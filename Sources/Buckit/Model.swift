import Foundation

enum ResourceKind: String, Codable {
    case file
    case link
}

struct Resource: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var kind: ResourceKind
    var name: String
    /// Absolute file path for `.file`, absolute URL string for `.link`.
    var value: String

    var url: URL? {
        switch kind {
        case .file: return URL(fileURLWithPath: value)
        case .link: return URL(string: value)
        }
    }

    var fileExists: Bool {
        kind == .file && FileManager.default.fileExists(atPath: value)
    }

    /// Subtle secondary text shown next to the name.
    var detail: String {
        switch kind {
        case .link:
            guard let url = URL(string: value), var host = url.host else { return value }
            if host.hasPrefix("www.") { host.removeFirst(4) }
            var path = url.path
            if path == "/" { path = "" }
            if path.hasSuffix("/") { path.removeLast() }
            return host + path
        case .file:
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: value, isDirectory: &isDir) else { return "Not found" }
            if isDir.boolValue { return "Folder" }
            let ext = (value as NSString).pathExtension.uppercased()
            let size = (try? FileManager.default.attributesOfItem(atPath: value)[.size] as? NSNumber)?.int64Value
            let sizeText = size.map { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) }
            return [ext.isEmpty ? nil : ext, sizeText].compactMap { $0 }.joined(separator: " · ")
        }
    }

    // MARK: Factories

    static func from(url: URL) -> Resource {
        if url.isFileURL {
            return Resource(kind: .file, name: url.lastPathComponent, value: url.path)
        }
        return Resource(kind: .link, name: displayName(for: url), value: url.absoluteString)
    }

    /// Interprets typed/pasted text as a link or a file path.
    static func from(text: String) -> Resource? {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return nil }
        let expanded = (t as NSString).expandingTildeInPath
        if expanded.hasPrefix("/"), FileManager.default.fileExists(atPath: expanded) {
            return from(url: URL(fileURLWithPath: expanded))
        }
        if let link = parseLink(t) { return from(url: link) }
        return nil
    }

    static func parseLink(_ s: String) -> URL? {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, !t.contains(" ") else { return nil }
        if let u = URL(string: t), let scheme = u.scheme?.lowercased(),
           ["http", "https", "mailto"].contains(scheme) {
            return u
        }
        if t.contains("."), !t.hasPrefix("/"), let u = URL(string: "https://" + t),
           let host = u.host, host.contains(".") {
            return u
        }
        return nil
    }

    static func displayName(for url: URL) -> String {
        if url.scheme == "mailto" { return url.absoluteString.replacingOccurrences(of: "mailto:", with: "") }
        guard var host = url.host?.lowercased() else { return url.absoluteString }
        if host.hasPrefix("www.") { host.removeFirst(4) }
        let known: [String: String] = [
            "github.com": "GitHub",
            "linkedin.com": "LinkedIn",
            "youtube.com": "YouTube",
            "figma.com": "Figma",
            "notion.so": "Notion",
            "notion.site": "Notion",
            "docs.google.com": "Google Docs",
            "drive.google.com": "Google Drive",
            "mail.google.com": "Gmail",
            "calendar.google.com": "Google Calendar",
            "x.com": "X",
            "twitter.com": "X",
            "vercel.app": "Vercel",
            "chatgpt.com": "ChatGPT",
            "claude.ai": "Claude",
        ]
        if let name = known[host] { return name }
        if host.hasSuffix("instructure.com") { return "Canvas" }
        if host.hasPrefix("brightspace.") { return "Brightspace" }
        let parts = host.split(separator: ".")
        let base = parts.count >= 2 ? String(parts[parts.count - 2]) : host
        return base.prefix(1).uppercased() + base.dropFirst()
    }
}

struct Todo: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var text: String
    var done: Bool = false
}

struct Space: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var resources: [Resource] = []
    var todos: [Todo] = []
    var note: String = ""
}

struct Snapshot: Codable {
    var spaces: [Space]
    var activeIndex: Int
}

extension Snapshot {
    static let seed = Snapshot(
        spaces: [
            Space(
                name: "Job Search",
                resources: [
                    Resource(kind: .link, name: "LinkedIn", value: "https://www.linkedin.com/in/"),
                    Resource(kind: .link, name: "GitHub", value: "https://github.com/JermSed"),
                ],
                todos: [
                    Todo(text: "Update portfolio"),
                    Todo(text: "Drop your resume in here"),
                ],
                note: ""
            ),
            Space(name: "School"),
            Space(
                name: "Development",
                resources: [
                    Resource(kind: .link, name: "Buckit repo", value: "https://github.com/JermSed/buckit"),
                ]
            ),
            Space(name: "Personal"),
        ],
        activeIndex: 0
    )
}
