import Foundation

final class ConfigStore {
    static let shared = ConfigStore()

    private let fileURL: URL
    private let queue = DispatchQueue(label: "com.syntexco.kineticdesk.configstore")

    private init() {
        let supportDir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LiveSpace", isDirectory: true)
        try? FileManager.default.createDirectory(at: supportDir, withIntermediateDirectories: true)
        fileURL = supportDir.appendingPathComponent("config.json")
    }

    func load() -> PlaylistConfig {
        queue.sync {
            guard let data = try? Data(contentsOf: fileURL),
                  let config = try? JSONDecoder.livespace.decode(PlaylistConfig.self, from: data)
            else {
                return .default
            }
            return config
        }
    }

    func save(_ config: PlaylistConfig) {
        queue.sync {
            guard let data = try? JSONEncoder.livespace.encode(config) else { return }
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    func mutate(_ transform: (inout PlaylistConfig) -> Void) {
        queue.sync {
            var config: PlaylistConfig
            if let data = try? Data(contentsOf: fileURL),
               let decoded = try? JSONDecoder.livespace.decode(PlaylistConfig.self, from: data) {
                config = decoded
            } else {
                config = .default
            }
            transform(&config)
            guard let data = try? JSONEncoder.livespace.encode(config) else { return }
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    func playlist(for config: PlaylistConfig) -> [URL] {
        playlist(inFolder: config.folderPath)
    }

    func playlist(inFolder folderPath: String) -> [URL] {
        let folderURL = URL(fileURLWithPath: folderPath, isDirectory: true)
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        return contents
            .filter { VideoFileKind.allowedExtensions.contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }
}

private extension JSONDecoder {
    static let livespace: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

private extension JSONEncoder {
    static let livespace: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
}
