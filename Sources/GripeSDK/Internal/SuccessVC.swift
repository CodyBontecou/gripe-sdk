import UIKit

final class SuccessVC: UIViewController {
    private let issueURL: URL
    private let issueNumber: Int?
    private let issueTitle: String
    private let croppedImage: UIImage?
    private let metadata: GripeMetadata
    private let onFinished: () -> Void

    private let copyButton = GripeSecondaryButton(title: "Copy Link", systemImage: "link")
    private var copyResetWorkItem: DispatchWorkItem?

    init(issueURL: URL,
         issueNumber: Int?,
         title: String,
         croppedImage: UIImage?,
         metadata: GripeMetadata,
         onFinished: @escaping () -> Void) {
        self.issueURL = issueURL
        self.issueNumber = issueNumber
        self.issueTitle = title
        self.croppedImage = croppedImage
        self.metadata = metadata
        self.onFinished = onFinished
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = GripeColor.background
        buildLayout()
    }

    private func buildLayout() {
        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.alwaysBounceVertical = true
        view.addSubview(scroll)

        let content = UIView()
        content.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(content)

        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            content.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            content.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            content.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            content.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor),
            content.heightAnchor.constraint(greaterThanOrEqualTo: scroll.frameLayoutGuide.heightAnchor),
        ])

        let closeButton = UIButton(type: .system)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.setImage(UIImage(systemName: "xmark",
                                     withConfiguration: UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)),
                             for: .normal)
        closeButton.tintColor = GripeColor.textSecondary
        closeButton.addTarget(self, action: #selector(handleClose), for: .touchUpInside)
        content.addSubview(closeButton)

        let badge = makeCheckBadge()
        let titleLabel = UILabel()
        titleLabel.text = "Issue created"
        titleLabel.font = GripeFont.headline()
        titleLabel.textColor = GripeColor.textPrimary
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let subtitleLabel = UILabel()
        if let n = issueNumber {
            subtitleLabel.text = "#\(n) \(issueTitle)"
        } else {
            subtitleLabel.text = issueTitle
        }
        subtitleLabel.font = GripeFont.body()
        subtitleLabel.textColor = GripeColor.textSecondary
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        let card = makeMetadataCard()

        let openButton = GripePrimaryButton(title: "Open in GitHub", systemImage: "arrow.up.right.square")
        openButton.addTarget(self, action: #selector(handleOpen), for: .touchUpInside)

        copyButton.addTarget(self, action: #selector(handleCopy), for: .touchUpInside)

        let doneButton = UIButton(type: .system)
        doneButton.translatesAutoresizingMaskIntoConstraints = false
        var doneAttr = AttributedString("Done")
        doneAttr.font = GripeFont.bodyMedium()
        doneAttr.foregroundColor = GripeColor.textSecondary
        var doneConfig = UIButton.Configuration.plain()
        doneConfig.attributedTitle = doneAttr
        doneConfig.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)
        doneButton.configuration = doneConfig
        doneButton.addTarget(self, action: #selector(handleDone), for: .touchUpInside)

        let buttonsStack = UIStackView(arrangedSubviews: [openButton, copyButton, doneButton])
        buttonsStack.axis = .vertical
        buttonsStack.spacing = 8
        buttonsStack.alignment = .fill
        buttonsStack.translatesAutoresizingMaskIntoConstraints = false

        content.addSubview(badge)
        content.addSubview(titleLabel)
        content.addSubview(subtitleLabel)
        content.addSubview(card)
        content.addSubview(buttonsStack)

        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: content.safeAreaLayoutGuide.topAnchor, constant: 16),
            closeButton.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),
            closeButton.widthAnchor.constraint(equalToConstant: 32),
            closeButton.heightAnchor.constraint(equalToConstant: 32),

            badge.centerXAnchor.constraint(equalTo: content.centerXAnchor),
            badge.topAnchor.constraint(greaterThanOrEqualTo: closeButton.bottomAnchor, constant: 24),
            badge.topAnchor.constraint(equalTo: content.safeAreaLayoutGuide.topAnchor, constant: 64),

            titleLabel.topAnchor.constraint(equalTo: badge.bottomAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            subtitleLabel.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),

            card.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 24),
            card.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            card.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),

            buttonsStack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            buttonsStack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            buttonsStack.topAnchor.constraint(greaterThanOrEqualTo: card.bottomAnchor, constant: 24),
            buttonsStack.bottomAnchor.constraint(equalTo: content.safeAreaLayoutGuide.bottomAnchor, constant: -16),
        ])
    }

    private func makeCheckBadge() -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.backgroundColor = GripeColor.success
        container.layer.cornerRadius = 40
        container.clipsToBounds = true

        let check = UIImageView(image: UIImage(systemName: "checkmark",
                                               withConfiguration: UIImage.SymbolConfiguration(pointSize: 36, weight: .semibold)))
        check.tintColor = .white
        check.contentMode = .scaleAspectFit
        check.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(check)

        NSLayoutConstraint.activate([
            container.widthAnchor.constraint(equalToConstant: 80),
            container.heightAnchor.constraint(equalToConstant: 80),
            check.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            check.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        ])
        return container
    }

    private func makeMetadataCard() -> UIView {
        let card = UIView()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.backgroundColor = GripeColor.surface
        card.layer.cornerRadius = GripeRadius.card
        card.layer.borderColor = GripeColor.border.cgColor
        card.layer.borderWidth = 1

        let dateFmt = DateFormatter()
        dateFmt.dateStyle = .medium
        dateFmt.timeStyle = .short

        let rows: [(String, String)] = [
            ("Captured", dateFmt.string(from: metadata.capturedAt)),
            ("Screen", metadata.viewControllerName ?? "—"),
            ("Product", metadata.bundleIdentifier),
            ("OS", "\(metadata.osName) \(metadata.osVersion)"),
            ("Device", metadata.deviceModel),
            ("App", "\(metadata.appVersion) (\(metadata.build))"),
        ]

        let rowsStack = UIStackView()
        rowsStack.axis = .vertical
        rowsStack.spacing = 6
        rowsStack.alignment = .fill
        rowsStack.translatesAutoresizingMaskIntoConstraints = false
        for (key, value) in rows {
            rowsStack.addArrangedSubview(makeMetadataRow(key: key, value: value))
        }
        card.addSubview(rowsStack)

        var thumbnail: UIImageView?
        if let img = croppedImage {
            let iv = UIImageView(image: img)
            iv.translatesAutoresizingMaskIntoConstraints = false
            iv.contentMode = .scaleAspectFill
            iv.clipsToBounds = true
            iv.layer.cornerRadius = 8
            iv.layer.borderColor = GripeColor.border.cgColor
            iv.layer.borderWidth = 1
            card.addSubview(iv)
            thumbnail = iv
        }

        var constraints: [NSLayoutConstraint] = [
            rowsStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            rowsStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            rowsStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
        ]

        if let thumbnail {
            constraints.append(contentsOf: [
                thumbnail.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
                thumbnail.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
                thumbnail.widthAnchor.constraint(equalToConstant: 56),
                thumbnail.heightAnchor.constraint(equalToConstant: 56),
                rowsStack.trailingAnchor.constraint(lessThanOrEqualTo: thumbnail.leadingAnchor, constant: -12),
            ])
        } else {
            constraints.append(rowsStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16))
        }

        NSLayoutConstraint.activate(constraints)
        return card
    }

    private func makeMetadataRow(key: String, value: String) -> UIView {
        let keyLabel = UILabel()
        keyLabel.text = key
        keyLabel.font = GripeFont.captionMedium()
        keyLabel.textColor = GripeColor.textSecondary
        keyLabel.translatesAutoresizingMaskIntoConstraints = false
        keyLabel.setContentHuggingPriority(.required, for: .horizontal)
        keyLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = GripeFont.body()
        valueLabel.textColor = GripeColor.textPrimary
        valueLabel.numberOfLines = 0
        valueLabel.textAlignment = .left
        valueLabel.translatesAutoresizingMaskIntoConstraints = false

        let row = UIStackView(arrangedSubviews: [keyLabel, valueLabel])
        row.axis = .horizontal
        row.alignment = .firstBaseline
        row.spacing = 12
        row.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            keyLabel.widthAnchor.constraint(equalToConstant: 80),
        ])
        return row
    }

    @objc private func handleOpen() {
        UIApplication.shared.open(issueURL)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.onFinished()
        }
    }

    @objc private func handleCopy() {
        UIPasteboard.general.string = issueURL.absoluteString
        var attr = AttributedString("Copied")
        attr.font = GripeFont.bodyMedium()
        var config = copyButton.configuration
        config?.attributedTitle = attr
        config?.image = UIImage(systemName: "checkmark")?
            .withConfiguration(UIImage.SymbolConfiguration(pointSize: 16, weight: .medium))
        copyButton.configuration = config

        copyResetWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            var restored = AttributedString("Copy Link")
            restored.font = GripeFont.bodyMedium()
            var c = self.copyButton.configuration
            c?.attributedTitle = restored
            c?.image = UIImage(systemName: "link")?
                .withConfiguration(UIImage.SymbolConfiguration(pointSize: 16, weight: .medium))
            self.copyButton.configuration = c
        }
        copyResetWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: work)
    }

    @objc private func handleDone() {
        onFinished()
    }

    @objc private func handleClose() {
        onFinished()
    }
}
