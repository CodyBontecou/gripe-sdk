import UIKit

final class CropRectView: UIView {
    private(set) var cropRectInView: CGRect?

    var onSelectionChanged: (() -> Void)?

    private var imageRectProvider: (() -> CGRect)?
    private let outline = CAShapeLayer()
    private let dim = CAShapeLayer()
    private var cornerHandles: [CAShapeLayer] = []
    private var startPoint: CGPoint?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        dim.fillColor = UIColor.black.withAlphaComponent(0.5).cgColor
        dim.fillRule = .evenOdd
        layer.addSublayer(dim)

        outline.fillColor = UIColor.clear.cgColor
        outline.strokeColor = GripeColor.primary.cgColor
        outline.lineWidth = 2
        outline.lineDashPattern = [6, 4]
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

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.maximumNumberOfTouches = 1
        addGestureRecognizer(pan)
    }

    func configure(imageRect: @escaping () -> CGRect) {
        self.imageRectProvider = imageRect
    }

    func refreshIfNeeded() {
        if cropRectInView == nil, let r = imageRectProvider?(), r.width > 80, r.height > 80 {
            cropRectInView = r.insetBy(dx: r.width * 0.15, dy: r.height * 0.2)
        }
        updatePaths()
    }

    @objc private func handlePan(_ pan: UIPanGestureRecognizer) {
        guard let imageRect = imageRectProvider?() else { return }
        let pt = clamp(pan.location(in: self), to: imageRect)
        switch pan.state {
        case .began:
            startPoint = pt
            cropRectInView = CGRect(origin: pt, size: .zero)
        case .changed:
            guard let start = startPoint else { return }
            cropRectInView = CGRect(
                x: min(start.x, pt.x),
                y: min(start.y, pt.y),
                width: abs(pt.x - start.x),
                height: abs(pt.y - start.y)
            )
            onSelectionChanged?()
        case .ended:
            startPoint = nil
            onSelectionChanged?()
        case .cancelled, .failed:
            startPoint = nil
        default:
            break
        }
        updatePaths()
    }

    private func clamp(_ p: CGPoint, to rect: CGRect) -> CGPoint {
        CGPoint(
            x: min(max(p.x, rect.minX), rect.maxX),
            y: min(max(p.y, rect.minY), rect.maxY)
        )
    }

    private func updatePaths() {
        guard let rect = cropRectInView else {
            outline.path = nil
            dim.path = nil
            cornerHandles.forEach { $0.isHidden = true }
            return
        }
        outline.path = UIBezierPath(rect: rect).cgPath
        let dimPath = UIBezierPath(rect: bounds)
        dimPath.append(UIBezierPath(rect: rect))
        dim.path = dimPath.cgPath
        positionCornerHandles(for: rect)
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
}
