import Foundation
import SwiftUI
import Combine
import UserNotifications
import BackgroundTasks

class FocusViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var currentMode: FocusMode?
    @Published var elapsedTime: TimeInterval = 0
    @Published var isActive = false
    @Published var userProfile: UserProfile
    @Published var currentSession: FocusSession?
    
    // MARK: - Private Properties
    private var timer: Timer?
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private let pointsInterval: TimeInterval = 120 // 2 minute
    private var lastPointAwardTime: TimeInterval = 0
    private var sessionStartTime: Date?
    private var cancellables = Set<AnyCancellable>()
    private var lastActiveDate: Date?
    
    // MARK: - Initialization
    init() {
        self.userProfile = UserProfile.load() ?? UserProfile(name: "User")
        setupAppLifecycleHandlers()
        requestNotificationPermissions()
        restoreActiveSession()
    }
    
    // MARK: - Public Methods
    func startFocus(mode: FocusMode) {
        stopFocus()
        
        sessionStartTime = Date()
        currentMode = mode
        isActive = true
        elapsedTime = 0
        lastPointAwardTime = 0
        
        currentSession = FocusSession(
            id: UUID(),
            mode: mode,
            startTime: sessionStartTime!,
            points: 0,
            badges: []
        )
        
        startTimer()
        saveSession()
        scheduleNotifications()
    }
    
    func stopFocus() {
        guard isActive else { return }
        
        timer?.invalidate()
        timer = nil
        isActive = false
        
        if var session = currentSession {
            session.endTime = Date()
            userProfile.sessions.append(session)
            userProfile.totalPoints += session.points
            userProfile.badges.append(contentsOf: session.badges)
            userProfile.save()
        }
        
        cleanupSession()
    }
    
    func updateUserProfile(name: String, imageData: Data?) {
        userProfile.name = name
        userProfile.imageData = imageData
        userProfile.save()
    }
    
    func formatTime(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) / 60 % 60
        let seconds = Int(timeInterval) % 60
        
        return hours > 0 
            ? String(format: "%02d:%02d:%02d", hours, minutes, seconds)
            : String(format: "%02d:%02d", minutes, seconds)
    }
    
    // MARK: - Private Methods - Timer Management
    private func startTimer() {
        timer?.invalidate()
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, let startTime = self.sessionStartTime else { return }
            
            let newElapsedTime = Date().timeIntervalSince(startTime)
            self.elapsedTime = newElapsedTime
            
            let currentMinute = Int(newElapsedTime / pointsInterval)
            let lastPointMinute = Int(self.lastPointAwardTime / pointsInterval)
            
            if currentMinute > 0 && currentMinute > lastPointMinute {
                self.lastPointAwardTime = newElapsedTime
                self.awardPoints()
                self.scheduleNotifications()
            }
        }
        
        RunLoop.main.add(timer!, forMode: .common)
    }
    
    // MARK: - Private Methods - Points and Badges
    private func awardPoints() {
        guard var session = currentSession else { return }
        
        session.points += 1
        
        let badgeType = BadgeType.allCases.randomElement()!
        let badge = Badge(emoji: badgeType.badges.randomElement()!, type: badgeType)
        session.badges.append(badge)
        
        currentSession = session
        saveSession()
        
        userProfile.totalPoints += 1
        userProfile.save()
        
        objectWillChange.send()
    }
    
    // MARK: - Private Methods - Session Management
    private func saveSession() {
        guard let session = currentSession else { return }
        if let data = try? JSONEncoder().encode(session) {
            UserDefaults.standard.set(data, forKey: "activeSession")
        }
    }
    
    private func cleanupSession() {
        currentSession = nil
        currentMode = nil
        elapsedTime = 0
        lastPointAwardTime = 0
        sessionStartTime = nil
        lastActiveDate = nil
        
        UserDefaults.standard.removeObject(forKey: "activeSession")
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        objectWillChange.send()
    }
    
    private func restoreActiveSession() {
        guard let session = FocusSession.loadActive() else { return }
        
        let currentTime = Date()
        let sessionAge = currentTime.timeIntervalSince(session.startTime)
        
        if sessionAge > 24 * 3600 {
            UserDefaults.standard.removeObject(forKey: "activeSession")
            return
        }
        
        currentSession = session
        currentMode = session.mode
        sessionStartTime = session.startTime
        
        let newElapsedTime = currentTime.timeIntervalSince(session.startTime)
        elapsedTime = newElapsedTime
        
        let lastAwardedMinute = session.points
        let currentMinute = Int(newElapsedTime / pointsInterval)
        let missedPoints = max(0, currentMinute - Int(lastAwardedMinute))
        
        if missedPoints > 0 {
            for _ in 0..<missedPoints {
                awardPoints()
            }
            lastPointAwardTime = Double(currentMinute) * pointsInterval
        } else {
            lastPointAwardTime = Double(lastAwardedMinute) * pointsInterval
        }
        
        lastActiveDate = currentTime
        isActive = true
        startTimer()
        scheduleNotifications()
    }
    
    // MARK: - Private Methods - Notifications
    private func setupAppLifecycleHandlers() {
        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            .sink { [weak self] _ in self?.handleBackground() }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in self?.handleForeground() }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)
            .sink { [weak self] _ in self?.handleAppTermination() }
            .store(in: &cancellables)
    }
    
    private func scheduleNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        guard let startTime = sessionStartTime else { return }
        let currentTime = Date()
        let elapsedInterval = currentTime.timeIntervalSince(startTime)
        let nextPointInterval = pointsInterval - elapsedInterval.truncatingRemainder(dividingBy: pointsInterval)
        
        for i in 0...4 {
            let content = UNMutableNotificationContent()
            content.title = "\(currentMode?.rawValue ?? "Focus") Session"
            content.body = "You earned a point and a badge! 🎉"
            content.sound = .default
            
            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: nextPointInterval + (Double(i) * pointsInterval),
                repeats: false
            )
            
            let request = UNNotificationRequest(
                identifier: "point-\(UUID().uuidString)",
                content: content,
                trigger: trigger
            )
            
            UNUserNotificationCenter.current().add(request)
        }
    }
    
    private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
    }
    
    // MARK: - Private Methods - App Lifecycle
    private func handleBackground() {
        guard isActive else { return }
        
        timer?.invalidate()
        timer = nil
        lastActiveDate = Date()
        saveSession()
        
        // Schedule notifications for future points
        scheduleNotifications()
        
        if backgroundTask == .invalid {
            backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
                self?.handleBackgroundTaskExpiration()
            }
        }
    }
    
    private func handleForeground() {
        guard let session = FocusSession.loadActive() else { return }
        
        currentSession = session
        currentMode = session.mode
        sessionStartTime = session.startTime
        
        let currentTime = Date()
        let newElapsedTime = currentTime.timeIntervalSince(session.startTime)
        elapsedTime = newElapsedTime
        
        let lastAwardedMinute = Int(self.lastPointAwardTime / pointsInterval)
        let currentMinute = Int(newElapsedTime / pointsInterval)
        let missedPoints = max(0, currentMinute - lastAwardedMinute)
        
        if missedPoints > 0 {
            for _ in 0..<missedPoints {
                awardPoints()
            }
            lastPointAwardTime = Double(currentMinute) * pointsInterval
        } else {
            lastPointAwardTime = Double(lastAwardedMinute) * pointsInterval
        }
        
        lastActiveDate = currentTime
        isActive = true
        startTimer()
    }
    
    private func handleAppTermination() {
        guard isActive else { return }
        
        saveSession()
        lastActiveDate = Date()
        // Schedule notifications before app terminates
        scheduleNotifications()
    }
    
    private func handleBackgroundTaskExpiration() {
        if isActive {
            saveSession()
        }
        endBackgroundTask()
    }
    
    private func endBackgroundTask() {
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }
    
    deinit {
        timer?.invalidate()
        cancellables.removeAll()
        endBackgroundTask()
    }
}

// MARK: - Helper Extensions
extension UserProfile {
    static func load() -> UserProfile? {
        guard let data = UserDefaults.standard.data(forKey: "userProfile") else { return nil }
        return try? JSONDecoder().decode(UserProfile.self, from: data)
    }
    
    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: "userProfile")
        }
    }
}

extension FocusSession {
    static func loadActive() -> FocusSession? {
        guard let data = UserDefaults.standard.data(forKey: "activeSession") else { return nil }
        return try? JSONDecoder().decode(FocusSession.self, from: data)
    }
} 

