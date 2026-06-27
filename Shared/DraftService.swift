import Foundation
import BvfAppKit

final class DraftService {
    private let cryptoService: CryptoService
    private let stagingDirectoryURL: URL
    private static let deviceIDKey = "DraftServiceDeviceID"

    private let deviceID: String

    init(cryptoService: CryptoService = CryptoService(), stagingDirectoryURL: URL = StagingManager.directoryURL) {
        self.cryptoService = cryptoService
        self.stagingDirectoryURL = stagingDirectoryURL
        self.deviceID = Self.getOrCreateDeviceID()
    }

    var draftFilename: String {
        ".draft-\(deviceID).txt.bvf"
    }

    /// Saves encrypted draft to staging directory
    func saveDraft(text: String, publicKeyURL: URL) -> Result<Void, Error> {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return clearDraft()
        }

        let draftURL = stagingDirectoryURL.appendingPathComponent(draftFilename)

        do {
            try FileManager.default.createDirectory(at: stagingDirectoryURL, withIntermediateDirectories: true)
        } catch {
            return .failure(error)
        }

        do {
            guard let textData = text.data(using: .utf8) else {
                return .failure(DraftServiceError.encodingFailed)
            }

            try cryptoService.encryptDataToFile(plaintext: textData, publicKeyURL: publicKeyURL, outputPath: draftURL)

            return .success(())
        } catch {
            return .failure(error)
        }
    }

    /// Promotes any existing draft on launch by moving it to a timestamped path
    func promoteDraftOnLaunch(folderURL: URL, publicKeyURL: URL? = nil) -> String? {
        let draftURL = stagingDirectoryURL.appendingPathComponent(draftFilename)

        guard FileManager.default.fileExists(atPath: draftURL.path) else {
            return nil
        }

        if isDraftStale(publicKeyURL: publicKeyURL) {
            _ = clearDraft()
            return "Encryption key was updated. Previous unsaved draft was discarded."
        }

        let modificationDate: Date
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: draftURL.path)
            modificationDate = attributes[.modificationDate] as? Date ?? Date()
        } catch {
            modificationDate = Date()
        }

        do {
            _ = try BvfStore.commit(staged: draftURL, date: modificationDate, suffix: "txt", in: folderURL)

            let timeAgo = formatRelativeTime(from: modificationDate)
            return "Previous draft from \(timeAgo) was saved"
        } catch {
            return nil
        }
    }

    /// Removes the draft file
    @discardableResult
    func clearDraft() -> Result<Void, Error> {
        let draftURL = stagingDirectoryURL.appendingPathComponent(draftFilename)

        guard FileManager.default.fileExists(atPath: draftURL.path) else {
            return .success(())
        }

        do {
            try FileManager.default.removeItem(at: draftURL)
            return .success(())
        } catch {
            return .failure(error)
        }
    }

    private func isDraftStale(publicKeyURL: URL?) -> Bool {
        let draftURL = stagingDirectoryURL.appendingPathComponent(draftFilename)

        guard let publicKeyURL = publicKeyURL,
              FileManager.default.fileExists(atPath: draftURL.path),
              FileManager.default.fileExists(atPath: publicKeyURL.path) else {
            return false
        }

        do {
            let draftAttrs = try FileManager.default.attributesOfItem(atPath: draftURL.path)
            let keyAttrs = try FileManager.default.attributesOfItem(atPath: publicKeyURL.path)

            guard let draftModTime = draftAttrs[.modificationDate] as? Date,
                  let keyModTime = keyAttrs[.modificationDate] as? Date else {
                return false
            }

            return keyModTime > draftModTime
        } catch {
            return false
        }
    }

    private static func getOrCreateDeviceID() -> String {
        if let existingID = UserDefaults.standard.string(forKey: deviceIDKey) {
            return existingID
        }

        let chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        let newID = String((0..<8).map { _ in chars.randomElement()! })

        UserDefaults.standard.set(newID, forKey: deviceIDKey)
        return newID
    }

    private func formatRelativeTime(from date: Date) -> String {
        let now = Date()
        let interval = now.timeIntervalSince(date)

        if interval < 60 {
            return "moments ago"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes) minute\(minutes == 1 ? "" : "s") ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours) hour\(hours == 1 ? "" : "s") ago"
        } else {
            let days = Int(interval / 86400)
            return "\(days) day\(days == 1 ? "" : "s") ago"
        }
    }
}

enum DraftServiceError: LocalizedError {
    case encodingFailed
    case invalidPublicKey

    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "Failed to encode draft text as UTF-8"
        case .invalidPublicKey:
            return "Invalid public key format"
        }
    }
}
