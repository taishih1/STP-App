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
            // Clean white background
            Color.white.ignoresSafeArea()

            VStack {
                Spacer()

                if let player = player {
                    VideoPlayerView(player: player)
                        .frame(maxWidth: .infinity)
                        .aspectRatio(contentMode: .fit)
                } else {
                    // Minimal loading state
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .orange))
                        .scaleEffect(1.2)
                }

                Spacer()
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

        backgroundColor = .white
        playerLayer.videoGravity = .resizeAspect
        playerLayer.backgroundColor = UIColor.white.cgColor
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
