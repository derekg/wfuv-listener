import AVFoundation
import Combine
import MediaPlayer
import SwiftUI

@MainActor
final class RadioStore: ObservableObject {
    @Published private(set) var isPlaying = false
    @Published private(set) var isLoading = false
    @Published private(set) var liveTrack: LiveTrack?
    @Published private(set) var isConfirmedLive = false
    @Published private(set) var liveArtwork: UIImage?
    @Published private(set) var songs: [Song] = []
    @Published private(set) var favorites: Set<String> = []
    @Published private(set) var savedSongs: [Song] = []
    @Published private(set) var errorMessage: String?
    @Published private(set) var playlistError: String?
    @Published private(set) var lastUpdated: Date?
    @Published var sleepEnd: Date?
    @Published private(set) var dataSaverEnabled = false

    var liveOnlySong: Song? {
        TimelineSelection.liveOnlySong(track: liveTrack, isConfirmedLive: isConfirmedLive, songs: songs)
    }

    var timelineSongs: [Song] {
        guard let liveOnlySong else { return songs }
        return [liveOnlySong] + songs
    }

    private var player: AVPlayer?
    private var pausedAt: Date?
    private let liveResumeWindow: TimeInterval = 30
    private var statusObserver: NSKeyValueObservation?
    private var itemStatusObserver: NSKeyValueObservation?
    private var playbackErrorObserver: NSObjectProtocol?
    private var refreshTask: Task<Void, Never>?
    private var refreshInFlight: Task<Void, Never>?
    private var sleepTask: Task<Void, Never>?
    private var playlistErrorTask: Task<Void, Never>?
    private var artworkTask: Task<Void, Never>?
    private var artworkKey: String?
    private var artworkRetryAt = Date.distantPast
    private let artworkCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 40
        cache.totalCostLimit = 24_000_000
        return cache
    }()
    private var stationTrack: LiveTrack?
    private let historyKey = "savedSongHistory.v1"
    private let favoritesKey = "favoriteSongIDs.v1"
    private let savedSongsKey = "savedSongs.v2"

    init() {
        if let data = UserDefaults.standard.data(forKey: historyKey),
           let saved = try? JSONDecoder().decode([Song].self, from: data) { songs = saved }
        if let data = UserDefaults.standard.data(forKey: savedSongsKey),
           let saved = try? JSONDecoder().decode([Song].self, from: data) {
            savedSongs = saved
        } else {
            let oldIDs = Set(UserDefaults.standard.stringArray(forKey: favoritesKey) ?? [])
            savedSongs = songs.filter { oldIDs.contains($0.id) }
            if let data = try? JSONEncoder().encode(savedSongs) {
                UserDefaults.standard.set(data, forKey: savedSongsKey)
            }
        }
        var uniqueFavorites: [String: Song] = [:]
        for song in savedSongs {
            if let existing = uniqueFavorites[song.favoriteID], existing.playedAt >= song.playedAt { continue }
            uniqueFavorites[song.favoriteID] = song
        }
        savedSongs = uniqueFavorites.values.sorted { $0.playedAt > $1.playedAt }
        favorites = Set(savedSongs.map(\.favoriteID))
        if let data = try? JSONEncoder().encode(savedSongs) {
            UserDefaults.standard.set(data, forKey: savedSongsKey)
        }
        let initialFavorites = savedSongs
        Task { await ArtworkService.shared.setPinnedSongs(initialFavorites) }
        dataSaverEnabled = UserDefaults.standard.bool(forKey: "dataSaverEnabled.v1")
        configureRemoteControls()
    }

    deinit {
        refreshTask?.cancel()
        sleepTask?.cancel()
        playlistErrorTask?.cancel()
        artworkTask?.cancel()
        if let playbackErrorObserver { NotificationCenter.default.removeObserver(playbackErrorObserver) }
    }

    func startRefreshing() {
        guard refreshTask == nil else { return }
        refreshTask = Task {
            while !Task.isCancelled {
                await refresh()
                try? await Task.sleep(for: .seconds(45))
            }
        }
    }

    func stopRefreshing() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    func refresh() async {
        if let refreshInFlight {
            await refreshInFlight.value
            return
        }
        let task = Task { await performRefresh() }
        refreshInFlight = task
        await task.value
        refreshInFlight = nil
    }

    private func performRefresh() async {
        async let fetchedSongs = WFUVService.fetchSongs()
        async let fetchedTrack = WFUVService.fetchNowPlaying()
        do {
            let incoming = try await fetchedSongs
            var merged = Dictionary(uniqueKeysWithValues: songs.map { ($0.id, $0) })
            for song in incoming { merged[song.id] = song }
            songs = merged.values.sorted { $0.playedAt > $1.playedAt }.prefix(500).map { $0 }
            if let data = try? JSONEncoder().encode(songs) { UserDefaults.standard.set(data, forKey: historyKey) }
            lastUpdated = .now
            playlistErrorTask?.cancel()
            playlistError = nil
            updateTrackSelection()
        } catch {
            playlistError = "Playlist didn’t update"
            playlistErrorTask?.cancel()
            playlistErrorTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(6))
                guard !Task.isCancelled else { return }
                self?.playlistError = nil
            }
        }
        let fetchedLiveTrack = try? await fetchedTrack
        if let fetchedLiveTrack,
           stationTrack == nil || (fetchedLiveTrack.playedAt ?? .distantPast) >= (stationTrack?.playedAt ?? .distantPast) {
            stationTrack = fetchedLiveTrack
        }
        updateTrackSelection()
    }

    private func updateTrackSelection() {
        let selected = TrackSelection.resolve(station: stationTrack, latest: songs.first, now: .now)
        isConfirmedLive = selected.1
        if let track = selected.0 {
            let nextKey = artworkIdentity(title: track.title, artist: track.artist)
            let changedSong = artworkKey != nextKey
            if changedSong {
                artworkTask?.cancel()
                artworkKey = nextKey
                liveArtwork = track.isMusic ? artworkCache.object(forKey: nextKey as NSString) : nil
            }
            if !track.isMusic { liveArtwork = nil }
            liveTrack = track
            if track.isMusic && (changedSong || Date.now >= artworkRetryAt) {
                loadArtwork(for: track)
            }
            updateNowPlayingInfo()
        } else {
            artworkTask?.cancel()
            artworkKey = nil
            liveArtwork = nil
            liveTrack = nil
            updateNowPlayingInfo()
        }
    }

    func togglePlayback() {
        if isPlaying || isLoading { pause() } else { play() }
    }

    func play() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            errorMessage = "Audio could not start. Check your device audio settings."
            return
        }
        if let pausedAt {
            let elapsed = Date.now.timeIntervalSince(pausedAt)
            if elapsed < 0 || elapsed >= liveResumeWindow {
                discardPlayer()
            }
        }
        if player?.currentItem?.status == .failed { discardPlayer() }
        pausedAt = nil
        if player == nil {
            let item = AVPlayerItem(url: dataSaverEnabled ? WFUVService.dataSaverStreamURL : WFUVService.highQualityStreamURL)
            let newPlayer = AVPlayer(playerItem: item)
            newPlayer.automaticallyWaitsToMinimizeStalling = true
            itemStatusObserver = item.observe(\.status, options: [.new]) { [weak self] item, _ in
                guard item.status == .failed else { return }
                Task { @MainActor [weak self] in
                    guard self?.player?.currentItem === item else { return }
                    self?.isLoading = false
                    self?.errorMessage = "Stream unavailable. Try reconnecting from playback options."
                }
            }
            statusObserver = newPlayer.observe(\.timeControlStatus, options: [.initial, .new]) { [weak self] player, _ in
                Task { @MainActor [weak self] in
                    guard self?.player === player else { return }
                    if player.timeControlStatus == .paused && self?.isPlaying == true && self?.pausedAt == nil {
                        self?.pausedAt = .now
                    }
                    self?.isPlaying = player.timeControlStatus == .playing
                    self?.isLoading = player.timeControlStatus == .waitingToPlayAtSpecifiedRate
                    self?.updateNowPlayingInfo()
                }
            }
            playbackErrorObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemFailedToPlayToEndTime, object: item, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard self?.player?.currentItem === item else { return }
                    self?.errorMessage = "Stream interrupted. Tap play to reconnect."
                    self?.pause()
                }
            }
            player = newPlayer
        }
        errorMessage = nil
        player?.play()
        updateNowPlayingInfo()
    }

    func pause() {
        player?.pause()
        pausedAt = .now
        isPlaying = false
        isLoading = false
        updateNowPlayingInfo()
    }

    private func discardPlayer() {
        player?.pause()
        statusObserver = nil
        itemStatusObserver = nil
        player = nil
        if let playbackErrorObserver { NotificationCenter.default.removeObserver(playbackErrorObserver) }
        playbackErrorObserver = nil
    }

    func reconnect() {
        pause()
        discardPlayer()
        play()
    }

    func setDataSaver(_ enabled: Bool) {
        guard dataSaverEnabled != enabled else { return }
        let wasPlaying = isPlaying || isLoading
        pause()
        discardPlayer()
        dataSaverEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "dataSaverEnabled.v1")
        if wasPlaying { play() }
    }

    func toggleFavorite(_ song: Song) {
        if !favorites.insert(song.favoriteID).inserted {
            favorites.remove(song.favoriteID)
            savedSongs.removeAll { $0.favoriteID == song.favoriteID }
        } else {
            savedSongs.insert(song, at: 0)
            savedSongs.sort { $0.playedAt > $1.playedAt }
        }
        if let data = try? JSONEncoder().encode(savedSongs) { UserDefaults.standard.set(data, forKey: savedSongsKey) }
        UserDefaults.standard.set(savedSongs.map(\.id), forKey: favoritesKey)
        let currentFavorites = savedSongs
        Task { await ArtworkService.shared.setPinnedSongs(currentFavorites) }
    }

    func setSleepTimer(minutes: Int?) {
        sleepTask?.cancel()
        guard let minutes else { sleepEnd = nil; return }
        sleepEnd = Date().addingTimeInterval(TimeInterval(minutes * 60))
        sleepTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(minutes * 60))
            guard !Task.isCancelled else { return }
            self?.pause()
            self?.sleepEnd = nil
        }
    }

    private func configureRemoteControls() {
        let commands = MPRemoteCommandCenter.shared()
        commands.playCommand.isEnabled = true
        commands.pauseCommand.isEnabled = true
        commands.togglePlayPauseCommand.isEnabled = true
        commands.nextTrackCommand.isEnabled = false
        commands.previousTrackCommand.isEnabled = false
        commands.changePlaybackPositionCommand.isEnabled = false
        commands.playCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.play() }
            return .success
        }
        commands.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.pause() }
            return .success
        }
        commands.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.togglePlayback() }
            return .success
        }
    }

    private func updateNowPlayingInfo() {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: liveTrack?.isMusic == true ? (liveTrack?.title ?? "WFUV") : "WFUV 90.7 FM",
            MPMediaItemPropertyArtist: liveTrack?.isMusic == true ? (liveTrack?.artist ?? "Live radio") : "New York's Music Discovery",
            MPNowPlayingInfoPropertyIsLiveStream: true,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]
        info[MPMediaItemPropertyAlbumTitle] = isConfirmedLive ? "Live on WFUV" : "Latest on WFUV"
        let artwork: UIImage
        if let liveArtwork {
            artwork = liveArtwork
        } else if let track = liveTrack, track.isMusic {
            artwork = SongArtwork.image(title: track.title, artist: track.artist)
        } else {
            artwork = StationArtwork.image
        }
        info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: artwork.size) { _ in artwork }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func loadArtwork(for track: LiveTrack) {
        artworkTask?.cancel()
        artworkRetryAt = Date().addingTimeInterval(300)
        guard track.isMusic, let requestedKey = artworkKey else { return }
        artworkTask = Task { [weak self] in
            if let cached = await ArtworkService.shared.cachedImageData(title: track.title, artist: track.artist),
               let image = UIImage(data: cached), !Task.isCancelled,
               self?.artworkKey == requestedKey {
                self?.cacheArtwork(image, key: requestedKey)
                self?.liveArtwork = image
                self?.updateNowPlayingInfo()
            }
            guard let data = await ArtworkService.shared.imageData(title: track.title, artist: track.artist,
                                                                  preferredURL: track.artworkURL, preferredAlbum: track.album),
                  let image = UIImage(data: data), !Task.isCancelled,
                  self?.artworkKey == requestedKey else { return }
            self?.cacheArtwork(image, key: requestedKey)
            self?.liveArtwork = image
            self?.updateNowPlayingInfo()
        }
    }

    func receiveArtwork(_ image: UIImage, for song: Song) {
        let key = artworkIdentity(title: song.title, artist: song.artist)
        cacheArtwork(image, key: key)
        guard let track = liveTrack, track.isMusic,
              artworkKey == key else { return }
        liveArtwork = image
        updateNowPlayingInfo()
    }

    func cachedArtwork(for song: Song) -> UIImage? {
        artworkCache.object(forKey: artworkIdentity(title: song.title, artist: song.artist) as NSString)
    }

    private func cacheArtwork(_ image: UIImage, key: String) {
        let width = image.cgImage?.width ?? Int(image.size.width)
        let height = image.cgImage?.height ?? Int(image.size.height)
        artworkCache.setObject(image, forKey: key as NSString, cost: width * height * 4)
    }

    private func artworkIdentity(title: String, artist: String) -> String {
        "\(title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())|\(artist.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())"
    }
}
