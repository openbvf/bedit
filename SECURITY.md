# Security

Bedit is a thin SwiftUI shell on [BvfAppKit](https://github.com/openbvf/BvfAppKit). This file covers only what's specific to journaling-with-text.

## Reporting vulnerabilities

If you find a security issue, **do not open a public issue.** Instead:

- **GitHub Security Advisories** (preferred): [Submit a private advisory](https://github.com/openbvf/bedit/security/advisories/new)
- **Email**: bvf@newvoll.net

## Out of scope

- App-lifecycle surface: [BvfAppKit/SECURITY.md](https://github.com/openbvf/BvfAppKit/blob/main/SECURITY.md).
- Encryption, key derivation, libsodium interop: [BvfKit/SECURITY.md](https://github.com/openbvf/BvfKit/blob/main/SECURITY.md).
- The `.bvf` file format and its threat model: [bvf/SECURITY.md](https://github.com/openbvf/bvf/blob/main/SECURITY.md).

## In scope

### Clipboard via Copy menu

The Copy menu places decrypted text on the system clipboard. Anything that reads the clipboard then sees the text, including macOS Universal Clipboard and clipboard-history utilities. Treat anything you copy as having left the encrypted store until you clear the clipboard.

### Document import

Bedit can import external text files, converting them to encrypted entries. **The original source files are left in place.** Bedit does not delete, move, or sanitize them. If the source contains content you don't want sitting on disk in plaintext, delete it yourself.

### Save-entry App Intent (Shortcuts / Siri)

Bedit registers an App Intent so Shortcuts and Siri can write encrypted entries into the journal folder. **Anyone who can run a shortcut on your device can invoke this intent.** The intent only writes; it cannot read existing entries, and what it writes is encrypted to your public key like any other entry. The concrete threat is appearance of entries you didn't author, not exposure of entries you did. To disable, remove the shortcut in Shortcuts.app.

### Fake entries via iCloud

If you've enabled iCloud sync and your iCloud account is compromised, an adversary can write `.bvf` files into your journal folder. Bedit will sync them down and present them as entries. There is no per-entry signature today that lets you distinguish your own writes from injected ones; the cryptographic guarantee is confidentiality of contents, not authenticity of authorship. Mitigation: protect your iCloud account.

### Public key substitution via iCloud

If you've enabled iCloud sync, Bedit publishes your public key to a shared iCloud location so iOS captures can encrypt to it. An adversary who can write to that location could swap your key with their own; subsequent iOS captures would encrypt to the adversary's key and be readable by them. BvfAppKit's `PubkeyDistributor` watches that location and surfaces a mismatch when the remote key diverges from the local one. See [BvfAppKit/SECURITY.md](https://github.com/openbvf/BvfAppKit/blob/main/SECURITY.md) for the mechanism.
