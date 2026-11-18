import Foundation

/// How people reach us. No server: the button opens a pre-filled email in the user's mail app.
enum Support {
    static let email = "dawnwell.app@gmail.com"
    static let privacyPolicy = URL(string: "https://baturinigor.github.io/Dawnwell/privacy")!

    /// A mailto link with the app version, iOS version and device model, so the first reply
    /// does not have to ask for them. Nothing about the user's health is added.
    static func mailURL(appVersion: String, build: String, system: String, device: String) -> URL? {
        var parts = URLComponents()
        parts.scheme = "mailto"
        parts.path = email
        parts.queryItems = [
            URLQueryItem(name: "subject", value: "Dawnwell feedback"),
            URLQueryItem(name: "body", value: "\n\n—\nDawnwell \(appVersion) (\(build)) · iOS \(system) · \(device)"),
        ]
        // Some mail apps read a bare "+" as a space, so encode it.
        parts.percentEncodedQuery = parts.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        return parts.url
    }
}
