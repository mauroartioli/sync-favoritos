import Foundation
import CryptoKit
import Darwin

struct SimpleBookmarkNode: Codable {
    var type: String // "folder" | "url"
    var name: String
    var url: String?
    var children: [SimpleBookmarkNode]?
}

struct SimpleBookmarksPayload: Codable {
    var bookmark_bar: [SimpleBookmarkNode]
    var other: [SimpleBookmarkNode]
}

struct AppConfig: Codable {
    var safari_bookmarks_path: String
    var port: Int
    var token: String

    static func `default`() -> AppConfig {
        AppConfig(
            safari_bookmarks_path: "~/Library/Safari/Bookmarks.plist",
            port: 5004,
            token: UUID().uuidString
        )
    }
}

enum ConfigPaths {
    static func appSupportDir() -> URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home
            .appendingPathComponent("Library")
            .appendingPathComponent("Application Support")
            .appendingPathComponent("SyncFavoritos", isDirectory: true)
    }

    static func configURL() -> URL { appSupportDir().appendingPathComponent("config.json") }
    static func cacheURL() -> URL { appSupportDir().appendingPathComponent("safari_bookmarks.json") }
    static func logURL() -> URL { appSupportDir().appendingPathComponent("syncfavoritosd.log") }
}

final class Logger {
    private let handle: FileHandle?
    private let formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    init() {
        try? FileManager.default.createDirectory(at: ConfigPaths.appSupportDir(), withIntermediateDirectories: true)
        let url = ConfigPaths.logURL()
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil)
        }
        handle = try? FileHandle(forWritingTo: url)
        _ = try? handle?.seekToEnd()
    }

    func info(_ message: String) {
        write("INFO", message)
    }

    func warn(_ message: String) {
        write("WARN", message)
    }

    func error(_ message: String) {
        write("ERROR", message)
    }

    private func write(_ level: String, _ message: String) {
        let line = "[\(formatter.string(from: Date()))] [\(level)] \(message)\n"
        if let data = line.data(using: .utf8) {
            try? handle?.write(contentsOf: data)
        }
    }
}

final class SafariBookmarksParser {
    func parse(plistURL: URL) throws -> SimpleBookmarksPayload {
        let data = try Data(contentsOf: plistURL)
        let plistAny = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        guard let plist = plistAny as? [String: Any] else {
            throw NSError(domain: "SyncFavoritos", code: 1, userInfo: [NSLocalizedDescriptionKey: "Formato do plist inválido."])
        }

        let children = (plist["Children"] as? [[String: Any]]) ?? []
        var bar: [SimpleBookmarkNode] = []
        var other: [SimpleBookmarkNode] = []

        for child in children {
            let title = child["Title"] as? String
            let items = (child["Children"] as? [[String: Any]]) ?? []
            if title == "BookmarksBar" {
                for item in items {
                    if let node = parseNode(item) { bar.append(node) }
                }
            } else if title == "BookmarksMenu" {
                for item in items {
                    if let node = parseNode(item) { other.append(node) }
                }
            }
        }

        return SimpleBookmarksPayload(bookmark_bar: bar, other: other)
    }

    private func parseNode(_ node: [String: Any]) -> SimpleBookmarkNode? {
        let nodeType = node["WebBookmarkType"] as? String

        if nodeType == "WebBookmarkTypeList" {
            guard let folderName = node["Title"] as? String, !folderName.isEmpty else { return nil }
            let childrenAny = (node["Children"] as? [[String: Any]]) ?? []
            let parsedChildren = childrenAny.compactMap(parseNode)
            return SimpleBookmarkNode(type: "folder", name: folderName, url: nil, children: parsedChildren)
        }

        if nodeType == "WebBookmarkTypeLeaf" {
            guard let url = node["URLString"] as? String, !url.isEmpty else { return nil }
            let uriDict = node["URIDictionary"] as? [String: Any]
            let titleFromDict = uriDict?["title"] as? String
            let title = (titleFromDict?.isEmpty == false ? titleFromDict : (node["Title"] as? String)) ?? url
            return SimpleBookmarkNode(type: "url", name: title, url: url, children: nil)
        }

        return nil
    }
}

final class BookmarksState {
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return e
    }()

    private let parser = SafariBookmarksParser()
    private let logger: Logger

    private(set) var lastJSON: Data = "{}".data(using: .utf8) ?? Data()
    private(set) var lastHash: String = ""

    init(logger: Logger) {
        self.logger = logger
    }

    func refresh(plistURL: URL) {
        do {
            let payload = try parser.parse(plistURL: plistURL)
            let json = try encoder.encode(payload)
            let hash = sha256Hex(json)

            if hash != lastHash {
                lastHash = hash
                lastJSON = json
                try? FileManager.default.createDirectory(at: ConfigPaths.appSupportDir(), withIntermediateDirectories: true)
                try? json.write(to: ConfigPaths.cacheURL(), options: .atomic)
                logger.info("Favoritos atualizados (hash=\(hash.prefix(12))).")
            }
        } catch {
            logger.error("Falha ao parsear Bookmarks.plist: \(error.localizedDescription)")
        }
    }

    private func sha256Hex(_ data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

// Minimal HTTP server (Foundation + BSD sockets)
final class HTTPGatewayServer {
    private let config: AppConfig
    private let state: BookmarksState
    private let logger: Logger
    private var serverSocket: Int32 = -1

    init(config: AppConfig, state: BookmarksState, logger: Logger) {
        self.config = config
        self.state = state
        self.logger = logger
    }

    func start() throws {
        serverSocket = socket(AF_INET, SOCK_STREAM, 0)
        guard serverSocket >= 0 else { throw NSError(domain: "SyncFavoritos", code: 2) }

        var value: Int32 = 1
        setsockopt(serverSocket, SOL_SOCKET, SO_REUSEADDR, &value, socklen_t(MemoryLayout.size(ofValue: value)))

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = in_port_t(UInt16(config.port).bigEndian)
        addr.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))

        let bindResult = withUnsafePointer(to: &addr) { ptr -> Int32 in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(serverSocket, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) }
        }
        guard bindResult == 0 else {
            throw NSError(domain: "SyncFavoritos", code: 3, userInfo: [NSLocalizedDescriptionKey: "Porta \(config.port) indisponível."])
        }

        guard listen(serverSocket, 16) == 0 else { throw NSError(domain: "SyncFavoritos", code: 4) }
        logger.info("Gateway iniciado em http://127.0.0.1:\(config.port)")

        while true {
            var clientAddr = sockaddr()
            var len: socklen_t = socklen_t(MemoryLayout<sockaddr>.size)
            let client = accept(serverSocket, &clientAddr, &len)
            if client < 0 { continue }
            handleClient(client)
            close(client)
        }
    }

    private func handleClient(_ fd: Int32) {
        var buffer = [UInt8](repeating: 0, count: 8192)
        let readCount = read(fd, &buffer, buffer.count)
        guard readCount > 0 else { return }

        let request = String(decoding: buffer.prefix(readCount), as: UTF8.self)
        let lines = request.split(separator: "\r\n", omittingEmptySubsequences: false)
        guard let first = lines.first else { return }

        let parts = first.split(separator: " ")
        let method = parts.count > 0 ? String(parts[0]) : ""
        let path = parts.count > 1 ? String(parts[1]) : ""

        if method == "OPTIONS" {
            writeResponse(fd, status: "204 No Content", headers: corsHeaders(), body: Data())
            return
        }

        if config.token.isEmpty == false {
            let tokenHeader = lines.first(where: { $0.lowercased().hasPrefix("x-sf-token:") })
            let provided = tokenHeader?.split(separator: ":", maxSplits: 1).last?.trimmingCharacters(in: .whitespaces) ?? ""
            if provided != config.token {
                writeJSON(fd, status: "401 Unauthorized", object: ["error": "unauthorized"])
                return
            }
        }

        if method == "GET" && (path == "/" || path == "/safari_bookmarks.json") {
            var headers = corsHeaders()
            headers["Content-Type"] = "application/json; charset=utf-8"
            writeResponse(fd, status: "200 OK", headers: headers, body: state.lastJSON)
            return
        }

        if method == "GET" && path == "/health" {
            writeJSON(fd, status: "200 OK", object: ["ok": true, "hash": state.lastHash])
            return
        }

        writeJSON(fd, status: "404 Not Found", object: ["error": "not_found"])
    }

    private func corsHeaders() -> [String: String] {
        [
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Methods": "GET, OPTIONS",
            "Access-Control-Allow-Headers": "Content-Type, X-SF-Token"
        ]
    }

    private func writeJSON(_ fd: Int32, status: String, object: [String: Any]) {
        let data = (try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted])) ?? Data()
        var headers = corsHeaders()
        headers["Content-Type"] = "application/json; charset=utf-8"
        writeResponse(fd, status: status, headers: headers, body: data)
    }

    private func writeResponse(_ fd: Int32, status: String, headers: [String: String], body: Data) {
        var headerLines = "HTTP/1.1 \(status)\r\n"
        for (k, v) in headers {
            headerLines += "\(k): \(v)\r\n"
        }
        headerLines += "Content-Length: \(body.count)\r\n"
        headerLines += "Connection: close\r\n\r\n"

        if let headerData = headerLines.data(using: .utf8) {
            _ = headerData.withUnsafeBytes { write(fd, $0.baseAddress, headerData.count) }
        }
        _ = body.withUnsafeBytes { write(fd, $0.baseAddress, body.count) }
    }
}

func loadOrCreateConfig(logger: Logger) -> AppConfig {
    let url = ConfigPaths.configURL()
    try? FileManager.default.createDirectory(at: ConfigPaths.appSupportDir(), withIntermediateDirectories: true)

    if let data = try? Data(contentsOf: url),
       let cfg = try? JSONDecoder().decode(AppConfig.self, from: data) {
        return cfg
    }

    let cfg = AppConfig.default()
    if let data = try? JSONEncoder().encode(cfg) {
        try? data.write(to: url, options: .atomic)
        logger.info("Config criada em \(url.path)")
    }
    return cfg
}

let logger = Logger()
let config = loadOrCreateConfig(logger: logger)

let plistPath = NSString(string: config.safari_bookmarks_path).expandingTildeInPath
let plistURL = URL(fileURLWithPath: plistPath)

let state = BookmarksState(logger: logger)
state.refresh(plistURL: plistURL)

// Poll refresh (simple + robust). Use a Dispatch timer (no RunLoop needed).
let refreshInterval: TimeInterval = 5
let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .utility))
timer.schedule(deadline: .now() + refreshInterval, repeating: refreshInterval)
timer.setEventHandler {
    state.refresh(plistURL: plistURL)
}
timer.resume()

do {
    let server = HTTPGatewayServer(config: config, state: state, logger: logger)
    try server.start()
} catch {
    logger.error("Falha ao iniciar gateway: \(error.localizedDescription)")
    exit(1)
}
