import UIKit

final class SelectorOverlayVC: UIViewController {
    enum Mode: Int { case element = 0, crop = 1 }

    private let snapshot: UIImage
    private let hierarchy: CapturedNode
    private let windowBounds: CGRect
    private let onClose: () -> Void

    private let imageView = UIImageView()
    private let highlighter = ElementHighlighter()
    private let cropView = CropRectView()

    private let titlePill = PaddedLabel()
    private let cancelButton = UIButton(type: .system)
    private let modeTogglePill = UIButton(type: .system)
    private let nextButton = GripePrimaryButton(title: "Next", systemImage: "arrow.right")
    private let hint = UILabel()

    private var mode: Mode = .element

    init(snapshot: UIImage, hierarchy: CapturedNode, windowBounds: CGRect, onClose: @escaping () -> Void) {
        self.snapshot = snapshot
        self.hierarchy = hierarchy
        self.windowBounds = windowBounds
        self.onClose = onClose
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        imageView.image = snapshot
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.isUserInteractionEnabled = false
        view.addSubview(imageView)

        highlighter.translatesAutoresizingMaskIntoConstraints = false
        highlighter.backgroundColor = .clear
        view.addSubview(highlighter)

        cropView.translatesAutoresizingMaskIntoConstraints = false
        cropView.backgroundColor = .clear
        cropView.isHidden = true
        view.addSubview(cropView)

        configureTitlePill()
        configureCancelButton()
        configureModeTogglePill()
        configureNextButton()
        configureHint()

        view.addSubview(titlePill)
        view.addSubview(cancelButton)
        view.addSubview(modeTogglePill)
        view.addSubview(hint)
        view.addSubview(nextButton)

        let imageRect: () -> CGRect = { [weak self] in self?.displayedImageRect() ?? .zero }
        highlighter.configure(
            hierarchy: hierarchy,
            windowBounds: windowBounds,
            imageRect: imageRect
        )
        cropView.configure(imageRect: imageRect)

        let selectionChanged: () -> Void = { [weak self] in self?.updateNextButtonVisibility() }
        highlighter.onSelectionChanged = selectionChanged
        cropView.onSelectionChanged = selectionChanged

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: view.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            highlighter.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            highlighter.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            highlighter.topAnchor.constraint(equalTo: view.topAnchor),
            highlighter.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            cropView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            cropView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            cropView.topAnchor.constraint(equalTo: view.topAnchor),
            cropView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            titlePill.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titlePill.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: GripeSpacing.s),

            cancelButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -GripeSpacing.l),
            cancelButton.centerYAnchor.constraint(equalTo: titlePill.centerYAnchor),

            modeTogglePill.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            modeTogglePill.bottomAnchor.constraint(equalTo: hint.topAnchor, constant: -GripeSpacing.s),

            hint.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: GripeSpacing.l),
            hint.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -GripeSpacing.l),
            hint.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -GripeSpacing.l),

            nextButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -GripeSpacing.l),
            nextButton.bottomAnchor.constraint(equalTo: modeTogglePill.topAnchor, constant: -GripeSpacing.m),
        ])

        updateNextButtonVisibility()
    }

    private func configureTitlePill() {
        titlePill.text = "Select an area"
        titlePill.font = GripeFont.bodyMedium()
        titlePill.textColor = GripeColor.textPrimary
        titlePill.backgroundColor = .white
        titlePill.textInsets = UIEdgeInsets(top: 10, left: GripeSpacing.l, bottom: 10, right: GripeSpacing.l)
        titlePill.layer.cornerRadius = 16
        titlePill.layer.borderWidth = 1
        titlePill.layer.borderColor = GripeColor.border.cgColor
        titlePill.layer.masksToBounds = true
        titlePill.translatesAutoresizingMaskIntoConstraints = false
    }

    private func configureCancelButton() {
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.setTitleColor(GripeColor.primary, for: .normal)
        cancelButton.titleLabel?.font = GripeFont.bodyMedium()
        cancelButton.tintColor = GripeColor.primary
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
    }

    private func configureModeTogglePill() {
        modeTogglePill.setTitle("Switch to Crop", for: .normal)
        modeTogglePill.setTitleColor(GripeColor.primary, for: .normal)
        modeTogglePill.titleLabel?.font = GripeFont.bodyMedium()
        modeTogglePill.backgroundColor = .white
        modeTogglePill.contentEdgeInsets = UIEdgeInsets(top: 10, left: GripeSpacing.l, bottom: 10, right: GripeSpacing.l)
        modeTogglePill.layer.cornerRadius = 16
        modeTogglePill.layer.borderWidth = 1
        modeTogglePill.layer.borderColor = GripeColor.border.cgColor
        modeTogglePill.layer.masksToBounds = true
        modeTogglePill.addTarget(self, action: #selector(toggleMode), for: .touchUpInside)
        modeTogglePill.translatesAutoresizingMaskIntoConstraints = false
    }

    private func configureNextButton() {
        nextButton.translatesAutoresizingMaskIntoConstraints = false
        nextButton.addTarget(self, action: #selector(nextTapped), for: .touchUpInside)
        nextButton.isHidden = true
    }

    private func configureHint() {
        hint.text = "Tap an element"
        hint.textColor = UIColor.white.withAlphaComponent(0.85)
        hint.font = GripeFont.caption()
        hint.textAlignment = .center
        hint.translatesAutoresizingMaskIntoConstraints = false
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        highlighter.refresh()
        cropView.refreshIfNeeded()
    }

    func displayedImageRect() -> CGRect {
        guard let image = imageView.image, image.size.width > 0, image.size.height > 0 else {
            return imageView.frame
        }
        let viewSize = imageView.bounds.size
        let scale = min(viewSize.width / image.size.width, viewSize.height / image.size.height)
        let displaySize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let origin = CGPoint(
            x: imageView.frame.origin.x + (viewSize.width - displaySize.width) / 2,
            y: imageView.frame.origin.y + (viewSize.height - displaySize.height) / 2
        )
        return CGRect(origin: origin, size: displaySize)
    }

    @objc private func toggleMode() {
        mode = (mode == .element) ? .crop : .element
        highlighter.isHidden = mode != .element
        cropView.isHidden = mode != .crop
        hint.text = mode == .element ? "Tap an element" : "Drag to draw an area"
        modeTogglePill.setTitle(mode == .element ? "Switch to Crop" : "Switch to Element", for: .normal)
        if mode == .crop { cropView.refreshIfNeeded() }
        updateNextButtonVisibility()
    }

    private func updateNextButtonVisibility() {
        let rect: CGRect?
        switch mode {
        case .element: rect = highlighter.selectedRectInView
        case .crop: rect = cropView.cropRectInView
        }
        let hasSelection = rect.map { $0.width > 4 && $0.height > 4 } ?? false
        nextButton.isHidden = !hasSelection
    }

    @objc private func cancelTapped() {
        finish(animated: true)
    }

    @objc private func nextTapped() {
        let selectedRect: CGRect?
        switch mode {
        case .element: selectedRect = highlighter.selectedRectInView
        case .crop: selectedRect = cropView.cropRectInView
        }
        guard let rect = selectedRect, rect.width > 4, rect.height > 4 else {
            flashHint(text: mode == .element ? "Tap an element first" : "Draw a region first")
            return
        }
        let cropped = crop(image: snapshot, rectInView: rect) ?? snapshot
        let composer = CommentComposerVC(croppedImage: cropped, onFinished: { [weak self] in
            self?.finish(animated: false)
        })
        if #available(iOS 15.0, *) {
            composer.modalPresentationStyle = .pageSheet
            if let sheet = composer.sheetPresentationController {
                sheet.detents = [.large()]
                sheet.prefersGrabberVisible = true
            }
        } else {
            composer.modalPresentationStyle = .formSheet
        }
        present(composer, animated: true)
    }

    private func flashHint(text: String) {
        hint.text = text
        UIView.animate(withDuration: 0.1, animations: { self.hint.alpha = 0.3 }) { _ in
            UIView.animate(withDuration: 0.1) { self.hint.alpha = 1 }
        }
    }

    private func crop(image: UIImage, rectInView: CGRect) -> UIImage? {
        let imageRect = displayedImageRect()
        guard imageRect.width > 0, imageRect.height > 0 else { return nil }
        let scaleX = image.size.width / imageRect.width
        let scaleY = image.size.height / imageRect.height
        let normalized = CGRect(
            x: (rectInView.minX - imageRect.minX) * scaleX,
            y: (rectInView.minY - imageRect.minY) * scaleY,
            width: rectInView.width * scaleX,
            height: rectInView.height * scaleY
        ).integral
        let pxRect = CGRect(
            x: normalized.minX * image.scale,
            y: normalized.minY * image.scale,
            width: normalized.width * image.scale,
            height: normalized.height * image.scale
        )
        guard let cg = image.cgImage?.cropping(to: pxRect) else { return nil }
        return UIImage(cgImage: cg, scale: image.scale, orientation: image.imageOrientation)
    }

    private func finish(animated: Bool) {
        let onClose = self.onClose
        dismiss(animated: animated) {
            onClose()
        }
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
