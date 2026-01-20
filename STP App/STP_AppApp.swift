import SwiftUI
import AVKit

@main
struct STP_AppApp: App {
    @State private var showLaunchScreen = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()

                if showLaunchScreen {
                    LaunchVideoView(isPresented: $showLaunchScreen)
                        .transition(.opacity)
                }
            }
        }
    }
}

// MARK: - Launch Video View
struct LaunchVideoView: View {
    @Binding var isPresented: Bool
    @State private var player: AVPlayer?

    var body: some View {
        ZStack {
            // Orange gradient background (matches app icon)
            LinearGradient(
                colors: [Color(red: 0.91, green: 0.36, blue: 0.02), Color(red: 0.96, green: 0.55, blue: 0.04)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 30) {
                if let player = player {
                    VideoPlayerView(player: player)
                        .frame(maxWidth: .infinity)
                        .aspectRatio(16/9, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(radius: 20)
                        .padding(.horizontal, 20)
                } else {
                    // Loading state - show app branding
                    VStack(spacing: 20) {
                        Image(systemName: "bicycle")
                            .font(.system(size: 80, weight: .bold))
                            .foregroundStyle(.white)

                        Text("STP 2026")
                            .font(.system(size: 36, weight: .black, design: .rounded))
                            .foregroundStyle(.white)

                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                    }
                }
            }
        }
        .onAppear {
            setupAndPlayVideo()
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }

    private func setupAndPlayVideo() {
        guard let url = Bundle.main.url(forResource: "STP_movie_3", withExtension: "mp4") else {
            print("Video file not found")
            // If video not found, dismiss after brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation {
                    isPresented = false
                }
            }
            return
        }

        let avPlayer = AVPlayer(url: url)
        self.player = avPlayer

        // Observe when video ends
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: avPlayer.currentItem,
            queue: .main
        ) { _ in
            withAnimation(.easeOut(duration: 0.5)) {
                isPresented = false
            }
        }

        // Start playing
        avPlayer.play()
    }
}

// MARK: - Video Player UIViewRepresentable
struct VideoPlayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> UIView {
        let view = PlayerUIView(player: player)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

class PlayerUIView: UIView {
    private var playerLayer: AVPlayerLayer

    init(player: AVPlayer) {
        playerLayer = AVPlayerLayer(player: player)
        super.init(frame: .zero)

        playerLayer.videoGravity = .resizeAspect
        layer.addSublayer(playerLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds
    }
}
