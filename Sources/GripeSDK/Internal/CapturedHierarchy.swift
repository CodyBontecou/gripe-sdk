import UIKit

struct CapturedNode {
    let className: String
    let accessibilityIdentifier: String?
    let frameInWindow: CGRect
    let children: [CapturedNode]
}

enum CapturedHierarchy {
    static func capture(window: UIWindow) -> CapturedNode {
        capture(view: window, in: window)
    }

    private static func capture(view: UIView, in window: UIWindow) -> CapturedNode {
        let frame = view.convert(view.bounds, to: window)
        let children = view.subviews
            .filter { !$0.isHidden && $0.alpha > 0.01 && $0.bounds.width > 1 && $0.bounds.height > 1 }
            .map { capture(view: $0, in: window) }
        return CapturedNode(
            className: String(describing: type(of: view)),
            accessibilityIdentifier: view.accessibilityIdentifier,
            frameInWindow: frame,
            children: children
        )
    }

    static func hitTest(_ point: CGPoint, in node: CapturedNode) -> CapturedNode? {
        guard node.frameInWindow.contains(point) else { return nil }
        for child in node.children.reversed() {
            if let hit = hitTest(point, in: child) { return hit }
        }
        return node
    }
}
