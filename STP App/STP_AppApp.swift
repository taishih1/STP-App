import SwiftUI
import AVKit
import UserNotifications

// MARK: - App Delegate for Notification Handling
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    // Handle notification tap when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound])
    }

    // Handle notification tap
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo

        if let checkpointId = userInfo["checkpointId"] as? String {
            print("📍 Notification tapped for checkpoint: \(checkpointId)")
            // Post notification to open checkpoint
            NotificationCenter.default.post(
                name: NSNotification.Name("OpenCheckpoint"),
                object: nil,
                userInfo: ["checkpointId": checkpointId]
            )
        }

        completionHandler()
    }
}

@main
struct STP_AppApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
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
            // Match this to your video's edge color (white, orange, etc.)
            Color.white
                .ignoresSafeArea()

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

        // Show full video, white background to hide black borders
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
