import AppIntents

/// A playlist as Shortcuts sees it.
///
/// Exposing playlists as a real `AppEntity` (rather than asking the user to
/// type a name into a text parameter) means the Shortcuts editor shows a
/// picker of actual playlists, and a renamed playlist keeps working because
/// the shortcut stores the persistent ID rather than the name.
struct PlaylistEntity: AppEntity {
    let id: String
    let name: String
    let songCount: Int

    init(_ playlist: Playlist) {
        self.id = String(playlist.id)
        self.name = playlist.name
        self.songCount = playlist.songCount
    }

    /// The numeric persistent ID, recovered from the string entity ID.
    var persistentID: UInt64? { UInt64(id) }

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Playlist")
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(name)",
            subtitle: "\(songCount) songs"
        )
    }

    static var defaultQuery = PlaylistEntityQuery()
}

struct PlaylistEntityQuery: EntityQuery {
    @MainActor
    func entities(for identifiers: [String]) async throws -> [PlaylistEntity] {
        let wanted = Set(identifiers)
        return try MusicLibrary.playlists()
            .filter { wanted.contains(String($0.id)) }
            .map(PlaylistEntity.init)
    }

    @MainActor
    func suggestedEntities() async throws -> [PlaylistEntity] {
        available()
    }
}

extension PlaylistEntityQuery: EnumerableEntityQuery {
    @MainActor
    func allEntities() async throws -> [PlaylistEntity] {
        available()
    }
}

private extension PlaylistEntityQuery {
    /// Deliberately swallows a failed library read.
    ///
    /// Both hosts of this picker — the Shortcuts editor and the widget's "Edit
    /// Widget" sheet — render a thrown error as a jarring failure alert over
    /// what is otherwise a list of choices. An empty list says the same thing
    /// more calmly, and the app's own screen already explains how to grant
    /// access. This matters most in the widget extension, which cannot present
    /// the authorization prompt itself.
    @MainActor
    func available() -> [PlaylistEntity] {
        guard let playlists = try? MusicLibrary.playlists() else { return [] }
        return playlists.map(PlaylistEntity.init)
    }
}
