import Foundation
import SwiftUI

class FocusViewModel: ObservableObject {
    @Published var currentMode: FocusMode?
    @Published var elapsedTime: TimeInterval = 0
    @Published var isActive = false
    @Published var userProfile: UserProfile
    @Published var currentSession: FocusSession?
    
    private var timer: Timer?
    private let pointsInterval: TimeInterval = 120 // 2 minutes
    
    init() {
        // Load user profile from UserDefaults or create new one
        if let data = UserDefaults.standard.data(forKey: "userProfile"),
           let profile = try? JSONDecoder().decode(UserProfile.self, from: data) {
            self.userProfile = profile
        } else {
            self.userProfile = UserProfile(name: "User")
        }
        
        // Check for active session
        if let data = UserDefaults.standard.data(forKey: "activeSession"),
           let session = try? JSONDecoder().decode(FocusSession.self, from: data) {
            self.currentSession = session
            self.currentMode = session.mode
            self.elapsedTime = Date().timeIntervalSince(session.startTime)
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
        }
    }
    
    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.elapsedTime += 1
            
            // Award points and badges every 2 minutes
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