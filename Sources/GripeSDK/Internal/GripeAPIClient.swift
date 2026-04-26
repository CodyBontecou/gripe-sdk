import UIKit

enum GripeError: LocalizedError {
    case notConfigured
    case encodingFailed
    case serverError(Int, String?)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "Gripe.start(apiKey:) was not called."
        case .encodingFailed: return "Could not encode the screenshot."
        case .serverError(let code, let body):
            if let body, !body.isEmpty { return "Server returned \(code): \(body)" }
            return "Server returned \(code)."
        case .invalidResponse: return "Server returned an invalid response."
        }
    }
}

final class GripeAPIClient {
    static let shared = GripeAPIClient()
    private init() {}

    func submit(image: UIImage, comment: String, metadata: GripeMetadata) async -> Result<URL, Error> {
        guard let config = Gripe.shared.configuration else {
            return .failure(GripeError.notConfigured)
        }
        guard let pngData = image.pngData() else {
            return .failure(GripeError.encodingFailed)
        }

        let metadataJSON: Data
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            metadataJSON = try encoder.encode(metadata)
        } catch {
            return .failure(error)
        }

        if config.dryRun {
            print("[Gripe] dryRun submit:")
            print("  endpoint:", config.endpoint.absoluteString)
            print("  comment:", comment)
            print("  metadata:", String(data: metadataJSON, encoding: .utf8) ?? "{}")
            print("  image bytes:", pngData.count)
            return .success(URL(string: "https://gripe.dev/dry-run/\(UUID().uuidString)")!)
        }

        var request = URLRequest(url: config.endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.appendField(boundary: boundary, name: "comment", value: comment)
        body.appendField(boundary: boundary, name: "metadata", value: String(data: metadataJSON, encoding: .utf8) ?? "{}")
        if let repository = config.repository, !repository.isEmpty {
            body.appendField(boundary: boundary, name: "repository", value: repository)
        }
        body.appendFile(boundary: boundary, name: "image", filename: "screenshot.png", contentType: "image/png", data: pngData)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        do {
            let (data, response) = try await URLSession.shared.upload(for: request, from: body)
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            guard (200..<300).contains(status) else {
                let bodyString = String(data: data, encoding: .utf8)
                return .failure(GripeError.serverError(status, bodyString))
            }
            struct Resp: Decodable { let issueUrl: String }
            do {
                let decoded = try JSONDecoder().decode(Resp.self, from: data)
                guard let url = URL(string: decoded.issueUrl) else { return .failure(GripeError.invalidResponse) }
                return .success(url)
            } catch {
                return .failure(GripeError.invalidResponse)
            }
        } catch {
            return .failure(error)
        }
    }
}

private extension Data {
    mutating func appendField(boundary: String, name: String, value: String) {
        append("--\(boundary)\r\n".data(using: .utf8)!)
        append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
        append("\(value)\r\n".data(using: .utf8)!)
    }

    mutating func appendFile(boundary: String, name: String, filename: String, contentType: String, data: Data) {
        append("--\(boundary)\r\n".data(using: .utf8)!)
        append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        append("Content-Type: \(contentType)\r\n\r\n".data(using: .utf8)!)
        append(data)
        append("\r\n".data(using: .utf8)!)
    }
}
