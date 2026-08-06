import SwiftUI
import MediaPlayer

/// The whole app.
///
/// One list, one tap. There is intentionally no now-playing view, no transport
/// controls and no queue display: once the queue is handed to the system Music
/// app, iOS already provides all of that on the lock screen and in Control
/// Centre, and rebuilding it here would be a worse copy of something the user
/// already has.
struct PlaylistPickerView: View {
    @State private var model = PlaylistPickerModel()

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("True Shuffle")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Toggle("Downloaded only", isOn: $model.downloadedOnly)
                            .toggleStyle(.button)
                            .labelStyle(.iconOnly)
                            .accessibilityLabel("Downloaded songs only")
                    }
                }
        }
        .task { await model.start() }
        .alert(
            "Couldn’t shuffle",
            isPresented: $model.isShowingError,
            presenting: model.errorMessage
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { message in
            Text(message)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .denied:
            ContentUnavailableView {
                Label("No library access", systemImage: "music.note.list")
            } description: {
                Text("True Shuffle needs permission to read your playlists.")
            } actions: {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    Link("Open Settings", destination: url)
                }
            }

        case .empty:
            ContentUnavailableView {
                Label("No playlists", systemImage: "music.note.list")
            } description: {
                Text("Create a playlist in the Music app and it will appear here.")
            }

        case .loaded(let playlists):
            list(playlists)
        }
    }

    private func list(_ playlists: [Playlist]) -> some View {
        List(playlists) { playlist in
            Button {
                model.shuffle(playlist)
            } label: {
                row(for: playlist)
            }
            .disabled(model.isStarting)
        }
        .listStyle(.plain)
        .refreshable { await model.reload() }
    }

    private func row(for playlist: Playlist) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(playlist.name)
                    .font(.body)
                    .foregroundStyle(.primary)

                Text(subtitle(for: playlist))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            if model.startingPlaylistID == playlist.id {
                ProgressView()
            } else {
                Image(systemName: "shuffle")
                    .foregroundStyle(.tint)
            }
        }
        .contentShape(.rect)
    }

    private func subtitle(for playlist: Playlist) -> String {
        let count = model.downloadedOnly ? playlist.downloadedCount : playlist.songCount
        let noun = count == 1 ? "song" : "songs"
        let suffix = model.downloadedOnly ? " downloaded" : ""
        return "\(count) \(noun)\(suffix)"
    }
}

// MARK: - Model

@MainActor
@Observable
final class PlaylistPickerModel {
    enum State {
        case loading
        case denied
        case empty
        case loaded([Playlist])
    }

    private(set) var state: State = .loading
    private(set) var startingPlaylistID: UInt64?
    var errorMessage: String?
    var isShowingError = false

    var isStarting: Bool { startingPlaylistID != nil }

    var downloadedOnly: Bool = AppSettings.downloadedOnly {
        didSet { AppSettings.downloadedOnly = downloadedOnly }
    }

    func start() async {
        if MusicLibrary.authorizationStatus == .notDetermined {
            _ = await MusicLibrary.requestAuthorization()
        }
        await reload()
    }

    func reload() async {
        guard MusicLibrary.isAuthorized else {
            state = .denied
            return
        }

        do {
            let playlists = try MusicLibrary.playlists()
            state = playlists.isEmpty ? .empty : .loaded(playlists)
        } catch {
            state = .denied
        }
    }

    func shuffle(_ playlist: Playlist) {
        guard startingPlaylistID == nil else { return }
        startingPlaylistID = playlist.id

        do {
            try ShuffleService.shuffleAndPlay(
                playlistID: playlist.id,
                downloadedOnly: downloadedOnly
            )
        } catch {
            present(error)
        }

        startingPlaylistID = nil
    }

    private func present(_ error: Error) {
        errorMessage = error.localizedDescription
        isShowingError = true
    }
}

#Preview {
    PlaylistPickerView()
}
