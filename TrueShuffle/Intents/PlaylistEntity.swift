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
        try MusicLibrary.playlists().map(PlaylistEntity.init)
    }
}

extension PlaylistEntityQuery: EnumerableEntityQuery {
    @MainActor
    func allEntities() async throws -> [PlaylistEntity] {
        try MusicLibrary.playlists().map(PlaylistEntity.init)
    }
}
