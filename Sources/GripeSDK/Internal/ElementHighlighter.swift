import UIKit

final class ElementHighlighter: UIView {
    private(set) var selectedRectInView: CGRect?

    var onSelectionChanged: (() -> Void)?

    private var hierarchy: CapturedNode?
    private var windowBounds: CGRect = .zero
    private var imageRectProvider: (() -> CGRect)?

    private let outline = CAShapeLayer()
    private let label = PaddedLabel()
    private var cornerHandles: [CAShapeLayer] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        outline.fillColor = GripeColor.primary.withAlphaComponent(0.12).cgColor
        outline.strokeColor = GripeColor.primary.cgColor
        outline.lineWidth = 2
        layer.addSublayer(outline)

        for _ in 0..<4 {
            let handle = CAShapeLayer()
            handle.fillColor = UIColor.white.cgColor
            handle.strokeColor = GripeColor.primary.cgColor
            handle.lineWidth = 1.5
            handle.isHidden = true
            layer.addSublayer(handle)
            cornerHandles.append(handle)
        }

        label.font = GripeFont.captionMedium()
        label.textColor = GripeColor.textPrimary
        label.backgroundColor = .white
        label.textAlignment = .center
        label.textInsets = UIEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)
        label.layer.cornerRadius = 8
        label.layer.borderWidth = 1
        label.layer.borderColor = GripeColor.border.cgColor
        label.layer.masksToBounds = false
        label.layer.shadowColor = UIColor.black.cgColor
        label.layer.shadowOpacity = 0.08
        label.layer.shadowRadius = 6
        label.layer.shadowOffset = CGSize(width: 0, height: 2)
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
            cornerHandles.forEach { $0.isHidden = true }
            return
        }
        outline.path = UIBezierPath(rect: rect).cgPath
        positionCornerHandles(for: rect)
        positionLabel(for: rect)
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

        let name = friendlyName(for: node)
        let dimensions = "\(Int(rectInView.width)) \u{00D7} \(Int(rectInView.height))"
        label.text = "\(name)  \(dimensions)"
        label.isHidden = false
        positionCornerHandles(for: rectInView)
        positionLabel(for: rectInView)

        onSelectionChanged?()
    }

    private func friendlyName(for node: CapturedNode) -> String {
        if let id = node.accessibilityIdentifier, !id.isEmpty {
            return id
        }
        var cleaned = node.className
        while cleaned.hasPrefix("_") { cleaned.removeFirst() }
        if cleaned.hasPrefix("UI") { cleaned.removeFirst(2) }
        if cleaned.hasPrefix("NS") { cleaned.removeFirst(2) }
        return cleaned.isEmpty ? node.className : cleaned.lowercased()
    }

    private func positionCornerHandles(for rect: CGRect) {
        let size: CGFloat = 10
        let half = size / 2
        let positions = [
            CGPoint(x: rect.minX, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.minY),
            CGPoint(x: rect.minX, y: rect.maxY),
            CGPoint(x: rect.maxX, y: rect.maxY),
        ]
        for (handle, center) in zip(cornerHandles, positions) {
            let frame = CGRect(x: center.x - half, y: center.y - half, width: size, height: size)
            handle.frame = frame
            handle.path = UIBezierPath(rect: handle.bounds).cgPath
            handle.isHidden = false
        }
    }

    private func positionLabel(for rect: CGRect) {
        let fitted = label.sizeThatFits(CGSize(width: bounds.width - 16, height: .greatestFiniteMagnitude))
        let size = CGSize(
            width: min(fitted.width, bounds.width - 16),
            height: fitted.height
        )
        var origin = CGPoint(
            x: rect.midX - size.width / 2,
            y: rect.maxY + 4
        )
        if origin.y + size.height > bounds.height - safeAreaInsets.bottom - 8 {
            origin.y = rect.minY - size.height - 4
        }
        origin.x = max(8, min(origin.x, bounds.width - size.width - 8))
        label.frame = CGRect(origin: origin, size: size)
        label.layer.shadowPath = UIBezierPath(roundedRect: label.bounds, cornerRadius: 8).cgPath
    }
}

private final class PaddedLabel: UILabel {
    var textInsets: UIEdgeInsets = .zero

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: textInsets))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(
            width: size.width + textInsets.left + textInsets.right,
            height: size.height + textInsets.top + textInsets.bottom
        )
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let inner = super.sizeThatFits(CGSize(
            width: size.width - textInsets.left - textInsets.right,
            height: size.height - textInsets.top - textInsets.bottom
        ))
        return CGSize(
            width: inner.width + textInsets.left + textInsets.right,
            height: inner.height + textInsets.top + textInsets.bottom
        )
    }
}
