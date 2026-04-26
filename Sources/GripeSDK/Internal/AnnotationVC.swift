#if canImport(UIKit)
import UIKit

// MARK: - Model

enum AnnotationTool: Int, CaseIterable {
    case pen, rect, arrow, text

    var systemImage: String {
        switch self {
        case .pen: return "scribble.variable"
        case .rect: return "rectangle"
        case .arrow: return "arrow.up.right"
        case .text: return "textformat"
        }
    }
}

private struct Annotation {
    enum Shape {
        case path(points: [CGPoint])
        case rect(CGRect)
        case arrow(from: CGPoint, to: CGPoint)
        case text(String, origin: CGPoint, fontSize: CGFloat)
    }
    var shape: Shape
    var color: UIColor
    var lineWidth: CGFloat
}

private enum AnnotationPalette {
    static let colors: [UIColor] = [
        UIColor(red: 0xEF/255, green: 0x44/255, blue: 0x44/255, alpha: 1),
        UIColor(red: 0xF5/255, green: 0xA6/255, blue: 0x23/255, alpha: 1),
        UIColor(red: 0x22/255, green: 0xC5/255, blue: 0x5E/255, alpha: 1),
        UIColor(red: 0x0A/255, green: 0x84/255, blue: 0xFF/255, alpha: 1),
        .black,
        .white,
    ]
    static let lineWidth: CGFloat = 4
    static let textFontSize: CGFloat = 22
}

// MARK: - Canvas

final class AnnotationCanvasView: UIView, UITextFieldDelegate {
    var image: UIImage? {
        didSet {
            imageView.image = image
            setNeedsLayout()
            setNeedsDisplay()
        }
    }
    var currentTool: AnnotationTool = .pen {
        didSet { commitLiveText(); updateGesturesForTool() }
    }
    var currentColor: UIColor = AnnotationPalette.colors[0] {
        didSet { liveTextField?.textColor = currentColor }
    }
    var onChange: (() -> Void)?

    private var annotations: [Annotation] = []
    private var redoStack: [Annotation] = []
    private var inProgress: Annotation?
    private var dragStart: CGPoint?
    private var liveTextField: UITextField?

    private let imageView = UIImageView()
    private let pan = UIPanGestureRecognizer()
    private let tap = UITapGestureRecognizer()

    var canUndo: Bool { !annotations.isEmpty || liveTextField != nil }
    var canRedo: Bool { !redoStack.isEmpty }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        contentMode = .redraw

        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = false
        imageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(imageView)

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        pan.addTarget(self, action: #selector(handlePan(_:)))
        tap.addTarget(self, action: #selector(handleTap(_:)))
        addGestureRecognizer(pan)
        addGestureRecognizer(tap)
        updateGesturesForTool()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    override func layoutSubviews() {
        super.layoutSubviews()
        setNeedsDisplay()
    }

    // MARK: Public actions

    func undo() {
        if liveTextField != nil { discardLiveText(); return }
        guard let last = annotations.popLast() else { return }
        redoStack.append(last)
        setNeedsDisplay()
        onChange?()
    }

    func redo() {
        guard let next = redoStack.popLast() else { return }
        annotations.append(next)
        setNeedsDisplay()
        onChange?()
    }

    func render() -> UIImage {
        commitLiveText()
        guard let image = image else { return UIImage() }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = image.scale
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        return renderer.image { ctx in
            image.draw(in: CGRect(origin: .zero, size: image.size))
            let pixelScale = image.size.width / max(imageRect.width, 1)
            for ann in annotations {
                draw(annotation: ann,
                     in: ctx.cgContext,
                     transform: { p in CGPoint(x: p.x * image.size.width, y: p.y * image.size.height) },
                     scale: pixelScale)
            }
        }
    }

    // MARK: Image rect / coordinate transforms

    private var imageRect: CGRect {
        guard let image = image, image.size.width > 0, image.size.height > 0 else { return .zero }
        let viewSize = bounds.size
        let s = min(viewSize.width / image.size.width, viewSize.height / image.size.height)
        let displaySize = CGSize(width: image.size.width * s, height: image.size.height * s)
        let origin = CGPoint(
            x: (viewSize.width - displaySize.width) / 2,
            y: (viewSize.height - displaySize.height) / 2
        )
        return CGRect(origin: origin, size: displaySize)
    }

    private func clamp(_ point: CGPoint) -> CGPoint {
        let r = imageRect
        return CGPoint(
            x: min(max(point.x, r.minX), r.maxX),
            y: min(max(point.y, r.minY), r.maxY)
        )
    }

    private func normalize(_ point: CGPoint) -> CGPoint {
        let r = imageRect
        guard r.width > 0, r.height > 0 else { return .zero }
        return CGPoint(x: (point.x - r.minX) / r.width, y: (point.y - r.minY) / r.height)
    }

    private func denormalize(_ point: CGPoint) -> CGPoint {
        let r = imageRect
        return CGPoint(x: r.minX + point.x * r.width, y: r.minY + point.y * r.height)
    }

    // MARK: Drawing

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        let viewTransform: (CGPoint) -> CGPoint = { [weak self] p in self?.denormalize(p) ?? .zero }
        for ann in annotations { draw(annotation: ann, in: ctx, transform: viewTransform, scale: 1) }
        if let inProgress { draw(annotation: inProgress, in: ctx, transform: viewTransform, scale: 1) }
    }

    private func draw(annotation: Annotation,
                      in ctx: CGContext,
                      transform: (CGPoint) -> CGPoint,
                      scale: CGFloat) {
        ctx.saveGState()
        ctx.setStrokeColor(annotation.color.cgColor)
        ctx.setFillColor(annotation.color.cgColor)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        ctx.setLineWidth(annotation.lineWidth * scale)

        switch annotation.shape {
        case .path(let pts):
            guard let first = pts.first else { ctx.restoreGState(); return }
            ctx.beginPath()
            ctx.move(to: transform(first))
            for p in pts.dropFirst() { ctx.addLine(to: transform(p)) }
            ctx.strokePath()
        case .rect(let r):
            let a = transform(r.origin)
            let b = transform(CGPoint(x: r.maxX, y: r.maxY))
            let pixelRect = CGRect(x: a.x, y: a.y, width: b.x - a.x, height: b.y - a.y)
            ctx.stroke(pixelRect)
        case .arrow(let from, let to):
            drawArrow(from: transform(from),
                      to: transform(to),
                      lineWidth: annotation.lineWidth * scale,
                      in: ctx)
        case .text(let s, let origin, let fontSize):
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: fontSize * scale, weight: .semibold),
                .foregroundColor: annotation.color,
            ]
            (s as NSString).draw(at: transform(origin), withAttributes: attrs)
        }
        ctx.restoreGState()
    }

    private func drawArrow(from: CGPoint, to: CGPoint, lineWidth: CGFloat, in ctx: CGContext) {
        ctx.beginPath()
        ctx.move(to: from)
        ctx.addLine(to: to)
        ctx.strokePath()
        let dx = to.x - from.x
        let dy = to.y - from.y
        let len = max(sqrt(dx * dx + dy * dy), 0.001)
        let ux = dx / len
        let uy = dy / len
        let head = max(lineWidth * 3.5, 12)
        let theta: CGFloat = .pi / 7
        let cosT = cos(theta), sinT = sin(theta)
        let p1 = CGPoint(x: to.x - head * (ux * cosT - uy * sinT),
                         y: to.y - head * (uy * cosT + ux * sinT))
        let p2 = CGPoint(x: to.x - head * (ux * cosT + uy * sinT),
                         y: to.y - head * (uy * cosT - ux * sinT))
        ctx.beginPath()
        ctx.move(to: to)
        ctx.addLine(to: p1)
        ctx.addLine(to: p2)
        ctx.closePath()
        ctx.fillPath()
    }

    // MARK: Gestures

    private func updateGesturesForTool() {
        switch currentTool {
        case .text:
            pan.isEnabled = false
            tap.isEnabled = true
        default:
            pan.isEnabled = true
            tap.isEnabled = false
        }
    }

    @objc private func handlePan(_ gr: UIPanGestureRecognizer) {
        let viewPt = clamp(gr.location(in: self))
        let np = normalize(viewPt)
        switch gr.state {
        case .began:
            redoStack.removeAll()
            switch currentTool {
            case .pen:
                inProgress = Annotation(shape: .path(points: [np]),
                                        color: currentColor,
                                        lineWidth: AnnotationPalette.lineWidth)
            case .rect:
                dragStart = np
                inProgress = Annotation(shape: .rect(CGRect(origin: np, size: .zero)),
                                        color: currentColor,
                                        lineWidth: AnnotationPalette.lineWidth)
            case .arrow:
                inProgress = Annotation(shape: .arrow(from: np, to: np),
                                        color: currentColor,
                                        lineWidth: AnnotationPalette.lineWidth)
            case .text:
                break
            }
        case .changed:
            guard var current = inProgress else { return }
            switch (currentTool, current.shape) {
            case (.pen, .path(var pts)):
                pts.append(np)
                current.shape = .path(points: pts)
            case (.rect, .rect):
                if let s = dragStart {
                    let r = CGRect(x: min(s.x, np.x),
                                   y: min(s.y, np.y),
                                   width: abs(np.x - s.x),
                                   height: abs(np.y - s.y))
                    current.shape = .rect(r)
                }
            case (.arrow, .arrow(let from, _)):
                current.shape = .arrow(from: from, to: np)
            default:
                break
            }
            inProgress = current
            setNeedsDisplay()
        case .ended, .cancelled, .failed:
            if let a = inProgress, isMeaningful(a) {
                annotations.append(a)
                onChange?()
            }
            inProgress = nil
            dragStart = nil
            setNeedsDisplay()
        default:
            break
        }
    }

    @objc private func handleTap(_ gr: UITapGestureRecognizer) {
        guard currentTool == .text else { return }
        if liveTextField != nil { commitLiveText(); return }
        let viewPt = gr.location(in: self)
        guard imageRect.contains(viewPt) else { return }
        showLiveTextField(at: viewPt)
    }

    private func isMeaningful(_ annotation: Annotation) -> Bool {
        let minLen: CGFloat = 0.005
        switch annotation.shape {
        case .path(let pts): return pts.count > 1
        case .rect(let r): return r.width > minLen && r.height > minLen
        case .arrow(let f, let t): return abs(f.x - t.x) > minLen || abs(f.y - t.y) > minLen
        case .text(let s, _, _): return !s.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }

    // MARK: Text editing

    private func showLiveTextField(at point: CGPoint) {
        let tf = UITextField()
        tf.font = UIFont.systemFont(ofSize: AnnotationPalette.textFontSize, weight: .semibold)
        tf.textColor = currentColor
        tf.backgroundColor = UIColor.black.withAlphaComponent(0.04)
        tf.layer.cornerRadius = 6
        tf.layer.cornerCurve = .continuous
        tf.layer.borderColor = UIColor.black.withAlphaComponent(0.2).cgColor
        tf.layer.borderWidth = 1
        tf.delegate = self
        tf.returnKeyType = .done
        tf.autocorrectionType = .no
        tf.autocapitalizationType = .sentences
        tf.spellCheckingType = .no
        tf.addTarget(self, action: #selector(liveTextChanged), for: .editingChanged)
        tf.translatesAutoresizingMaskIntoConstraints = false

        let placeholderWidth: CGFloat = 140
        let height: CGFloat = AnnotationPalette.textFontSize + 14
        let originX = min(max(point.x, imageRect.minX), imageRect.maxX - placeholderWidth)
        let originY = min(max(point.y - height / 2, imageRect.minY), imageRect.maxY - height)
        tf.frame = CGRect(x: originX, y: originY, width: placeholderWidth, height: height)
        addSubview(tf)
        liveTextField = tf
        tf.becomeFirstResponder()
    }

    @objc private func liveTextChanged() {
        guard let tf = liveTextField, let font = tf.font else { return }
        let textWidth = (tf.text ?? "").size(withAttributes: [.font: font]).width
        let width = max(80, textWidth + 24)
        var frame = tf.frame
        frame.size.width = min(width, imageRect.maxX - frame.minX)
        tf.frame = frame
    }

    func commitLiveText() {
        guard let tf = liveTextField else { return }
        let text = (tf.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let textColor = tf.textColor ?? .black
        tf.removeFromSuperview()
        liveTextField = nil
        guard !text.isEmpty else { return }
        let origin = normalize(CGPoint(x: tf.frame.minX + 6, y: tf.frame.minY + 7))
        let annotation = Annotation(
            shape: .text(text, origin: origin, fontSize: AnnotationPalette.textFontSize),
            color: textColor,
            lineWidth: 0
        )
        annotations.append(annotation)
        redoStack.removeAll()
        setNeedsDisplay()
        onChange?()
    }

    private func discardLiveText() {
        liveTextField?.removeFromSuperview()
        liveTextField = nil
        onChange?()
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        commitLiveText()
        return true
    }
}

// MARK: - View controller

final class AnnotationVC: UIViewController {
    private let baseImage: UIImage
    private let onCancel: () -> Void
    private let onDone: (UIImage) -> Void

    private let canvasView = AnnotationCanvasView()

    private let topBar = UIView()
    private let topBarBlur = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterial))
    private let topBarRim = UIView()
    private let backButton = UIButton(type: .system)
    private let undoButton = UIButton(type: .system)
    private let redoButton = UIButton(type: .system)
    private let doneButton = UIButton(type: .custom)

    private let palette = UIView()
    private let paletteBlur = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterial))
    private let paletteRim = UIView()
    private let toolStack = UIStackView()
    private let colorStack = UIStackView()

    private var toolButtons: [UIButton] = []
    private var colorButtons: [UIButton] = []

    init(image: UIImage, onCancel: @escaping () -> Void, onDone: @escaping (UIImage) -> Void) {
        self.baseImage = image
        self.onCancel = onCancel
        self.onDone = onDone
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        canvasView.image = baseImage
        canvasView.currentTool = .pen
        canvasView.currentColor = AnnotationPalette.colors[0]
        canvasView.onChange = { [weak self] in self?.refreshUndoRedo() }
        canvasView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(canvasView)

        configureTopBar()
        configurePalette()

        view.addSubview(topBar)
        view.addSubview(palette)

        NSLayoutConstraint.activate([
            canvasView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            canvasView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            canvasView.topAnchor.constraint(equalTo: view.topAnchor),
            canvasView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            topBar.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            topBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: GripeSpacing.s),
            topBar.heightAnchor.constraint(equalToConstant: 44),
            topBar.leadingAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.leadingAnchor, constant: GripeSpacing.l),
            topBar.trailingAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -GripeSpacing.l),

            palette.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: GripeSpacing.l),
            palette.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -GripeSpacing.l),
            palette.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -GripeSpacing.m),
        ])

        applyToolSelection()
        applyColorSelection()
        refreshUndoRedo()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        topBar.layer.shadowPath = UIBezierPath(
            roundedRect: topBar.bounds,
            cornerRadius: topBar.layer.cornerRadius
        ).cgPath
        palette.layer.shadowPath = UIBezierPath(
            roundedRect: palette.bounds,
            cornerRadius: palette.layer.cornerRadius
        ).cgPath
    }

    // MARK: Top bar

    private func configureTopBar() {
        topBar.translatesAutoresizingMaskIntoConstraints = false
        topBar.backgroundColor = .clear
        topBar.layer.cornerRadius = 22
        topBar.layer.cornerCurve = .continuous
        topBar.layer.shadowColor = UIColor.black.cgColor
        topBar.layer.shadowOpacity = 0.18
        topBar.layer.shadowRadius = 18
        topBar.layer.shadowOffset = CGSize(width: 0, height: 4)

        topBarBlur.translatesAutoresizingMaskIntoConstraints = false
        topBarBlur.layer.cornerRadius = 22
        topBarBlur.layer.cornerCurve = .continuous
        topBarBlur.clipsToBounds = true
        topBar.addSubview(topBarBlur)

        topBarRim.translatesAutoresizingMaskIntoConstraints = false
        topBarRim.backgroundColor = .clear
        topBarRim.layer.cornerRadius = 22
        topBarRim.layer.cornerCurve = .continuous
        topBarRim.layer.borderWidth = 0.5
        topBarRim.layer.borderColor = UIColor.white.withAlphaComponent(0.45).cgColor
        topBarRim.isUserInteractionEnabled = false
        topBar.addSubview(topBarRim)

        NSLayoutConstraint.activate([
            topBarBlur.leadingAnchor.constraint(equalTo: topBar.leadingAnchor),
            topBarBlur.trailingAnchor.constraint(equalTo: topBar.trailingAnchor),
            topBarBlur.topAnchor.constraint(equalTo: topBar.topAnchor),
            topBarBlur.bottomAnchor.constraint(equalTo: topBar.bottomAnchor),

            topBarRim.leadingAnchor.constraint(equalTo: topBar.leadingAnchor),
            topBarRim.trailingAnchor.constraint(equalTo: topBar.trailingAnchor),
            topBarRim.topAnchor.constraint(equalTo: topBar.topAnchor),
            topBarRim.bottomAnchor.constraint(equalTo: topBar.bottomAnchor),
        ])

        let content = topBarBlur.contentView

        backButton.setImage(UIImage(systemName: "chevron.left")?
            .withConfiguration(UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)), for: .normal)
        backButton.tintColor = GripeColor.textPrimary
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        backButton.translatesAutoresizingMaskIntoConstraints = false

        undoButton.setImage(UIImage(systemName: "arrow.uturn.backward")?
            .withConfiguration(UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)), for: .normal)
        undoButton.tintColor = GripeColor.textPrimary
        undoButton.addTarget(self, action: #selector(undoTapped), for: .touchUpInside)
        undoButton.translatesAutoresizingMaskIntoConstraints = false

        redoButton.setImage(UIImage(systemName: "arrow.uturn.forward")?
            .withConfiguration(UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)), for: .normal)
        redoButton.tintColor = GripeColor.textPrimary
        redoButton.addTarget(self, action: #selector(redoTapped), for: .touchUpInside)
        redoButton.translatesAutoresizingMaskIntoConstraints = false

        var doneConfig = UIButton.Configuration.plain()
        doneConfig.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12)
        var doneAttr = AttributedString("Done")
        doneAttr.font = .systemFont(ofSize: 15, weight: .semibold)
        doneAttr.foregroundColor = GripeColor.primary
        doneConfig.attributedTitle = doneAttr
        doneButton.configuration = doneConfig
        doneButton.addTarget(self, action: #selector(doneTapped), for: .touchUpInside)
        doneButton.translatesAutoresizingMaskIntoConstraints = false

        let leftStack = UIStackView(arrangedSubviews: [backButton, undoButton, redoButton])
        leftStack.axis = .horizontal
        leftStack.spacing = 4
        leftStack.alignment = .center
        leftStack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(leftStack)
        content.addSubview(doneButton)

        NSLayoutConstraint.activate([
            leftStack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 8),
            leftStack.centerYAnchor.constraint(equalTo: content.centerYAnchor),

            backButton.widthAnchor.constraint(equalToConstant: 32),
            backButton.heightAnchor.constraint(equalToConstant: 32),
            undoButton.widthAnchor.constraint(equalToConstant: 32),
            undoButton.heightAnchor.constraint(equalToConstant: 32),
            redoButton.widthAnchor.constraint(equalToConstant: 32),
            redoButton.heightAnchor.constraint(equalToConstant: 32),

            doneButton.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -6),
            doneButton.centerYAnchor.constraint(equalTo: content.centerYAnchor),
            doneButton.leadingAnchor.constraint(greaterThanOrEqualTo: leftStack.trailingAnchor, constant: 24),
        ])
    }

    // MARK: Palette

    private func configurePalette() {
        palette.translatesAutoresizingMaskIntoConstraints = false
        palette.backgroundColor = .clear
        palette.layer.cornerRadius = 22
        palette.layer.cornerCurve = .continuous
        palette.layer.shadowColor = UIColor.black.cgColor
        palette.layer.shadowOpacity = 0.18
        palette.layer.shadowRadius = 18
        palette.layer.shadowOffset = CGSize(width: 0, height: 4)

        paletteBlur.translatesAutoresizingMaskIntoConstraints = false
        paletteBlur.layer.cornerRadius = 22
        paletteBlur.layer.cornerCurve = .continuous
        paletteBlur.clipsToBounds = true
        palette.addSubview(paletteBlur)

        paletteRim.translatesAutoresizingMaskIntoConstraints = false
        paletteRim.backgroundColor = .clear
        paletteRim.layer.cornerRadius = 22
        paletteRim.layer.cornerCurve = .continuous
        paletteRim.layer.borderWidth = 0.5
        paletteRim.layer.borderColor = UIColor.white.withAlphaComponent(0.45).cgColor
        paletteRim.isUserInteractionEnabled = false
        palette.addSubview(paletteRim)

        NSLayoutConstraint.activate([
            paletteBlur.leadingAnchor.constraint(equalTo: palette.leadingAnchor),
            paletteBlur.trailingAnchor.constraint(equalTo: palette.trailingAnchor),
            paletteBlur.topAnchor.constraint(equalTo: palette.topAnchor),
            paletteBlur.bottomAnchor.constraint(equalTo: palette.bottomAnchor),

            paletteRim.leadingAnchor.constraint(equalTo: palette.leadingAnchor),
            paletteRim.trailingAnchor.constraint(equalTo: palette.trailingAnchor),
            paletteRim.topAnchor.constraint(equalTo: palette.topAnchor),
            paletteRim.bottomAnchor.constraint(equalTo: palette.bottomAnchor),
        ])

        let content = paletteBlur.contentView

        toolStack.axis = .horizontal
        toolStack.alignment = .center
        toolStack.distribution = .fillEqually
        toolStack.spacing = 8
        toolStack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(toolStack)

        toolButtons = AnnotationTool.allCases.enumerated().map { index, tool in
            let btn = UIButton(type: .custom)
            btn.tag = index
            btn.layer.cornerRadius = 12
            btn.layer.cornerCurve = .continuous
            btn.layer.borderWidth = 1
            btn.setImage(UIImage(systemName: tool.systemImage)?
                .withConfiguration(UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)), for: .normal)
            btn.addTarget(self, action: #selector(toolTapped(_:)), for: .touchUpInside)
            btn.translatesAutoresizingMaskIntoConstraints = false
            btn.heightAnchor.constraint(equalToConstant: 44).isActive = true
            return btn
        }
        toolButtons.forEach { toolStack.addArrangedSubview($0) }

        colorStack.axis = .horizontal
        colorStack.alignment = .center
        colorStack.distribution = .fillEqually
        colorStack.spacing = 8
        colorStack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(colorStack)

        colorButtons = AnnotationPalette.colors.enumerated().map { index, color in
            let btn = UIButton(type: .custom)
            btn.tag = index
            btn.backgroundColor = color
            btn.layer.cornerRadius = 14
            btn.layer.borderWidth = 1
            btn.layer.borderColor = UIColor.black.withAlphaComponent(0.12).cgColor
            btn.addTarget(self, action: #selector(colorTapped(_:)), for: .touchUpInside)
            btn.translatesAutoresizingMaskIntoConstraints = false
            btn.widthAnchor.constraint(equalToConstant: 28).isActive = true
            btn.heightAnchor.constraint(equalToConstant: 28).isActive = true
            return btn
        }
        colorButtons.forEach { colorStack.addArrangedSubview($0) }

        NSLayoutConstraint.activate([
            toolStack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 12),
            toolStack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -12),
            toolStack.topAnchor.constraint(equalTo: content.topAnchor, constant: 12),

            colorStack.centerXAnchor.constraint(equalTo: content.centerXAnchor),
            colorStack.topAnchor.constraint(equalTo: toolStack.bottomAnchor, constant: 12),
            colorStack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -14),
            colorStack.leadingAnchor.constraint(greaterThanOrEqualTo: content.leadingAnchor, constant: 12),
            colorStack.trailingAnchor.constraint(lessThanOrEqualTo: content.trailingAnchor, constant: -12),
        ])
    }

    // MARK: Selection state

    private func applyToolSelection() {
        let activeIndex = canvasView.currentTool.rawValue
        for (i, btn) in toolButtons.enumerated() {
            let active = i == activeIndex
            btn.backgroundColor = active ? GripeColor.primary : UIColor.white.withAlphaComponent(0.85)
            btn.tintColor = active ? .white : GripeColor.textPrimary
            btn.layer.borderColor = active
                ? GripeColor.primary.cgColor
                : UIColor.black.withAlphaComponent(0.08).cgColor
        }
    }

    private func applyColorSelection() {
        let activeColor = canvasView.currentColor
        for (i, btn) in colorButtons.enumerated() {
            let color = AnnotationPalette.colors[i]
            let active = color == activeColor
            btn.layer.borderWidth = active ? 2.5 : 1
            btn.layer.borderColor = active
                ? GripeColor.textPrimary.cgColor
                : UIColor.black.withAlphaComponent(0.12).cgColor
            btn.transform = active ? CGAffineTransform(scaleX: 1.1, y: 1.1) : .identity
        }
    }

    private func refreshUndoRedo() {
        undoButton.isEnabled = canvasView.canUndo
        undoButton.alpha = canvasView.canUndo ? 1 : 0.35
        redoButton.isEnabled = canvasView.canRedo
        redoButton.alpha = canvasView.canRedo ? 1 : 0.35
    }

    // MARK: Actions

    @objc private func toolTapped(_ sender: UIButton) {
        guard let tool = AnnotationTool(rawValue: sender.tag) else { return }
        canvasView.currentTool = tool
        UIView.animate(withDuration: 0.15) { self.applyToolSelection() }
    }

    @objc private func colorTapped(_ sender: UIButton) {
        let color = AnnotationPalette.colors[sender.tag]
        canvasView.currentColor = color
        UIView.animate(withDuration: 0.15) { self.applyColorSelection() }
    }

    @objc private func undoTapped() {
        canvasView.undo()
        refreshUndoRedo()
    }

    @objc private func redoTapped() {
        canvasView.redo()
        refreshUndoRedo()
    }

    @objc private func backTapped() {
        let onCancel = self.onCancel
        dismiss(animated: true) { onCancel() }
    }

    @objc private func doneTapped() {
        let result = canvasView.render()
        let onDone = self.onDone
        dismiss(animated: true) { onDone(result) }
    }
}
#endif
