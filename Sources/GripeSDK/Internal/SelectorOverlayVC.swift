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
    private let modeControl = UISegmentedControl(items: ["Element", "Crop"])
    private let topBar = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
    private let cancelButton = UIButton(type: .system)
    private let nextButton = UIButton(type: .system)
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

        topBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(topBar)

        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.tintColor = .white
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false

        nextButton.setTitle("Next", for: .normal)
        nextButton.tintColor = .white
        nextButton.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        nextButton.addTarget(self, action: #selector(nextTapped), for: .touchUpInside)
        nextButton.translatesAutoresizingMaskIntoConstraints = false

        modeControl.selectedSegmentIndex = 0
        modeControl.addTarget(self, action: #selector(modeChanged), for: .valueChanged)
        modeControl.translatesAutoresizingMaskIntoConstraints = false

        topBar.contentView.addSubview(cancelButton)
        topBar.contentView.addSubview(modeControl)
        topBar.contentView.addSubview(nextButton)

        hint.text = "Tap a UI element"
        hint.textColor = UIColor.white.withAlphaComponent(0.85)
        hint.font = .preferredFont(forTextStyle: .footnote)
        hint.textAlignment = .center
        hint.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hint)

        let imageRect: () -> CGRect = { [weak self] in self?.displayedImageRect() ?? .zero }
        highlighter.configure(
            hierarchy: hierarchy,
            windowBounds: windowBounds,
            imageRect: imageRect
        )
        cropView.configure(imageRect: imageRect)

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

            topBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topBar.topAnchor.constraint(equalTo: view.topAnchor),
            topBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 56),

            cancelButton.leadingAnchor.constraint(equalTo: topBar.contentView.leadingAnchor, constant: 16),
            cancelButton.bottomAnchor.constraint(equalTo: topBar.contentView.bottomAnchor, constant: -10),

            nextButton.trailingAnchor.constraint(equalTo: topBar.contentView.trailingAnchor, constant: -16),
            nextButton.bottomAnchor.constraint(equalTo: topBar.contentView.bottomAnchor, constant: -10),

            modeControl.centerXAnchor.constraint(equalTo: topBar.contentView.centerXAnchor),
            modeControl.centerYAnchor.constraint(equalTo: cancelButton.centerYAnchor),
            modeControl.widthAnchor.constraint(equalToConstant: 180),

            hint.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            hint.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            hint.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
        ])
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        highlighter.refresh()
        cropView.refreshIfNeeded()
    }

    private func displayedImageRect() -> CGRect {
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

    @objc private func modeChanged() {
        mode = Mode(rawValue: modeControl.selectedSegmentIndex) ?? .element
        highlighter.isHidden = mode != .element
        cropView.isHidden = mode != .crop
        hint.text = mode == .element ? "Tap a UI element" : "Drag to draw a region"
        if mode == .crop { cropView.refreshIfNeeded() }
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
        let nav = UINavigationController(rootViewController: composer)
        nav.modalPresentationStyle = .formSheet
        present(nav, animated: true)
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
