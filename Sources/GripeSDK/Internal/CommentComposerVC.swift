import UIKit

final class CommentComposerVC: UIViewController {
    static let issueSubmittedNotification = Notification.Name("GripeIssueSubmitted")

    private let croppedImage: UIImage
    private let onFinished: () -> Void

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    private let titleLabel = UILabel()
    private let closeButton = UIButton(type: .system)

    private let thumbnailView = UIImageView()
    private let commentArea = GripeTextArea(placeholder: "Describe what you're seeing\u{2026}")
    private let titleField = GripeTextField(placeholder: "Short summary")

    private let bugChip = GripeChip(title: "Bug", systemImage: "ant.fill")
    private let ideaChip = GripeChip(title: "Idea", systemImage: "lightbulb")
    private let polishChip = GripeChip(title: "Polish", systemImage: "sparkles")

    private let repoSelector: GripeRepoSelector
    private let submitButton = GripePrimaryButton(title: "Send to GitHub", systemImage: "paperplane.fill")
    private let activity = UIActivityIndicatorView(style: .medium)

    init(croppedImage: UIImage, onFinished: @escaping () -> Void) {
        self.croppedImage = croppedImage
        self.onFinished = onFinished
        let repo = Gripe.shared.configuration?.repository ?? "owner/app-ios"
        self.repoSelector = GripeRepoSelector(repository: repo)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = GripeColor.background

        setupScroll()
        setupHeader()
        setupContent()
        setupSubmit()
        setupActions()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            self?.commentArea.textView.becomeFirstResponder()
        }
    }

    private func setupScroll() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        scrollView.keyboardDismissMode = .interactive
        view.addSubview(scrollView)

        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.axis = .vertical
        contentStack.spacing = GripeSpacing.l
        contentStack.alignment = .fill
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: GripeSpacing.xl),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: GripeSpacing.xl),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -GripeSpacing.xl),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -GripeSpacing.xl),
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -GripeSpacing.xl * 2),
        ])
    }

    private func setupHeader() {
        let headerRow = UIView()
        headerRow.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.text = "New GitHub Issue"
        titleLabel.font = GripeFont.headline()
        titleLabel.textColor = GripeColor.textPrimary
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        headerRow.addSubview(titleLabel)

        closeButton.setImage(
            UIImage(systemName: "xmark.circle.fill")?
                .withConfiguration(UIImage.SymbolConfiguration(pointSize: 28, weight: .regular)),
            for: .normal
        )
        closeButton.tintColor = GripeColor.textSecondary
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        headerRow.addSubview(closeButton)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: headerRow.leadingAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: headerRow.centerYAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: closeButton.leadingAnchor, constant: -GripeSpacing.s),

            closeButton.trailingAnchor.constraint(equalTo: headerRow.trailingAnchor),
            closeButton.centerYAnchor.constraint(equalTo: headerRow.centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 32),
            closeButton.heightAnchor.constraint(equalToConstant: 32),

            headerRow.heightAnchor.constraint(greaterThanOrEqualToConstant: 32),
        ])

        contentStack.addArrangedSubview(headerRow)
    }

    private func setupContent() {
        contentStack.addArrangedSubview(makeSection(label: "Comment", control: makeCommentBlock()))
        contentStack.addArrangedSubview(makeSection(label: "Title", control: titleField))
        contentStack.addArrangedSubview(makeSection(label: "Tags", control: makeTagsRow()))
        contentStack.addArrangedSubview(makeSection(label: "Repository", control: repoSelector))

        let spacer = UIView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.setContentHuggingPriority(.defaultLow, for: .vertical)
        spacer.heightAnchor.constraint(greaterThanOrEqualToConstant: GripeSpacing.l).isActive = true
        contentStack.addArrangedSubview(spacer)
    }

    private func makeSection(label: String, control: UIView) -> UIView {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = GripeSpacing.s
        stack.alignment = .fill
        stack.addArrangedSubview(GripeFieldLabel(label))
        stack.addArrangedSubview(control)
        return stack
    }

    private func makeCommentBlock() -> UIView {
        let container = UIStackView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.axis = .vertical
        container.spacing = GripeSpacing.s
        container.alignment = .leading

        thumbnailView.image = croppedImage
        thumbnailView.contentMode = .scaleAspectFill
        thumbnailView.clipsToBounds = true
        thumbnailView.layer.cornerRadius = 10
        thumbnailView.layer.borderColor = GripeColor.border.cgColor
        thumbnailView.layer.borderWidth = 1
        thumbnailView.translatesAutoresizingMaskIntoConstraints = false

        commentArea.translatesAutoresizingMaskIntoConstraints = false

        container.addArrangedSubview(thumbnailView)
        container.addArrangedSubview(commentArea)

        NSLayoutConstraint.activate([
            thumbnailView.widthAnchor.constraint(equalToConstant: 80),
            thumbnailView.heightAnchor.constraint(equalToConstant: 80),

            commentArea.heightAnchor.constraint(greaterThanOrEqualToConstant: 110),
            commentArea.widthAnchor.constraint(equalTo: container.widthAnchor),
        ])

        return container
    }

    private func makeTagsRow() -> UIView {
        let row = UIStackView(arrangedSubviews: [bugChip, ideaChip, polishChip])
        row.translatesAutoresizingMaskIntoConstraints = false
        row.axis = .horizontal
        row.spacing = GripeSpacing.s
        row.alignment = .center
        row.distribution = .fill

        bugChip.isSelectedChip = true

        let trailingSpacer = UIView()
        trailingSpacer.translatesAutoresizingMaskIntoConstraints = false
        trailingSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        row.addArrangedSubview(trailingSpacer)

        return row
    }

    private func setupSubmit() {
        view.addSubview(submitButton)
        view.addSubview(activity)

        activity.translatesAutoresizingMaskIntoConstraints = false
        activity.hidesWhenStopped = true

        NSLayoutConstraint.activate([
            submitButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: GripeSpacing.xl),
            submitButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -GripeSpacing.xl),
            submitButton.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor, constant: -GripeSpacing.l),

            activity.centerXAnchor.constraint(equalTo: submitButton.centerXAnchor),
            activity.centerYAnchor.constraint(equalTo: submitButton.centerYAnchor),
        ])

        scrollView.contentInset.bottom = 80
        scrollView.verticalScrollIndicatorInsets.bottom = 80
    }

    private func setupActions() {
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        submitButton.addTarget(self, action: #selector(submitTapped), for: .touchUpInside)
        bugChip.addTarget(self, action: #selector(chipTapped(_:)), for: .touchUpInside)
        ideaChip.addTarget(self, action: #selector(chipTapped(_:)), for: .touchUpInside)
        polishChip.addTarget(self, action: #selector(chipTapped(_:)), for: .touchUpInside)
    }

    @objc private func closeTapped() {
        let onFinished = self.onFinished
        dismiss(animated: true) { onFinished() }
    }

    @objc private func chipTapped(_ sender: GripeChip) {
        let chips = [bugChip, ideaChip, polishChip]
        let willToggleOff = sender.isSelectedChip
        if willToggleOff {
            let othersSelected = chips.contains { $0 !== sender && $0.isSelectedChip }
            guard othersSelected else { return }
        }
        sender.isSelectedChip.toggle()
    }

    private var selectedTags: [String] {
        var tags: [String] = []
        if bugChip.isSelectedChip { tags.append(bugChip.title) }
        if ideaChip.isSelectedChip { tags.append(ideaChip.title) }
        if polishChip.isSelectedChip { tags.append(polishChip.title) }
        return tags
    }

    @objc private func submitTapped() {
        view.endEditing(true)
        setBusy(true)

        let titleText = titleField.textField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let commentBody = commentArea.textView.text ?? ""
        let tags = selectedTags
        let combinedComment = "\(titleText)\n\nTags: \(tags.joined(separator: ", "))\n\n\(commentBody)"
        let metadata = MetadataCollector.collect()
        let image = croppedImage

        Task { [weak self] in
            let result = await GripeAPIClient.shared.submit(image: image, comment: combinedComment, metadata: metadata)
            await MainActor.run {
                self?.handle(result, title: titleText, tags: tags)
            }
        }
    }

    private func setBusy(_ busy: Bool) {
        submitButton.isEnabled = !busy
        submitButton.alpha = busy ? 0.5 : 1
        closeButton.isEnabled = !busy
        commentArea.textView.isEditable = !busy
        titleField.textField.isEnabled = !busy
        if busy { activity.startAnimating() } else { activity.stopAnimating() }
    }

    private func handle(_ result: Result<URL, Error>, title: String, tags: [String]) {
        switch result {
        case .success(let url):
            NotificationCenter.default.post(
                name: CommentComposerVC.issueSubmittedNotification,
                object: nil,
                userInfo: [
                    "url": url,
                    "title": title,
                    "tags": tags,
                    "image": croppedImage,
                    "metadata": MetadataCollector.collect(),
                ]
            )
            let onFinished = self.onFinished
            dismiss(animated: true) { onFinished() }
        case .failure(let error):
            setBusy(false)
            let alert = UIAlertController(
                title: "Couldn't submit",
                message: error.localizedDescription,
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        }
    }
}
