import UIKit

final class CommentComposerVC: UIViewController {
    private let croppedImage: UIImage
    private let onFinished: () -> Void

    private let imageView = UIImageView()
    private let textView = UITextView()
    private let placeholderLabel = UILabel()
    private let activity = UIActivityIndicatorView(style: .medium)
    private lazy var submitItem = UIBarButtonItem(title: "Submit", style: .done, target: self, action: #selector(submitTapped))

    init(croppedImage: UIImage, onFinished: @escaping () -> Void) {
        self.croppedImage = croppedImage
        self.onFinished = onFinished
        super.init(nibName: nil, bundle: nil)
        title = "New Gripe"
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(cancelTapped)
        )
        navigationItem.rightBarButtonItem = submitItem

        imageView.image = croppedImage
        imageView.contentMode = .scaleAspectFit
        imageView.layer.borderColor = UIColor.separator.cgColor
        imageView.layer.borderWidth = 1
        imageView.layer.cornerRadius = 8
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(imageView)

        textView.font = .preferredFont(forTextStyle: .body)
        textView.delegate = self
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.layer.borderColor = UIColor.separator.cgColor
        textView.layer.borderWidth = 1
        textView.layer.cornerRadius = 8
        textView.textContainerInset = UIEdgeInsets(top: 10, left: 8, bottom: 10, right: 8)
        view.addSubview(textView)

        placeholderLabel.text = "Describe what's happening…"
        placeholderLabel.textColor = .placeholderText
        placeholderLabel.font = textView.font
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(placeholderLabel)

        activity.translatesAutoresizingMaskIntoConstraints = false
        activity.hidesWhenStopped = true
        view.addSubview(activity)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            imageView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            imageView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            imageView.heightAnchor.constraint(equalToConstant: 220),

            textView.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 16),
            textView.leadingAnchor.constraint(equalTo: imageView.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: imageView.trailingAnchor),
            textView.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor, constant: -16),

            placeholderLabel.topAnchor.constraint(equalTo: textView.topAnchor, constant: 16),
            placeholderLabel.leadingAnchor.constraint(equalTo: textView.leadingAnchor, constant: 13),

            activity.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activity.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.textView.becomeFirstResponder()
        }
    }

    @objc private func cancelTapped() {
        let onFinished = self.onFinished
        dismiss(animated: true) { onFinished() }
    }

    @objc private func submitTapped() {
        view.endEditing(true)
        setBusy(true)
        let comment = textView.text ?? ""
        let metadata = MetadataCollector.collect()
        let image = croppedImage
        Task { [weak self] in
            let result = await GripeAPIClient.shared.submit(image: image, comment: comment, metadata: metadata)
            await MainActor.run { self?.handle(result) }
        }
    }

    private func setBusy(_ busy: Bool) {
        submitItem.isEnabled = !busy
        navigationItem.leftBarButtonItem?.isEnabled = !busy
        textView.isEditable = !busy
        if busy { activity.startAnimating() } else { activity.stopAnimating() }
    }

    private func handle(_ result: Result<URL, Error>) {
        setBusy(false)
        let alert: UIAlertController
        switch result {
        case .success(let url):
            alert = UIAlertController(title: "Submitted", message: url.absoluteString, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Open", style: .default) { [weak self] _ in
                UIApplication.shared.open(url)
                self?.finish()
            })
            alert.addAction(UIAlertAction(title: "Done", style: .cancel) { [weak self] _ in
                self?.finish()
            })
        case .failure(let error):
            alert = UIAlertController(title: "Couldn't submit", message: error.localizedDescription, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
        }
        present(alert, animated: true)
    }

    private func finish() {
        let onFinished = self.onFinished
        dismiss(animated: true) { onFinished() }
    }
}

extension CommentComposerVC: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        placeholderLabel.isHidden = !textView.text.isEmpty
    }
}
