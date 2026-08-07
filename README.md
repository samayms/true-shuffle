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

Budget about 20 minutes. Steps 1–3 are one-time; after that installs are a
single command over Wi-Fi.

### 1. Sign the app

```bash
git clone https://github.com/samayms/true-shuffle.git
cd true-shuffle
open TrueShuffle.xcodeproj
```

In Xcode:

1. **Settings** (`⌘,`) **→ Accounts → +** → **Apple ID** → sign in. This creates
   a free "Personal Team".
2. Click the blue **TrueShuffle** project icon in the sidebar → under TARGETS
   select **TrueShuffle** → **Signing & Capabilities**.
3. Tick **Automatically manage signing**, then set **Team** to your Personal Team.
4. Change the **Bundle Identifier** to something globally unique, e.g.
   `com.yourname.TrueShuffle`. If Xcode says the identifier is unavailable, pick
   a different one — someone else has claimed it.

> [!NOTE]
> Until an iPhone is plugged in, this screen shows **"Communication with Apple
> failed — your team has no devices"** and **"No profiles were found"**. That is
> expected, not a misconfiguration: a free Personal Team cannot mint a
> provisioning profile until at least one real device is registered to it. It
> clears in step 3.

### 2. Enable Developer Mode on the iPhone

iOS will not run a development-signed app until Developer Mode is on. This is
the step most likely to trip you up, because the app installs fine without it
and then simply refuses to launch.

1. Connect the iPhone by USB and unlock it → tap **Trust This Computer**.
2. On the iPhone: **Settings → Privacy & Security** → scroll to the bottom →
   **Developer Mode** → toggle **on**.
3. Tap **Restart**. After the reboot, unlock and confirm with **Turn On**.

Confirm the Mac sees it properly:

```bash
xcrun devicectl list devices
```

The **State** column must read `connected`. If it reads `connected (no DDI)`,
Developer Mode is still off — the developer disk image can't mount without it.

> [!TIP]
> If **Developer Mode** doesn't appear in Settings, leave the phone plugged in
> and press `⌘R` in Xcode once. The failed attempt makes the menu appear.

### 3. Install it

With the phone connected, the quickest route is the same script that later runs
unattended — this installs the app *and* proves the automation works:

```bash
./scripts/resign.sh --list        # copy your iPhone's identifier
cp scripts/resign.config.example scripts/resign.config
# paste the identifier into DEVICE_ID
./scripts/resign.sh --force
```

A successful run ends with `SUCCESS: reinstalled TrueShuffle`. (Pressing `⌘R` in
Xcode works too, with the iPhone selected as the destination under "Devices".)

Then on the iPhone, approve the certificate:
**Settings → General → VPN & Device Management** → tap your Apple ID → **Trust**.

Open the app and tap **Allow** when it asks for media library access.

> [!IMPORTANT]
> Denying media library access leaves the app with nothing to read. Re-enable it
> under **Settings → Privacy & Security → Media & Apple Music → True Shuffle**.

### 4. Go wireless

**Window → Devices and Simulators** (`⇧⌘2`) → select the iPhone → tick
**Connect via Network**. Wait for the 🌐 icon, then unplug. Every future install
happens over Wi-Fi as long as both devices are on the same network.

### 5. Keep it installed

Free signing certificates expire after **7 days**, after which the app stops
opening. No tool removes that limit, but it can be fully automated:

```bash
./scripts/setup-automation.sh
```

This installs [SleepWatcher](https://www.bernhard-baehr.de/), points `~/.wakeup`
at `scripts/resign.sh`, and unlocks the codesigning key for non-interactive use.
The first time you open your Mac each day, the app is rebuilt and reinstalled
over Wi-Fi.

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

**Xcode: "Communication with Apple failed — your team has no devices."**
Expected before any iPhone has been connected. A free Personal Team can't
generate a provisioning profile until a real device is registered to it. Plug
the phone in, then click **Try Again** on that Status row.

**`devicectl` shows `connected (no DDI)`.**
Developer Mode is off on the phone. See step 2 — the developer disk image can't
mount without it, and the app will install but refuse to launch.

**The app installs but won't launch, or shows "Untrusted Developer."**
Approve the certificate: **Settings → General → VPN & Device Management** → tap
your Apple ID → **Trust**.

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
