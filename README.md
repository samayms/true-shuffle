<div align="center">

# True Shuffle

**A genuinely random shuffle for Apple Music, on your own iPhone.**

</div>

Apple Music's shuffle is weighted. It leans on the same artists, revisits recent
plays, and quietly makes some orderings far more likely than others. True Shuffle
does the boring, correct thing instead: an unbiased Fisher–Yates shuffle where
every possible ordering is equally likely, handed straight to the Music app to
play.

It is a personal, sideloaded app. No App Store, no backend, no accounts, no API
keys, and no `$99/year` Apple Developer Program.

## Features

- **Uniform shuffle.** Fisher–Yates with a cryptographic RNG, covered by tests
  that check positional uniformity and full permutation coverage — not just
  "it looks random."
- **Real playback.** The queue is handed to the system Music app, so the lock
  screen, Control Center, CarPlay, AirPlay and background audio all work
  normally. This app implements none of them and doesn't need to.
- **Knows what's downloaded.** Optionally shuffles only songs stored on the
  device, so a shuffle on a plane or the subway never hits a song it can't play.
- **Built for Shortcuts.** Two actions, both of which run without opening the
  app — the intended everyday path is one tap from the home screen or the
  Action Button.
- **Stays installed.** Free provisioning expires every 7 days; an included
  script re-signs the app over Wi-Fi when you open your Mac.

## How it works

```
MPMediaQuery.playlists()  →  Fisher–Yates  →  MPMusicPlayerController.systemMusicPlayer
   your playlists            uniform order        the real Music app plays it
```

The app uses Apple's `MediaPlayer` framework, which is free, on-device, and
entirely separate from MusicKit and the Apple Music API. Two alternatives were
ruled out:

| Approach | Verdict | Why |
|---|---|---|
| Shortcuts "Find Music" filtering | Ruled out | No reliable playlist filter; fails silently for songs not already in the library |
| PWA / MusicKit JS | Ruled out | Can't see local download status; playback stalls when the tab is backgrounded |
| **Native Swift + `MediaPlayer`** | **Chosen** | Full local library and download-status access; real system playback |

> [!NOTE]
> One detail matters more than it looks. Before playing, the app forces
> `player.shuffleMode = .off`. If the Music app's own shuffle happens to be
> switched on, it re-shuffles the queue it was just handed — with the weighted
> algorithm this app exists to avoid — silently discarding the uniform ordering.

## Requirements

- macOS with **Xcode 16 or newer** (developed against Xcode 26.6)
- An iPhone running **iOS 18 or newer**
- A free Apple ID — no paid developer account needed
- [Homebrew](https://brew.sh), for the re-signing automation

## Getting started

### 1. Sign the app

```bash
git clone https://github.com/samayms/true-shuffle.git
cd true-shuffle
open TrueShuffle.xcodeproj
```

In Xcode:

1. **Settings → Accounts** → add your Apple ID (this creates a "Personal Team").
2. Select the **TrueShuffle** target → **Signing & Capabilities**.
3. Set **Team** to your Personal Team.
4. Change the **Bundle Identifier** to something unique to you, e.g.
   `com.yourname.TrueShuffle`.

### 2. Install it on your phone

Connect the iPhone by cable once, pick it as the run destination, and press
**Run** (`⌘R`). On the phone, approve the developer certificate under
**Settings → General → VPN & Device Management**.

To go wireless for every future install: **Window → Devices and Simulators**
(`⇧⌘2`) → select the iPhone → check **Connect via Network**. The cable is no
longer needed as long as both devices share a Wi-Fi network.

> [!IMPORTANT]
> On first launch the app asks for media library access. Denying it leaves the
> app with nothing to read — you can re-enable it under
> **Settings → Privacy & Security → Media & Apple Music**.

### 3. Keep it installed

Free signing certificates expire after **7 days**, after which the app stops
opening. No tool removes that limit, but it can be fully automated:

```bash
./scripts/setup-automation.sh
```

This installs [SleepWatcher](https://www.bernhard-baehr.de/), points `~/.wakeup`
at `scripts/resign.sh`, and unlocks the codesigning key for non-interactive use.
The first time you open your Mac each day, the app is rebuilt and reinstalled
over Wi-Fi.

Verify it end to end before trusting it:

```bash
./scripts/resign.sh --force
```

> [!WARNING]
> The keychain step in `setup-automation.sh` is mandatory, not optional. Without
> `security set-key-partition-list`, the first headless build blocks on a GUI
> password prompt that nobody is awake to answer, and the automation hangs
> silently until you notice the app has stopped opening.

## Using it from Shortcuts

The app registers two actions, both with `openAppWhenRun = false` — they start
music without ever bringing True Shuffle to the foreground.

| Action | Parameters | Use it for |
|---|---|---|
| **Shuffle Last Playlist** | none | The everyday one-tap case: home screen icon, Action Button, or a Back Tap |
| **Shuffle Playlist** | playlist, downloaded-only | Picking a specific playlist, or per-playlist shortcuts |

To put it on your home screen: **Shortcuts → +** → add **Shuffle Last Playlist**
→ share sheet → **Add to Home Screen**. Tapping it shuffles and plays with no
visible app launch.

Both actions also work with Siri (*"Shuffle my playlist with True Shuffle"*).

## Project layout

```
TrueShuffle/
├── Model/
│   ├── Shuffle.swift          Fisher–Yates, pure and injectable-RNG for testing
│   ├── MusicLibrary.swift     MediaPlayer reads: playlists, songs, download status
│   ├── ShuffleService.swift   The single shuffle-and-play path
│   └── AppSettings.swift      Last playlist + downloaded-only preference
├── Views/
│   └── PlaylistPickerView.swift   The entire UI: one list, one tap
└── Intents/
    ├── PlaylistEntity.swift   Playlists as a Shortcuts entity
    └── ShuffleIntents.swift   The two actions + Siri phrases

scripts/
├── resign.sh                  Daily rebuild + wireless reinstall
└── setup-automation.sh        One-time SleepWatcher and keychain setup
```

## Development

Build and test from the command line:

```bash
xcodebuild build -scheme TrueShuffle -destination 'platform=iOS Simulator,name=iPhone 17'
xcodebuild test  -scheme TrueShuffle -destination 'platform=iOS Simulator,name=iPhone 17'
```

> [!NOTE]
> The simulator has no music library, so the app correctly shows its empty
> state there. Anything involving real playlists has to be tested on a device.

The Xcode project uses file-system-synchronized groups, so new Swift files
under `TrueShuffle/` are picked up automatically without touching
`project.pbxproj`.

### Why the shuffle has its own tests

Swift's `shuffled()` is already an unbiased Fisher–Yates, so `Shuffle.swift` is
not fixing a standard-library gap. It is written out explicitly because the
app's one substantive claim — *every ordering is equally likely* — deserves an
implementation you can read and tests that measure it. The suite checks that
the result is a permutation, that all `n!` orderings are reachable, that
elements can stay in place (the classic off-by-one turns Fisher–Yates into
Sattolo's algorithm, which never leaves anything put), and that positions are
occupied uniformly across 30,000 trials.

## Troubleshooting

**The app won't open and shows "Unable to Verify App."**
The 7-day certificate expired. Run `./scripts/resign.sh --force`, or check
`~/.local/state/true-shuffle/resign.log` to see why the automation didn't.

**Re-signing fails with "could not write to device."**
Wireless deploy is flaky on some Xcode/iOS combinations. `resign.sh` already
retries three times; if it still fails, confirm both devices are on the same
Wi-Fi network and that the phone is unlocked.

**Playback starts, but the order doesn't feel random.**
Check that the Music app's own shuffle is off. True Shuffle forces it off when
it hands over the queue, but toggling it on afterwards re-shuffles what's
already playing.

**The playlist list is empty.**
Media library permission was denied, or the playlists are empty. Empty
playlists are deliberately hidden, since they can't be shuffled.
