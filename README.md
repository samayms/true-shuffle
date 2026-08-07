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
- **One screen.** A dark, system-native list: pick a playlist, it shuffles.
  Recently shuffled playlists sit at the top, and a compact now-playing bar
  gives you play/pause and a one-tap reshuffle.
- **Real playback.** The queue is handed to the system Music app, so the lock
  screen, Control Center, CarPlay, AirPlay and background audio all work
  normally. This app implements none of them and doesn't need to.
- **Knows what's downloaded.** Optionally shuffles only songs stored on the
  device, so a shuffle on a plane or the subway never hits a song it can't play.
- **Built for Shortcuts.** Two actions, both of which run without opening the
  app — the intended everyday path is one tap from the home screen or the
  Action Button.
- **Home Screen widget.** Three sizes showing one, three, or six playlists.
  Every row is a button that shuffles and plays on the spot, with no app
  launch at all.
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

A correctly configured device shows:

| What you see | What it means |
|---|---|
| 🌐 beside the device name | Network connection is live — this is the whole point of the step |
| Identifier's second UUID | Must match `DEVICE_ID` in `scripts/resign.config` |
| No errors or warnings | Nothing to fix |
| **True Shuffle** under Installed Apps | The app is on the phone |
| Device Conditions: **None** | Correct — that's a network-throttling test tool, unrelated to signing |

> [!NOTE]
> The widget does **not** appear as its own row under Installed Apps, and that
> is not a failure. App extensions ship inside the host app's bundle, so
> `TrueShuffleWidgetExtension.appex` is part of the single True Shuffle entry.
> To confirm it really shipped, check the built product instead:
>
> ```bash
> ls TrueShuffle.app/PlugIns/
> ```

The same check from the command line, without opening Xcode:

```bash
xcrun devicectl list devices
```

A hostname ending in `.coredevice.local` and a state of `connected` means the
phone is reachable over the network right now.

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

> [!NOTE]
> macOS will ask whether **sleepwatcher** may *"receive keystrokes from any
> application"*. **Deny it.** SleepWatcher requests Input Monitoring only
> because it *can* watch for user inactivity — its `-t`/`-i`/`-R` idle options,
> and `-b`/`-r`/`-g`. This setup uses none of them:
>
> ```
> sleepwatcher -V -s ~/.sleep -w ~/.wakeup
> ```
>
> Sleep and wake are power-management events, so `-s` and `-w` work with the
> permission denied. Granting it would give a background daemon keylogger-level
> access for no benefit.

Verify it end to end before trusting it. The script skips if it already ran
today, so force a run:

```bash
./scripts/resign.sh --force
tail ~/.local/state/true-shuffle/resign.log
```

The widget needs no separate handling: it has its own bundle ID and its own
profile on the same 7-day clock, but `resign.sh` builds the whole scheme and the
extension is embedded in the app, so one pass refreshes both. Check what the
signing actually produced with:

```bash
security cms -D -i <path>/TrueShuffle.app/PlugIns/TrueShuffleWidgetExtension.appex/embedded.mobileprovision \
  | plutil -p - | grep ExpirationDate
```

#### Checking on it later

One block that answers "is this still working?":

```bash
tail -1 ~/.local/state/true-shuffle/resign.log     # last outcome
cat ~/.local/state/true-shuffle/last-resign        # date of last success
brew services list | grep sleepwatcher             # daemon still started?
tail -1 ~/.wakeup                                  # hook still points at the repo
xcrun devicectl list devices | grep -i iphone      # phone reachable?
```

Healthy looks like a `SUCCESS: reinstalled TrueShuffle` line dated within the
last few days, `sleepwatcher started`, and the phone listed. The date matters
more than the word: a success from nine days ago means the app has already
expired.

#### Testing the wake trigger itself

`resign.sh --force` proves the *build and install* work. It does not prove that
waking the Mac actually fires them. To test that, clear the day marker first —
otherwise the once-a-day guard makes the run exit silently and you learn
nothing:

```bash
rm ~/.local/state/true-shuffle/last-resign
pmset sleepnow
# wake the Mac, wait a minute, then:
tail ~/.local/state/true-shuffle/resign.log
```

A fresh `starting re-sign for device …` line timestamped after the wake means
the whole chain works: SleepWatcher → `~/.wakeup` → `resign.sh`.

#### Where this still breaks

"Automated" is not "unconditional". Three things will silently stop it, and you
won't find out until the app refuses to open:

- **The Mac must wake at least once every 7 days.** SleepWatcher triggers on
  wake; no wake, no re-sign. If your Mac tends to stay running for days, a
  `launchd` agent on a calendar interval is the more robust trigger.
- **The iPhone must be on the same Wi-Fi at that moment.** If it isn't, the run
  logs the miss and exits *without* recording success, so the next wake retries.
- **Wireless deploy is genuinely flaky.** `resign.sh` already retries three
  times with backoff and raises a macOS notification on real failure — that
  notification exists precisely because a silent 3am failure is the risk.

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

## The widget

Long-press the Home Screen → **Edit** → **Add Widget** → **True Shuffle**.

| Size | Shows | Notes |
|---|---|---|
| Small | Three playlists | Tight type, 22pt buttons |
| Medium | Three playlists | The same rows with room to breathe |
| Large | Six playlists | Adds how long ago each was played |

Every size is the same object — hairline-separated rows dividing the full
height evenly — so nothing scrolls and the row count never depends on how many
playlists you happen to have.

Tapping a row shuffles that playlist and starts it in the Music app. Nothing
opens — the button runs an `AudioPlaybackIntent` inside the widget extension
itself, which reads the library and hands off the queue directly.

**Choosing what appears.** Long-press the widget → **Edit Widget** gives three
playlist slots. Any slot you fill is pinned to that position; any slot you
leave empty falls back to what you shuffled or played most recently. An
unconfigured widget is therefore already useful, which is why there is no
in-app settings screen for this — the native sheet is the whole interface.

> [!NOTE]
> The widget extension is a separate process, and a free personal team can't
> use App Groups, so the extension cannot read the app's stored history. What
> the two *do* share is the music library itself — so the widget orders rows by
> each playlist's most recent play date, which both processes can see. Shuffles
> started from the widget's own buttons are recorded locally and take priority.

The extension **inherits the app's media library permission** — you grant access
once, in the app, and the widget can read playlists from its own process.
Verified on iOS 26.5.2.

> [!NOTE]
> This is worth stating because the public evidence suggests otherwise. Apple
> bug report FB11566125 — *"MPMediaLibrary.authorizationStatus() is always
> .denied in Widget Extension"*, filed against iOS 16.1 and still marked Open —
> describes this exact combination and reports it as a regression from iOS 15.
> It does not reproduce here. Treat that radar as stale rather than current.
>
> An extension still can't *request* access, though: there's no UI in which to
> present the prompt. The app remains the only place that can ask, which is why
> the widget falls back to "Open True Shuffle to allow access to your music"
> rather than trying to prompt.

## Project layout

```
TrueShuffle/
├── Model/
│   ├── Shuffle.swift          Fisher–Yates, pure and injectable-RNG for testing
│   ├── MusicLibrary.swift     MediaPlayer reads: playlists, songs, download status
│   ├── ShuffleService.swift   The single shuffle-and-play path
│   ├── NowPlayingMonitor.swift  Observes the system player for the bottom bar
│   ├── SampleData.swift       DEBUG-only fixture library for UI work
│   └── AppSettings.swift      Last playlist, recent shuffles, preferences
├── Design/
│   └── Theme.swift            Colour and metric tokens from the design doc
├── Views/
│   ├── PlaylistPickerView.swift   The entire UI: one list, one tap
│   └── PlaylistPickerModel.swift  Row/recent/now-playing derivation
└── Intents/
    ├── PlaylistEntity.swift   Playlists as a Shortcuts entity
    └── ShuffleIntents.swift   The two actions + Siri phrases

TrueShuffleWidget/
├── ShuffleWidget.swift            Widget definition + timeline provider
├── SelectPlaylistsIntent.swift    The three Edit Widget slots
├── ShuffleFromWidgetIntent.swift  What a button tap runs
├── WidgetModel.swift              The timeline entry
├── WidgetChrome.swift             Play badge and shared tokens
└── Views/
    └── ShuffleRowsView.swift      The row list, plus per-size constants

scripts/
├── resign.sh                  Daily rebuild + wireless reinstall
├── setup-automation.sh        One-time SleepWatcher and keychain setup
└── make-icon.swift            Renders the app icon at 1024×1024
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

The widget extension is a second target that references the *same* `TrueShuffle`
group, with membership exceptions for the parts that are the app's alone — its
`@main` entry point, its views, its assets, and its Shortcuts provider.
Everything else (the shuffle, the library reads, the theme) is shared source
compiled into both, rather than a copy. A new file under `TrueShuffle/Model/`
is therefore visible to the widget with no project edit; a new app-only view
needs adding to that exception list.

The simulator has no music library, so every real code path lands in an empty
state there. To work on the UI without a device, launch with `-sampleData`:

```bash
xcrun simctl launch booted com.TrueShuffle.samayshah -sampleData
```

That swaps in a fixture library and seeds the recent row and now-playing bar.
It is `#if DEBUG` only and cannot reach the Release builds that
`scripts/resign.sh` installs.

### Design

The interface and icon come from a design doc built in Claude Design. The
palette is deliberately three values — near-black ink `#15151A`, paper
`#F4F2ED`, and a single signal red `oklch(0.68 0.17 25)` (`#EF6661`) that only
ever marks the thing currently playing. Tokens live in
`TrueShuffle/Design/Theme.swift`.

The app icon is the "Trail" mark: two squares mid-swap, each leaving an echo of
where it just was, so the tile reads as travel rather than two parked shapes —
Fisher–Yates' single repeated operation, drawn. It is generated at 1024×1024
from `scripts/make-icon.swift`.

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
