import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = FocusViewModel()
    @State private var showingProfile = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if viewModel.isActive {
                    activeFocusView
                } else {
                    focusModeSelectionView
                }
            }
            .navigationTitle("Focus Mode")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingProfile = true }) {
                        Image(systemName: "person.circle")
                    }
                }
            }
            .sheet(isPresented: $showingProfile) {
                ProfileView(viewModel: viewModel)
            }
        }
    }
    
    private var activeFocusView: some View {
        VStack(spacing: 30) {
            Text(viewModel.currentMode?.rawValue ?? "")
                .font(.largeTitle)
                .bold()
            
            Text(viewModel.formatTime(viewModel.elapsedTime))
                .font(.system(size: 60, weight: .bold, design: .monospaced))
            
            if let session = viewModel.currentSession {
                VStack(spacing: 10) {
                    Text("Points: \(session.points)")
                        .font(.title2)
                    
                    Text("Badges: \(session.badges.map { $0.emoji }.joined())")
                        .font(.title2)
                }
            }
            
            Button(action: { viewModel.stopFocus() }) {
                Text("Stop Focusing")
                    .font(.title3)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.red)
                    .cornerRadius(10)
            }
        }
        .padding()
    }
    
    private var focusModeSelectionView: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 20) {
            ForEach(FocusMode.allCases, id: \.self) { mode in
                Button(action: { viewModel.startFocus(mode: mode) }) {
                    VStack {
                        Image(systemName: modeIcon(for: mode))
                            .font(.system(size: 40))
                        Text(mode.rawValue)
                            .font(.title2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(modeColor(for: mode))
                    .foregroundColor(.white)
                    .cornerRadius(15)
                }
            }
        }
        .padding()
    }
    
    private func modeIcon(for mode: FocusMode) -> String {
        switch mode {
        case .work: return "briefcase.fill"
        case .play: return "gamecontroller.fill"
        case .rest: return "bed.double.fill"
        case .sleep: return "moon.fill"
        }
    }
    
    private func modeColor(for mode: FocusMode) -> Color {
        switch mode {
        case .work: return .blue
        case .play: return .green
        case .rest: return .orange
        case .sleep: return .purple
        }
    }
} 