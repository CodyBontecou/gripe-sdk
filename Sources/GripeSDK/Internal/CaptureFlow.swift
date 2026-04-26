import UIKit

enum CaptureFlow {
    static func start(completion: @escaping () -> Void) {
        guard let scene = activeScene(),
              let window = scene.keyWindow ?? scene.windows.first(where: { !$0.isHidden }) else {
            completion()
            return
        }
        let snapshot = renderSnapshot(of: window)
        let hierarchy = CapturedHierarchy.capture(window: window)

        let overlay = SelectorOverlayVC(
            snapshot: snapshot,
            hierarchy: hierarchy,
            windowBounds: window.bounds,
            onClose: completion
        )
        overlay.modalPresentationStyle = .overFullScreen
        overlay.modalTransitionStyle = .crossDissolve
        topViewController(for: window)?.present(overlay, animated: true)
    }

    private static func activeScene() -> UIWindowScene? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
    }

    private static func renderSnapshot(of window: UIWindow) -> UIImage {
        let renderer = UIGraphicsImageRenderer(bounds: window.bounds)
        return renderer.image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: false)
        }
    }

    private static func topViewController(for window: UIWindow) -> UIViewController? {
        var top = window.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}
