# Bedit

<img src="bedit-macos.svg" alt="" width="128" align="right">

Bedit is a private app to write and read your journal on macOS. You can also write to it from iPhone, iPad, or Shortcuts. Entries are encrypted as you write and decrypted only inside the app where you read, so there's never a readable copy on disk for Spotlight, backups, other software, or people using your computer to find.

iOS is write-only by design. An iPhone or iPad can write new entries but can never read them, because the private key isn't on iOS at all. If your phone is taken, your words aren't on it.

Screenshots are on the [App Store listing](https://apps.apple.com/us/app/bedit/id6755100266).

## Features

- Write and read encrypted journal entries on macOS.
- Optionally enable iCloud Drive to write new entries from iPhone or iPad; only your Mac can read them.
- Use Siri or Shortcuts to write entries.
- Browse by date and filter by tag.
- Full-text search across entries.
- Import existing documents as encrypted entries.
- No lock-in. Everything's a file named by date, decryptable with [bvf-cli](https://github.com/openbvf/bvf/tree/main/bvf-cli).
- Export selection.
- Idle auto-lock.

## Install

<a href="https://apps.apple.com/us/app/bedit/id6755100266?itsct=apps_box_badge&amp;itscg=30200"><img alt="Download on the App Store" src="https://tools.applemediaservices.com/api/badges/download-on-the-app-store/black/en-us?releaseDate=1751760000" height="50"></a>

- **macOS**: Requires macOS 15 or later. Or [build from source](BUILDING.md).
- **iOS**: Requires iOS 18 or later.

## First run

You generate keys and choose a passphrase during onboarding (or reuse existing ones from another bvf app). The passphrase is the only thing standing between someone who has your keys and your entry files. There is no recovery, no support desk, no "forgot password" link. Ideally it only exists in your head. Make it [secure](https://www.eff.org/dice).

During onboarding, you can also choose to enable iCloud Drive so entries written on your iPhone or iPad land on your Mac. You can change this later in preferences, where you can also rerun the onboarding wizard at any time.

## What this protects, and what it doesn't

Files at rest are unreadable without your passphrase. Full stop.

For the full threat model and cryptographic details, see [PRIVACY.md](PRIVACY.md) and [SECURITY.md](SECURITY.md).

**Bedit protects you from:**

- Anyone who steals your Mac, iPhone, or iPad
- Someone logged into your Mac as you; passphrase on launch, auto-lock on idle, and can be set to lock the moment focus leaves the app
- Anyone using your iPhone or iPad, which can't read your journal in the first place
- Anyone who copies your encrypted entries; they might see encrypted blobs, never the words
- AI agents, indexers, and other software that read files on your Mac; same answer
- Apple, or anyone who breaches iCloud; same answer

**Bedit does not protect you from:**

- Someone looking at your screen, or taking screenshots, while you have Bedit unlocked
- A keylogger or a tampered Bedit binary. If your Mac is compromised at runtime, all bets are off.
- A forgotten passphrase. There is no recovery, and the entries are gone.
- A memory attack on your running, unlocked Mac (see [SECURITY.md](SECURITY.md) for the nuances).
- Fake entries from someone using your device. Anyone logged into your Mac, iPhone, or iPad can add an entry.
- Yourself, via advanced settings. Moving the private key off your Mac (to iCloud, a shared folder, a backup service that holds its own decryption key) puts it within reach of whoever can read that location.

## License

MIT. See [LICENSE](LICENSE).

## Reporting issues

Bugs and feature requests: file an issue at https://github.com/openbvf/bedit/issues.

Security issues: see [SECURITY.md](SECURITY.md). Do not file public issues for security.
