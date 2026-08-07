import SwiftUI

/// The whole app: pick a playlist, it shuffles and hands the queue to Music.
///
/// There is deliberately no now-playing *screen* and no transport beyond
/// play/pause — once the queue is with the system Music app, iOS already
/// provides the lock screen and Control Centre, and rebuilding those here
/// would be a worse copy of something the user already has.
struct PlaylistPickerView: View {
    @State private var model = PlaylistPickerModel()

    var body: some View {
        ZStack {
            Theme.ground.ignoresSafeArea()
            content
        }
        .preferredColorScheme(.dark)
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
            ProgressView().tint(Theme.secondaryText)

        case .denied:
            unavailable(
                title: "No library access",
                message: "True Shuffle needs permission to read your playlists."
            ) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    Link("Open Settings", destination: url)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.signal)
                }
            }

        case .empty:
            unavailable(
                title: "No playlists",
                message: "Create a playlist in the Music app and it will appear here."
            ) { EmptyView() }

        case .loaded:
            loaded
        }
    }

    private func unavailable(
        title: String,
        message: String,
        @ViewBuilder action: () -> some View
    ) -> some View {
        VStack(spacing: 10) {
            Text(title)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Theme.primaryText)
            Text(message)
                .font(.system(size: 15))
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)
            action().padding(.top, 6)
        }
        .padding(.horizontal, 40)
    }

    // MARK: - Loaded state

    private var loaded: some View {
        VStack(spacing: 0) {
            header
            downloadedToggle
            list
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if model.nowPlaying.isActive {
                NowPlayingBar(model: model)
                    .padding(.horizontal, Theme.horizontalPadding)
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.snappy(duration: 0.28), value: model.nowPlaying.isActive)
    }

    private var header: some View {
        Text("True Shuffle")
            .font(.system(size: 34, weight: .bold))
            .tracking(-0.95)
            .foregroundStyle(Theme.primaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 14)
    }

    private var downloadedToggle: some View {
        HStack(spacing: 14) {
            Text("Downloaded only")
                .font(.system(size: 16))
                .tracking(-0.16)
                .foregroundStyle(Theme.primaryText)

            Spacer(minLength: 0)

            Toggle("Downloaded only", isOn: $model.downloadedOnly)
                .labelsHidden()
                .tint(Theme.signal)
        }
        .padding(.horizontal, Theme.horizontalPadding)
        .frame(minHeight: Theme.toggleRowMinHeight)
        .background(Theme.surface, in: .rect(cornerRadius: Theme.cardRadius))
        .padding(.horizontal, Theme.horizontalPadding)
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if !model.recent.isEmpty {
                    Text("Recently shuffled").sectionHeader()

                    HStack(spacing: 10) {
                        ForEach(model.recent) { entry in
                            RecentCard(entry: entry) { model.shuffle(entry.playlist) }
                        }
                    }
                    .padding(.horizontal, Theme.horizontalPadding)
                }

                // Not "All playlists" any more: the group now leads with the
                // whole library, which isn't one.
                Text("Your music").sectionHeader()

                if model.visible.isEmpty {
                    Text("Nothing downloaded yet. Turn the filter off to shuffle from your whole library.")
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.secondaryText)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 38)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(model.visible.enumerated()), id: \.element.id) { index, row in
                            PlaylistRow(row: row, showsSeparator: index > 0) {
                                model.shuffle(row.playlist)
                            }
                        }
                    }
                    .background(Theme.surface, in: .rect(cornerRadius: Theme.cardRadius))
                    .padding(.horizontal, Theme.horizontalPadding)
                }
            }
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .refreshable { await model.reload() }
    }
}

// MARK: - Rows

private struct PlaylistRow: View {
    let row: PlaylistRowModel
    let showsSeparator: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(row.playlist.name)
                        .font(.system(size: 17))
                        .tracking(-0.2)
                        .foregroundStyle(Theme.primaryText)
                        .lineLimit(1)

                    Text(row.meta)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.secondaryText)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                if let status = row.status {
                    Text(status)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.signal)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.tertiaryText)
                }
            }
            .padding(.horizontal, Theme.horizontalPadding)
            .frame(minHeight: Theme.rowMinHeight)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .overlay(alignment: .top) {
            if showsSeparator {
                Theme.separator
                    .frame(height: 0.5)
                    .padding(.leading, Theme.horizontalPadding)
            }
        }
    }
}

private struct RecentCard: View {
    let entry: RecentEntry
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.playlist.name)
                    .font(.system(size: 15, weight: .semibold))
                    .tracking(-0.15)
                    .foregroundStyle(Theme.primaryText)
                    .lineLimit(1)

                Text(entry.when)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.secondaryText)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 13)
            .padding(.vertical, 14)
            .background(Theme.surface, in: .rect(cornerRadius: Theme.recentCardRadius))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Now playing

private struct NowPlayingBar: View {
    @Bindable var model: PlaylistPickerModel

    var body: some View {
        HStack(spacing: 14) {
            Button {
                model.togglePlayPause()
            } label: {
                Image(systemName: model.nowPlaying.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Theme.primaryText)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.1), in: .circle)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(model.nowPlaying.isPlaying ? "Pause" : "Play")

            VStack(alignment: .leading, spacing: 2) {
                Text(model.nowPlayingName)
                    .font(.system(size: 15, weight: .semibold))
                    .tracking(-0.15)
                    .foregroundStyle(Theme.primaryText)
                    .lineLimit(1)

                Text(model.nowPlayingMeta)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.nowPlayingMeta)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                model.reshuffle()
            } label: {
                Text("Again")
                    .font(.system(size: 14, weight: .semibold))
                    .tracking(-0.14)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Theme.signal, in: .rect(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .accessibilityHint("Reshuffles the same playlist")
        }
        .padding(.horizontal, Theme.horizontalPadding)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(Color.white.opacity(0.09), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.6), radius: 20, y: 12)
    }
}

#Preview {
    PlaylistPickerView()
}
