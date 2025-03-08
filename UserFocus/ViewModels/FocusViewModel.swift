import Foundation
import SwiftUI
import Combine

class FocusViewModel: ObservableObject {
    @Published var currentMode: FocusMode?
    @Published var elapsedTime: TimeInterval = 0
    @Published var isActive = false
    @Published var userProfile: UserProfile
    @Published var currentSession: FocusSession?
    
    private var timer: Timer?
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private let pointsInterval: TimeInterval = 120 // 2 minutes
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Load user profile from UserDefaults or create new one
        if let data = UserDefaults.standard.data(forKey: "userProfile"),
           let profile = try? JSONDecoder().decode(UserProfile.self, from: data) {
            self.userProfile = profile
        } else {
            self.userProfile = UserProfile(name: "User")
        }
        
        // Restore active session if exists
        restoreActiveSession()
        
        // Setup notifications for app lifecycle
        setupNotifications()
    }
    
    private func setupNotifications() {
        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            .sink { [weak self] _ in
                self?.handleAppBackground()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.handleAppForeground()
            }
            .store(in: &cancellables)
    }
    
    private func handleAppBackground() {
        // Save the current timestamp when going to background
        if isActive {
            UserDefaults.standard.set(Date(), forKey: "lastBackgroundDate")
            saveActiveSession()
            
            // Start background task
            backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
                self?.endBackgroundTask()
            }
        }
    }
    
    private func handleAppForeground() {
        if isActive {
            // Calculate elapsed time while in background
            if let lastBackgroundDate = UserDefaults.standard.object(forKey: "lastBackgroundDate") as? Date {
                let backgroundDuration = Date().timeIntervalSince(lastBackgroundDate)
                elapsedTime += backgroundDuration
                
                // Award points for background time
                let pointsEarned = Int(backgroundDuration / pointsInterval)
                if pointsEarned > 0 {
                    awardPointsForBackgroundTime(pointsEarned)
                }
            }
            
            // Restart timer
            startTimer()
        }
        
        endBackgroundTask()
    }
    
    private func endBackgroundTask() {
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }
    
    private func restoreActiveSession() {
        if let data = UserDefaults.standard.data(forKey: "activeSession"),
           let session = try? JSONDecoder().decode(FocusSession.self, from: data) {
            currentSession = session
            currentMode = session.mode
            elapsedTime = Date().timeIntervalSince(session.startTime)
            isActive = true
            startTimer()
        }
    }
    
    func startFocus(mode: FocusMode) {
        currentMode = mode
        isActive = true
        elapsedTime = 0
        
        let newSession = FocusSession(
            id: UUID(),
            mode: mode,
            startTime: Date(),
            points: 0,
            badges: []
        )
        
        currentSession = newSession
        saveActiveSession()
        startTimer()
    }
    
    func stopFocus() {
        isActive = false
        timer?.invalidate()
        timer = nil
        
        if var session = currentSession {
            session.endTime = Date()
            userProfile.sessions.append(session)
            userProfile.totalPoints += session.points
            userProfile.badges.append(contentsOf: session.badges)
            saveUserProfile()
            currentSession = nil
            UserDefaults.standard.removeObject(forKey: "activeSession")
            UserDefaults.standard.removeObject(forKey: "lastBackgroundDate")
        }
    }
    
    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.elapsedTime += 1
            
            // Award points every 2 minutes
            if Int(self.elapsedTime) % Int(self.pointsInterval) == 0 {
                self.awardPoints()
            }
        }
    }
    
    private func awardPoints() {
        guard var session = currentSession else { return }
        session.points += 1
        
        // Randomly select a badge type and emoji
        let badgeType = BadgeType.allCases.randomElement()!
        let badgeEmoji = badgeType.badges.randomElement()!
        let newBadge = Badge(emoji: badgeEmoji, type: badgeType)
        
        session.badges.append(newBadge)
        currentSession = session
        saveActiveSession()
    }
    
    private func awardPointsForBackgroundTime(_ points: Int) {
        guard var session = currentSession else { return }
        
        for _ in 0..<points {
            session.points += 1
            let badgeType = BadgeType.allCases.randomElement()!
            let badgeEmoji = badgeType.badges.randomElement()!
            let newBadge = Badge(emoji: badgeEmoji, type: badgeType)
            session.badges.append(newBadge)
        }
        
        currentSession = session
        saveActiveSession()
    }
    
    private func saveActiveSession() {
        if let session = currentSession,
           let data = try? JSONEncoder().encode(session) {
            UserDefaults.standard.set(data, forKey: "activeSession")
        }
    }
    
    private func saveUserProfile() {
        if let data = try? JSONEncoder().encode(userProfile) {
            UserDefaults.standard.set(data, forKey: "userProfile")
        }
    }
    
    func updateUserProfile(name: String, imageData: Data?) {
        userProfile.name = name
        userProfile.imageData = imageData
        saveUserProfile()
    }
    
    func formatTime(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) / 60 % 60
        let seconds = Int(timeInterval) % 60
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
} 