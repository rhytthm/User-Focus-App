import SwiftUI
import PhotosUI

struct ProfileView: View {
    @ObservedObject var viewModel: FocusViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedItem: PhotosPickerItem?
    @State private var userName: String
    
    init(viewModel: FocusViewModel) {
        self.viewModel = viewModel
        _userName = State(initialValue: viewModel.userProfile.name)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Profile Image
                    if let imageData = viewModel.userProfile.imageData,
                       let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 120, height: 120)
                            .clipShape(Circle())
                    } else {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 120, height: 120)
                            .foregroundColor(.gray)
                    }
                    
                    PhotosPicker(selection: $selectedItem) {
                        Text("Change Photo")
                            .foregroundColor(.blue)
                    }
                    
                    // User Name
                    TextField("Your Name", text: $userName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)
                        .onChange(of: userName) { newValue in
                            viewModel.updateUserProfile(name: newValue, imageData: viewModel.userProfile.imageData)
                        }
                    
                    // Stats
                    VStack(spacing: 15) {
                        StatView(title: "Total Points", value: "\(viewModel.userProfile.totalPoints)")
                        StatView(title: "Total Badges", value: "\(viewModel.userProfile.badges.count)")
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                    
                    // Badges Collection
                    VStack(alignment: .leading) {
                        Text("Badges Collection")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(viewModel.userProfile.badges) { badge in
                                    Text(badge.emoji)
                                        .font(.system(size: 40))
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    // Recent Sessions
                    VStack(alignment: .leading) {
                        Text("Recent Sessions")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ForEach(viewModel.userProfile.sessions.sorted(by: { $0.startTime > $1.startTime })) { session in
                            SessionRow(session: session)
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onChange(of: selectedItem) { newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        viewModel.updateUserProfile(name: userName, imageData: data)
                    }
                }
            }
        }
    }
}

struct StatView: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.gray)
            Text(value)
                .font(.title2)
                .bold()
        }
    }
}

struct SessionRow: View {
    let session: FocusSession
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(session.mode.rawValue)
                    .font(.headline)
                Spacer()
                Text(session.startTime.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            HStack {
                Text("Duration: \(formatDuration(session.duration))")
                Spacer()
                Text("Points: \(session.points)")
            }
            .font(.subheadline)
            
            if !session.badges.isEmpty {
                Text("Badges: \(session.badges.map { $0.emoji }.joined())")
                    .font(.subheadline)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
        .padding(.horizontal)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
} 