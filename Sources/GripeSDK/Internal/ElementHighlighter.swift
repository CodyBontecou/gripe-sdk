import UIKit

final class ElementHighlighter: UIView {
    private(set) var selectedRectInView: CGRect?

    private var hierarchy: CapturedNode?
    private var windowBounds: CGRect = .zero
    private var imageRectProvider: (() -> CGRect)?

    private let outline = CAShapeLayer()
    private let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        outline.fillColor = UIColor.systemBlue.withAlphaComponent(0.18).cgColor
        outline.strokeColor = UIColor.systemBlue.cgColor
        outline.lineWidth = 1.5
        layer.addSublayer(outline)

        label.font = .monospacedSystemFont(ofSize: 11, weight: .medium)
        label.textColor = .white
        label.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.9)
        label.textAlignment = .center
        label.layer.cornerRadius = 4
        label.layer.masksToBounds = true
        label.isHidden = true
        addSubview(label)

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handle(_:)))
        let tap = UITapGestureRecognizer(target: self, action: #selector(handle(_:)))
        pan.maximumNumberOfTouches = 1
        addGestureRecognizer(pan)
        addGestureRecognizer(tap)
    }

    func configure(hierarchy: CapturedNode, windowBounds: CGRect, imageRect: @escaping () -> CGRect) {
        self.hierarchy = hierarchy
        self.windowBounds = windowBounds
        self.imageRectProvider = imageRect
    }

    func refresh() {
        guard let rect = selectedRectInView else {
            outline.path = nil
            label.isHidden = true
            return
        }
        outline.path = UIBezierPath(rect: rect).cgPath
        positionLabel(above: rect)
    }

    @objc private func handle(_ recognizer: UIGestureRecognizer) {
        let point = recognizer.location(in: self)
        select(at: point)
    }

    private func select(at point: CGPoint) {
        guard let hierarchy, let imageRect = imageRectProvider?(),
              imageRect.width > 0, imageRect.contains(point) else { return }

        let scale = imageRect.width / windowBounds.width
        guard scale > 0 else { return }

        let pointInWindow = CGPoint(
            x: (point.x - imageRect.minX) / scale,
            y: (point.y - imageRect.minY) / scale
        )
        guard let node = CapturedHierarchy.hitTest(pointInWindow, in: hierarchy) else { return }

        let rectInView = CGRect(
            x: imageRect.minX + node.frameInWindow.minX * scale,
            y: imageRect.minY + node.frameInWindow.minY * scale,
            width: node.frameInWindow.width * scale,
            height: node.frameInWindow.height * scale
        )
        selectedRectInView = rectInView
        outline.path = UIBezierPath(rect: rectInView).cgPath

        let id = node.accessibilityIdentifier.map { " #\($0)" } ?? ""
        label.text = " \(node.className)\(id) "
        label.isHidden = false
        positionLabel(above: rectInView)
    }

    private func positionLabel(above rect: CGRect) {
        label.sizeToFit()
        var size = label.bounds.size
        size.width = min(size.width + 12, bounds.width - 16)
        size.height += 4
        var origin = CGPoint(x: rect.minX, y: rect.minY - size.height - 4)
        if origin.y < safeAreaInsets.top + 60 {
            origin.y = rect.maxY + 4
        }
        origin.x = max(8, min(origin.x, bounds.width - size.width - 8))
        label.frame = CGRect(origin: origin, size: size)
    }
}
