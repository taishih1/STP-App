import SwiftUI
import AVKit

@main
struct STP_AppApp: App {
    @State private var showLaunchScreen = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .opacity(showLaunchScreen ? 0 : 1)

                if showLaunchScreen {
                    LaunchVideoView(isPresented: $showLaunchScreen)
                }
            }
            .animation(.easeInOut(duration: 0.4), value: showLaunchScreen)
        }
    }
}

// MARK: - Launch Video View
struct LaunchVideoView: View {
    @Binding var isPresented: Bool
    @StateObject private var playerViewModel = VideoPlayerViewModel()

    var body: some View {
        ZStack {
            // Background matches video edges - adjust this color to match your video
            Color.white
                .ignoresSafeArea()

            // Video centered, shows full content
            VideoPlayerRepresentable(player: playerViewModel.player)
                .ignoresSafeArea()
        }
        .onAppear {
            playerViewModel.onVideoEnd = {
                isPresented = false
            }
            playerViewModel.play()
        }
    }
}

// MARK: - Video Player ViewModel
class VideoPlayerViewModel: ObservableObject {
    let player: AVPlayer
    var onVideoEnd: (() -> Void)?
    private var observer: Any?

    init() {
        if let url = Bundle.main.url(forResource: "STP_movie_3", withExtension: "mp4") {
            self.player = AVPlayer(url: url)
            self.player.isMuted = false
            setupObserver()
        } else {
            print("❌ Video file not found in bundle")
            self.player = AVPlayer()
            // Auto-dismiss if no video
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                self?.onVideoEnd?()
            }
        }
    }

    private func setupObserver() {
        observer = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { [weak self] _ in
            self?.onVideoEnd?()
        }
    }

    func play() {
        player.seek(to: .zero)
        player.play()
    }

    deinit {
        if let observer = observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}

// MARK: - Video Player UIViewRepresentable
struct VideoPlayerRepresentable: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerContainerView {
        return PlayerContainerView(player: player)
    }

    func updateUIView(_ uiView: PlayerContainerView, context: Context) {}
}

class PlayerContainerView: UIView {
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
