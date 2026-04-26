import UIKit

// MARK: - Buttons

final class GripePrimaryButton: UIButton {
    init(title: String, systemImage: String? = nil) {
        super.init(frame: .zero)
        var config = UIButton.Configuration.filled()
        config.cornerStyle = .fixed
        config.background.cornerRadius = GripeRadius.button
        config.background.backgroundColor = GripeColor.primary
        config.baseForegroundColor = .white
        config.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 18, bottom: 14, trailing: 18)
        config.imagePadding = 8
        if let systemImage {
            config.image = UIImage(systemName: systemImage)?
                .withConfiguration(UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold))
        }
        var attr = AttributedString(title)
        attr.font = GripeFont.bodySemibold()
        config.attributedTitle = attr
        configuration = config
        configurationUpdateHandler = { btn in
            var c = btn.configuration
            c?.background.backgroundColor = btn.isHighlighted ? GripeColor.primaryDark : GripeColor.primary
            btn.configuration = c
        }
        translatesAutoresizingMaskIntoConstraints = false
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }
}

final class GripeSecondaryButton: UIButton {
    init(title: String, systemImage: String? = nil) {
        super.init(frame: .zero)
        var config = UIButton.Configuration.plain()
        config.background.strokeColor = GripeColor.border
        config.background.strokeWidth = 1
        config.background.cornerRadius = GripeRadius.button
        config.background.backgroundColor = GripeColor.surface
        config.baseForegroundColor = GripeColor.textPrimary
        config.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 18, bottom: 14, trailing: 18)
        config.imagePadding = 8
        if let systemImage {
            config.image = UIImage(systemName: systemImage)?
                .withConfiguration(UIImage.SymbolConfiguration(pointSize: 16, weight: .medium))
        }
        var attr = AttributedString(title)
        attr.font = GripeFont.bodyMedium()
        config.attributedTitle = attr
        configuration = config
        configurationUpdateHandler = { btn in
            var c = btn.configuration
            c?.background.backgroundColor = btn.isHighlighted ? GripeColor.chipFill : GripeColor.surface
            btn.configuration = c
        }
        translatesAutoresizingMaskIntoConstraints = false
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }
}

// MARK: - Chip

final class GripeChip: UIControl {
    let title: String
    let systemImage: String?

    private let stack = UIStackView()
    private let icon = UIImageView()
    private let label = UILabel()

    var isSelectedChip: Bool = false { didSet { applyState() } }

    init(title: String, systemImage: String? = nil) {
        self.title = title
        self.systemImage = systemImage
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        layer.cornerRadius = GripeRadius.chip
        layer.borderWidth = 1
        clipsToBounds = true

        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 6
        stack.isUserInteractionEnabled = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        if let systemImage {
            icon.image = UIImage(systemName: systemImage)?
                .withConfiguration(UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold))
            icon.contentMode = .scaleAspectFit
            stack.addArrangedSubview(icon)
        }

        label.text = title
        label.font = GripeFont.chip()
        stack.addArrangedSubview(label)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            heightAnchor.constraint(equalToConstant: 32),
        ])
        applyState()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    override var isHighlighted: Bool { didSet { alpha = isHighlighted ? 0.7 : 1 } }

    private func applyState() {
        if isSelectedChip {
            backgroundColor = GripeColor.primary.withAlphaComponent(0.1)
            layer.borderColor = GripeColor.primary.cgColor
            label.textColor = GripeColor.primary
            icon.tintColor = GripeColor.primary
        } else {
            backgroundColor = GripeColor.surface
            layer.borderColor = GripeColor.border.cgColor
            label.textColor = GripeColor.textSecondary
            icon.tintColor = GripeColor.textSecondary
        }
    }
}

// MARK: - Repository selector

final class GripeRepoSelector: UIControl {
    private let icon = UIImageView()
    private let label = UILabel()
    private let chevron = UIImageView()

    var repository: String = "owner/app-ios" {
        didSet { label.text = repository }
    }

    init(repository: String) {
        self.repository = repository
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = GripeColor.surface
        layer.cornerRadius = GripeRadius.field
        layer.borderColor = GripeColor.border.cgColor
        layer.borderWidth = 1

        icon.image = UIImage(systemName: "chevron.left.forwardslash.chevron.right")?
            .withConfiguration(UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold))
        icon.tintColor = GripeColor.textPrimary
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false
        addSubview(icon)

        label.text = repository
        label.font = GripeFont.bodyMedium()
        label.textColor = GripeColor.textPrimary
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        chevron.image = UIImage(systemName: "chevron.right")?
            .withConfiguration(UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold))
        chevron.tintColor = GripeColor.textSecondary
        chevron.contentMode = .scaleAspectFit
        chevron.translatesAutoresizingMaskIntoConstraints = false
        addSubview(chevron)

        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            icon.centerYAnchor.constraint(equalTo: centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 22),
            icon.heightAnchor.constraint(equalToConstant: 22),

            label.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 10),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),

            chevron.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            chevron.centerYAnchor.constraint(equalTo: centerYAnchor),

            heightAnchor.constraint(equalToConstant: 52),
        ])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    override var isHighlighted: Bool { didSet { alpha = isHighlighted ? 0.6 : 1 } }
}

// MARK: - Single-line text field

final class GripeTextField: UIView {
    let textField = UITextField()

    init(placeholder: String) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = GripeColor.surface
        layer.cornerRadius = GripeRadius.field
        layer.borderColor = GripeColor.border.cgColor
        layer.borderWidth = 1

        textField.font = GripeFont.body()
        textField.textColor = GripeColor.textPrimary
        textField.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [.foregroundColor: GripeColor.textSecondary]
        )
        textField.translatesAutoresizingMaskIntoConstraints = false
        addSubview(textField)

        NSLayoutConstraint.activate([
            textField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            textField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            textField.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            textField.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            heightAnchor.constraint(equalToConstant: 48),
        ])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }
}

// MARK: - Multi-line comment area

final class GripeTextArea: UIView, UITextViewDelegate {
    let textView = UITextView()
    private let placeholderLabel = UILabel()

    var onChange: ((String) -> Void)?

    init(placeholder: String) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = GripeColor.surface
        layer.cornerRadius = GripeRadius.field
        layer.borderColor = GripeColor.border.cgColor
        layer.borderWidth = 1

        textView.font = GripeFont.body()
        textView.textColor = GripeColor.textPrimary
        textView.backgroundColor = .clear
        textView.delegate = self
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 10, bottom: 12, right: 10)
        textView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(textView)

        placeholderLabel.text = placeholder
        placeholderLabel.font = GripeFont.body()
        placeholderLabel.textColor = GripeColor.textSecondary
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(placeholderLabel)

        NSLayoutConstraint.activate([
            textView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            textView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            textView.topAnchor.constraint(equalTo: topAnchor, constant: 0),
            textView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: 0),

            placeholderLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            placeholderLabel.topAnchor.constraint(equalTo: topAnchor, constant: 14),
        ])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    func textViewDidChange(_ textView: UITextView) {
        placeholderLabel.isHidden = !textView.text.isEmpty
        onChange?(textView.text)
    }
}

// MARK: - Form section label (small uppercase)

final class GripeFieldLabel: UILabel {
    init(_ text: String) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        self.text = text
        font = GripeFont.captionMedium()
        textColor = GripeColor.textSecondary
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }
}

// MARK: - Brand logo (chat bubble + dot)

final class GripeLogoView: UIView {
    init(size: CGFloat = 28) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = GripeColor.primary
        layer.cornerRadius = size * 0.28
        clipsToBounds = true

        let icon = UIImageView(image: UIImage(systemName: "bubble.left.fill")?
            .withConfiguration(UIImage.SymbolConfiguration(pointSize: size * 0.55, weight: .bold)))
        icon.tintColor = .white
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false
        addSubview(icon)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: size),
            heightAnchor.constraint(equalToConstant: size),
            icon.centerXAnchor.constraint(equalTo: centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -1),
        ])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }
}
