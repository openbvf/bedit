import Testing
import Foundation
import BvfKit
import BvfAppKit
@testable import Bedit

@MainActor
@Suite(.serialized)
struct DraftServiceTests {

    private static let deviceIDKey = "DraftServiceDeviceID"

    private func makeTempDirectory() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func writePublicKey(in directory: URL, filename: String = "test_public.pub") throws -> URL {
        let keypair = try Keypair.generate()
        let keyURL = directory.appendingPathComponent(filename)
        try keypair.publicKey.write(to: keyURL, atomically: true, encoding: .utf8)
        return keyURL
    }

    private func withCleanUserDefaults<T>(_ body: () throws -> T) rethrows -> T {
        let previous = UserDefaults.standard.string(forKey: Self.deviceIDKey)
        UserDefaults.standard.removeObject(forKey: Self.deviceIDKey)
        defer {
            if let previous {
                UserDefaults.standard.set(previous, forKey: Self.deviceIDKey)
            } else {
                UserDefaults.standard.removeObject(forKey: Self.deviceIDKey)
            }
        }
        return try body()
    }

    @Test func emptyOrWhitespaceTextClearsExistingDraft() throws {
        try withCleanUserDefaults {
            let staging = makeTempDirectory()
            let folder = makeTempDirectory()
            defer {
                try? FileManager.default.removeItem(at: staging)
                try? FileManager.default.removeItem(at: folder)
            }

            let publicKeyURL = try writePublicKey(in: folder)
            let service = DraftService(stagingDirectoryURL: staging)
            let draftURL = staging.appendingPathComponent(service.draftFilename)

            _ = service.saveDraft(text: "real content", publicKeyURL: publicKeyURL)
            #expect(FileManager.default.fileExists(atPath: draftURL.path))

            let emptyResult = service.saveDraft(text: "", publicKeyURL: publicKeyURL)
            #expect(emptyResult.isSuccess)
            #expect(!FileManager.default.fileExists(atPath: draftURL.path))

            _ = service.saveDraft(text: "real content", publicKeyURL: publicKeyURL)
            #expect(FileManager.default.fileExists(atPath: draftURL.path))

            let whitespaceResult = service.saveDraft(text: "   \n\t  ", publicKeyURL: publicKeyURL)
            #expect(whitespaceResult.isSuccess)
            #expect(!FileManager.default.fileExists(atPath: draftURL.path))
        }
    }

    @Test func promoteDraftOnLaunchMovesDraftAndReturnsMessage() throws {
        try withCleanUserDefaults {
            let staging = makeTempDirectory()
            let folder = makeTempDirectory()
            defer {
                try? FileManager.default.removeItem(at: staging)
                try? FileManager.default.removeItem(at: folder)
            }

            let publicKeyURL = try writePublicKey(in: folder)
            let service = DraftService(stagingDirectoryURL: staging)
            let draftURL = staging.appendingPathComponent(service.draftFilename)

            #expect(service.promoteDraftOnLaunch(folderURL: folder) == nil)

            _ = service.saveDraft(text: "draft to promote", publicKeyURL: publicKeyURL)
            #expect(FileManager.default.fileExists(atPath: draftURL.path))

            let message = service.promoteDraftOnLaunch(folderURL: folder)
            #expect(message?.contains("Previous draft") ?? false)
            #expect(!FileManager.default.fileExists(atPath: draftURL.path))
        }
    }

    @Test func promoteDiscardsDraftWhenKeyIsNewerThanDraft() throws {
        try withCleanUserDefaults {
            let staging = makeTempDirectory()
            let folder = makeTempDirectory()
            defer {
                try? FileManager.default.removeItem(at: staging)
                try? FileManager.default.removeItem(at: folder)
            }

            let publicKeyURL = try writePublicKey(in: folder)
            let service = DraftService(stagingDirectoryURL: staging)
            let draftURL = staging.appendingPathComponent(service.draftFilename)

            _ = service.saveDraft(text: "draft that should be discarded", publicKeyURL: publicKeyURL)
            #expect(FileManager.default.fileExists(atPath: draftURL.path))

            let future = Date().addingTimeInterval(60)
            try FileManager.default.setAttributes([.modificationDate: future], ofItemAtPath: publicKeyURL.path)

            let message = service.promoteDraftOnLaunch(folderURL: folder, publicKeyURL: publicKeyURL)

            #expect(message == "Encryption key was updated. Previous unsaved draft was discarded.")
            #expect(!FileManager.default.fileExists(atPath: draftURL.path))

            let folderContents = try FileManager.default.contentsOfDirectory(atPath: folder.path)
            #expect(folderContents == [publicKeyURL.lastPathComponent],
                    "No yyyy/MM/dd structure should be created when draft is discarded")
        }
    }

    @Test func deviceIDFilenameIsStableAndPerDeviceUnique() {
        withCleanUserDefaults {
            UserDefaults.standard.set("DEVICE01", forKey: Self.deviceIDKey)
            let firstA = DraftService().draftFilename
            let firstB = DraftService().draftFilename
            #expect(firstA == firstB, "Same persisted device ID should produce the same filename")
            #expect(firstA == ".draft-DEVICE01.txt.bvf")

            UserDefaults.standard.removeObject(forKey: Self.deviceIDKey)
            let second = DraftService().draftFilename
            #expect(second != firstA, "A fresh device ID should produce a different filename")
            #expect(second.hasPrefix(".draft-"))
            #expect(second.hasSuffix(".txt.bvf"))
        }
    }
}

extension Result {
    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }
}
