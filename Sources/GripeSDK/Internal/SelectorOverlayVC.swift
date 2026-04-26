#if canImport(UIKit)
import UIKit

final class SelectorOverlayVC: UIViewController {
    private let snapshot: UIImage
    private let onClose: () -> Void

    private let imageView = UIImageView()
    private let cropView = CropRectView()

    private let titlePill = UIView()
    private let titleLabel = UILabel()
    private let infoButton = UIButton(type: .system)
    private let cancelButton = UIButton(type: .custom)
    private let nextButton = GripePrimaryButton(title: "Next", systemImage: "arrow.right")

    init(snapshot: UIImage, onClose: @escaping () -> Void) {
        self.snapshot = snapshot
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

        cropView.translatesAutoresizingMaskIntoConstraints = false
        cropView.backgroundColor = .clear
        view.addSubview(cropView)

        configureTitlePill()
        configureCancelButton()
        configureNextButton()

        view.addSubview(titlePill)
        view.addSubview(cancelButton)
        view.addSubview(nextButton)

        let imageRect: () -> CGRect = { [weak self] in self?.displayedImageRect() ?? .zero }
        cropView.configure(imageRect: imageRect)
        cropView.onSelectionChanged = { [weak self] in self?.updateNextButtonVisibility() }

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: view.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            cropView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            cropView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            cropView.topAnchor.constraint(equalTo: view.topAnchor),
            cropView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            titlePill.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titlePill.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: GripeSpacing.s),

            cancelButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -GripeSpacing.l),
            cancelButton.centerYAnchor.constraint(equalTo: titlePill.centerYAnchor),
            cancelButton.widthAnchor.constraint(equalToConstant: 36),
            cancelButton.heightAnchor.constraint(equalToConstant: 36),

            nextButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -GripeSpacing.l),
            nextButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -GripeSpacing.l),
        ])

        updateNextButtonVisibility()
    }

    private func configureTitlePill() {
        titlePill.backgroundColor = .white
        titlePill.layer.cornerRadius = 18
        titlePill.layer.borderWidth = 1
        titlePill.layer.borderColor = GripeColor.border.cgColor
        titlePill.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.text = "Gripe"
        titleLabel.font = GripeFont.bodySemibold()
        titleLabel.textColor = GripeColor.textPrimary
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titlePill.addSubview(titleLabel)

        infoButton.setImage(UIImage(systemName: "info.circle")?
            .withConfiguration(UIImage.SymbolConfiguration(pointSize: 18, weight: .regular)), for: .normal)
        infoButton.tintColor = GripeColor.textSecondary
        infoButton.addTarget(self, action: #selector(infoTapped), for: .touchUpInside)
        infoButton.translatesAutoresizingMaskIntoConstraints = false
        titlePill.addSubview(infoButton)

        NSLayoutConstraint.activate([
            titlePill.heightAnchor.constraint(equalToConstant: 36),

            titleLabel.leadingAnchor.constraint(equalTo: titlePill.leadingAnchor, constant: GripeSpacing.l),
            titleLabel.centerYAnchor.constraint(equalTo: titlePill.centerYAnchor),

            infoButton.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 6),
            infoButton.trailingAnchor.constraint(equalTo: titlePill.trailingAnchor, constant: -10),
            infoButton.centerYAnchor.constraint(equalTo: titlePill.centerYAnchor),
            infoButton.widthAnchor.constraint(equalToConstant: 28),
            infoButton.heightAnchor.constraint(equalToConstant: 28),
        ])
    }

    private func configureCancelButton() {
        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: "xmark")?
            .withConfiguration(UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold))
        config.baseForegroundColor = GripeColor.textPrimary
        config.contentInsets = .zero
        cancelButton.configuration = config
        cancelButton.backgroundColor = .white
        cancelButton.layer.cornerRadius = 18
        cancelButton.layer.shadowColor = UIColor.black.cgColor
        cancelButton.layer.shadowOpacity = 0.2
        cancelButton.layer.shadowOffset = CGSize(width: 0, height: 2)
        cancelButton.layer.shadowRadius = 6
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
    }

    private func configureNextButton() {
        nextButton.translatesAutoresizingMaskIntoConstraints = false
        nextButton.addTarget(self, action: #selector(nextTapped), for: .touchUpInside)
        nextButton.isHidden = true
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
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

    private func updateNextButtonVisibility() {
        let rect = cropView.cropRectInView
        let hasSelection = rect.map { $0.width > 4 && $0.height > 4 } ?? false
        nextButton.isHidden = !hasSelection
    }

    @objc private func cancelTapped() {
        finish(animated: true)
    }

    @objc private func infoTapped() {
        let docs = DocsSheetVC()
        if #available(iOS 15.0, *) {
            docs.modalPresentationStyle = .pageSheet
            if let sheet = docs.sheetPresentationController {
                if #available(iOS 16.0, *) {
                    sheet.detents = [.medium(), .large()]
                } else {
                    sheet.detents = [.medium(), .large()]
                }
                sheet.prefersGrabberVisible = true
            }
        } else {
            docs.modalPresentationStyle = .formSheet
        }
        present(docs, animated: true)
    }

    @objc private func nextTapped() {
        guard let rect = cropView.cropRectInView, rect.width > 4, rect.height > 4 else { return }
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
#endif

