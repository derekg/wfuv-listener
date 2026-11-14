import AVKit
import SwiftUI
import UIKit

private enum Palette {
    static let ink = Color(red: 0.08, green: 0.08, blue: 0.09)
    static let cream = Color(red: 0.975, green: 0.972, blue: 0.962)
    static let red = Color(red: 0.81, green: 0.12, blue: 0.22)
    static let pale = Color(red: 0.94, green: 0.93, blue: 0.92)
    static let muted = Color(red: 0.43, green: 0.42, blue: 0.42)
}

private enum TypeStyle {
    static func headline(_ size: CGFloat) -> Font { .custom("Bitter-Bold", size: size, relativeTo: .title) }
    static func body(_ size: CGFloat) -> Font { .custom("Heebo-Regular", size: size, relativeTo: .body) }
    static func bold(_ size: CGFloat) -> Font { .custom("Heebo-Bold", size: size, relativeTo: .body) }
}

struct ContentView: View {
    @EnvironmentObject private var radio: RadioStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var selection = 0

    var body: some View {
        TabView(selection: $selection) {
            ListenView()
                .tabItem { Label("Listen", systemImage: "dot.radiowaves.left.and.right") }
                .tag(0)
            SavedView()
                .tabItem { Label("Favorites", systemImage: "heart") }
                .tag(1)
            DiscoverView()
                .tabItem { Label("Discover", systemImage: "square.grid.2x2") }
                .tag(2)
        }
        .tint(Palette.red)
        .preferredColorScheme(.light)
        .onAppear { radio.startRefreshing() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { radio.startRefreshing() }
            else { radio.stopRefreshing() }
        }
    }
}

private struct ListenScrollKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

private struct ListenScrollObserver: ViewModifier {
    @Binding var offset: CGFloat

    @ViewBuilder func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y
            } action: { _, newOffset in
                offset = newOffset
            }
        } else {
            content.onPreferenceChange(ListenScrollKey.self) { offset = -$0 }
        }
    }
}

private struct PlaybackButton: View {
    @EnvironmentObject private var radio: RadioStore
    let diameter: CGFloat

    var body: some View {
        Button { radio.togglePlayback() } label: {
            Group {
                if radio.isLoading { ProgressView().tint(.white) }
                else { Image(systemName: radio.isPlaying ? "pause.fill" : "play.fill") }
            }
            .font(.system(size: diameter * 0.34, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: diameter, height: diameter)
            .background(Palette.red, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(radio.isPlaying ? "Pause live radio" : "Play live radio")
    }
}

private struct ListenView: View {
    @EnvironmentObject private var radio: RadioStore
    @State private var scrollPosition: CGFloat = 0

    private var title: String { radio.liveTrack?.isMusic == true ? (radio.liveTrack?.title ?? "WFUV") : "WFUV 90.7" }
    private var artist: String { radio.liveTrack?.isMusic == true ? (radio.liveTrack?.artist ?? "") : "New York’s Music Discovery" }
    private var currentArtwork: UIImage {
        if let liveArtwork = radio.liveArtwork { return liveArtwork }
        if radio.liveTrack?.isMusic == true { return SongArtwork.image(title: title, artist: artist) }
        return StationArtwork.image
    }
    private var days: [Date] { Array(Set(radio.timelineSongs.map { Calendar.current.startOfDay(for: $0.playedAt) })).sorted(by: >) }

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    header.padding(.bottom, 20)
                    hero.padding(.horizontal, -14).padding(.bottom, 16)
                    secondaryControls.padding(.bottom, 30)
                    if let message = radio.errorMessage {
                        Text(message).font(TypeStyle.body(14)).foregroundStyle(Palette.red)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Palette.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                            .padding(.bottom, 14)
                    }
                    if let message = radio.playlistError {
                        HStack(spacing: 9) {
                            Image(systemName: "arrow.clockwise.circle.fill")
                            Text(message).font(TypeStyle.bold(13))
                            Spacer(minLength: 4)
                            Button("Retry") { Task { await radio.refresh() } }
                                .font(TypeStyle.bold(13))
                        }
                        .foregroundStyle(Palette.red)
                        .padding(12)
                        .background(Palette.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                        .padding(.bottom, 14)
                    }
                    HStack(alignment: .firstTextBaseline) {
                        Text("Played on WFUV").font(TypeStyle.headline(26)).foregroundStyle(Palette.ink)
                        Spacer(minLength: 8)
                        Button { Task { await radio.refresh() } } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 15, weight: .semibold))
                                .frame(width: 44, height: 44)
                        }
                        .accessibilityLabel("Refresh playlist")
                    }
                    if let checked = radio.lastUpdated {
                        let latest = radio.timelineSongs.first?.playedAt.formatted(date: .omitted, time: .shortened) ?? "—"
                        Text("Latest \(latest) · checked \(checked.formatted(date: .omitted, time: .shortened))")
                            .font(TypeStyle.body(12)).foregroundStyle(Palette.muted)
                            .padding(.bottom, 17)
                    } else {
                        Text("Checking the station playlist…")
                            .font(TypeStyle.body(12)).foregroundStyle(Palette.muted)
                            .padding(.bottom, 17)
                    }
                    if radio.timelineSongs.isEmpty {
                        Text("Songs will appear when WFUV updates its playlist.")
                            .font(TypeStyle.body(15)).foregroundStyle(Palette.muted)
                    }
                    ForEach(days, id: \.self) { day in
                        Text(day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()).uppercased())
                            .font(TypeStyle.bold(11)).tracking(1.2).foregroundStyle(Palette.red)
                            .padding(.top, 13).padding(.bottom, 9)
                        ForEach(radio.timelineSongs.filter { Calendar.current.isDate($0.playedAt, inSameDayAs: day) }) { song in
                            SongRow(song: song, isLiveOnly: radio.liveOnlySong?.id == song.id)
                            Divider().padding(.leading, 60)
                        }
                    }
                    Text("Earlier entries are collected while this app is used.")
                        .font(TypeStyle.body(12)).foregroundStyle(Palette.muted).padding(.top, 24)
                }
                .padding(.horizontal, 22)
                .padding(.top, 12)
                .padding(.bottom, 110)
                .background {
                    GeometryReader { proxy in
                        Color.clear.preference(key: ListenScrollKey.self,
                                               value: proxy.frame(in: .named("listenScroll")).minY)
                    }
                }
            }
            .coordinateSpace(name: "listenScroll")
            .refreshable { await radio.refresh() }
            .modifier(ListenScrollObserver(offset: $scrollPosition))

            if scrollPosition > 270 { compactPlayer.transition(.move(edge: .top).combined(with: .opacity)) }
        }
        .background(Palette.cream.ignoresSafeArea())
        .animation(.easeOut(duration: 0.18), value: scrollPosition > 270)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            Text("90.7").foregroundStyle(Palette.red)
            Text("WFUV").foregroundStyle(Palette.ink)
            Spacer()
            Text("FUV LISTENER · INDEPENDENT").font(TypeStyle.bold(9)).tracking(0.7).foregroundStyle(Palette.muted)
        }
        .font(TypeStyle.bold(23))
        .accessibilityElement(children: .combine)
    }

    private var hero: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                Image(uiImage: currentArtwork)
                    .resizable().scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .blur(radius: 40)
                    .overlay {
                        LinearGradient(colors: [Palette.ink.opacity(0.30), Palette.ink.opacity(0.88)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    }
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 7) {
                        Circle().fill(Palette.red).frame(width: 8, height: 8)
                        Text(radio.liveTrack == nil || radio.isConfirmedLive ? "ON AIR · WFUV" : "LATEST PLAYED · WFUV")
                            .font(TypeStyle.bold(11)).tracking(1.3)
                    }
                    .foregroundStyle(.white.opacity(0.82))
                    Image(uiImage: currentArtwork)
                        .resizable().scaledToFill()
                        .frame(width: 108, height: 108)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay { RoundedRectangle(cornerRadius: 8).strokeBorder(.white.opacity(0.25)) }
                        .shadow(color: .black.opacity(0.32), radius: 14, y: 6)
                        .padding(.top, 13)
                        .accessibilityHidden(true)
                    Spacer(minLength: 8)
                    Text(title)
                        .font(TypeStyle.headline(32))
                        .foregroundStyle(.white)
                        .lineLimit(3)
                        .minimumScaleFactor(0.78)
                    Text(artist)
                        .font(TypeStyle.body(21))
                        .foregroundStyle(.white.opacity(0.78))
                        .lineLimit(2)
                        .padding(.top, 7)
                    HStack {
                        Spacer()
                        PlaybackButton(diameter: 68)
                    }
                    .padding(.top, 15)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 22)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
        .frame(height: 376)
    }

    private var secondaryControls: some View {
        HStack(spacing: 8) {
            AirPlayView().frame(width: 34, height: 34)
            Text("Output").font(TypeStyle.body(13))
            Spacer()
            Menu {
                Button(radio.dataSaverEnabled ? "✓ Data saver · 64k AAC" : "Data saver · 64k AAC") { radio.setDataSaver(true) }
                Button(!radio.dataSaverEnabled ? "✓ High quality · 128k MP3" : "High quality · 128k MP3") { radio.setDataSaver(false) }
                Divider()
                if radio.sleepEnd != nil { Button("Turn off timer") { radio.setSleepTimer(minutes: nil) } }
                ForEach([15, 30, 60], id: \.self) { minutes in
                    Button("Stop in \(minutes) minutes") { radio.setSleepTimer(minutes: minutes) }
                }
                Button("Reconnect stream") { radio.reconnect() }
            } label: {
                Label("Options", systemImage: "ellipsis")
                    .font(TypeStyle.body(13))
                    .frame(height: 44)
            }
            .accessibilityLabel("Playback options")
        }
        .foregroundStyle(Palette.muted)
        .padding(.horizontal, 4)
    }

    private var compactPlayer: some View {
        HStack(spacing: 12) {
            Image(uiImage: currentArtwork)
                .resizable().scaledToFill()
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 7))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                if radio.liveTrack != nil && !radio.isConfirmedLive {
                    Text("LATEST PLAYED")
                        .font(TypeStyle.bold(9)).tracking(0.8).foregroundStyle(Palette.red)
                }
                Text(title).font(TypeStyle.headline(17)).lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                Text(artist).font(TypeStyle.body(13)).foregroundStyle(Palette.muted).lineLimit(1)
            }
            Spacer(minLength: 4)
            PlaybackButton(diameter: 48)
        }
        .foregroundStyle(Palette.ink)
        .padding(.horizontal, 20).padding(.vertical, 10)
        .background(Palette.cream)
        .overlay(alignment: .bottom) { Rectangle().fill(Palette.pale).frame(height: 1) }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("compactPlayer")
    }
}

private struct ArtworkCard: View {
    let image: UIImage?
    let height: CGFloat
    var onAir = false

    var body: some View {
        GeometryReader { geometry in
            let artwork = image ?? StationArtwork.image
            ZStack {
                Image(uiImage: artwork)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: height)
                    .blur(radius: 30)
                    .overlay {
                        LinearGradient(colors: [Palette.ink.opacity(0.32), Palette.ink.opacity(0.82)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    }
                Image(uiImage: artwork)
                    .resizable()
                    .scaledToFit()
                    .frame(width: min(geometry.size.width * 0.62, height * 0.76), height: height * 0.76)
                    .shadow(color: .black.opacity(0.38), radius: 20, y: 9)
            }
            .frame(width: geometry.size.width, height: height)
            .overlay(alignment: .topLeading) {
                if onAir {
                    Text("ON AIR")
                        .font(TypeStyle.bold(10)).tracking(1.3)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .foregroundStyle(.white)
                        .background(Palette.red, in: Capsule())
                        .padding(14)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .frame(height: height)
    }
}

private struct AirPlayView: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let view = AVRoutePickerView()
        view.tintColor = UIColor(Palette.ink)
        view.activeTintColor = UIColor(Palette.red)
        return view
    }
    func updateUIView(_ view: AVRoutePickerView, context: Context) {}
}

private struct SavedView: View {
    @EnvironmentObject private var radio: RadioStore
    @State private var search = ""
    @State private var sharedDocument: SharedDocument?
    @State private var showingExportError = false

    private var savedSongs: [Song] { radio.savedSongs }
    private var visibleSongs: [Song] {
        savedSongs.filter {
            search.isEmpty || $0.title.localizedCaseInsensitiveContains(search) || $0.artist.localizedCaseInsensitiveContains(search)
        }
    }
    private var days: [Date] {
        Array(Set(visibleSongs.map { Calendar.current.startOfDay(for: $0.playedAt) })).sorted(by: >)
    }

    var body: some View {
        NavigationStack {
            List {
                forEachDays
                if visibleSongs.isEmpty {
                    Section {
                        ContentUnavailableView("No favorites yet", systemImage: "heart", description: Text("Tap a heart beside a song on Listen."))
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.cream)
            .navigationTitle("Favorites")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { shareExport() } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(savedSongs.isEmpty)
                    .accessibilityLabel("Share favorites")
                }
            }
            .searchable(text: $search, prompt: "Song or artist")
            .refreshable { await radio.refresh() }
            .sheet(item: $sharedDocument) { document in
                ActivitySheet(items: [document.url])
            }
            .alert("Could not share favorites", isPresented: $showingExportError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Please try again.")
            }
        }
    }

    private var forEachDays: some View {
        ForEach(days, id: \.self) { day in
            Section(day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())) {
                ForEach(visibleSongs.filter { Calendar.current.isDate($0.playedAt, inSameDayAs: day) }) { song in
                    SongRow(song: song)
                }
            }
        }
    }

    private func shareExport() {
        do {
            sharedDocument = SharedDocument(url: try SongExport.saveToFiles(savedSongs))
        } catch {
            showingExportError = true
        }
    }

}

private struct SharedDocument: Identifiable {
    let url: URL
    var id: URL { url }
}

private struct ActivitySheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

private struct SongRow: View {
    @EnvironmentObject private var radio: RadioStore
    @State private var showingDetail = false
    @State private var thumbnail: UIImage?
    @State private var thumbnailSongID: String?
    let song: Song
    var isLiveOnly = false

    var body: some View {
        HStack(spacing: 4) {
            Button { showingDetail = true } label: {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 7).fill(Palette.ink)
                        Image(uiImage: (thumbnailSongID == song.id ? thumbnail : nil) ?? radio.cachedArtwork(for: song) ?? SongArtwork.image(title: song.title, artist: song.artist, size: 160))
                            .resizable().scaledToFill()
                    }
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                    VStack(alignment: .leading, spacing: 1) {
                        if isLiveOnly {
                            Text("ON AIR · LIVE FEED")
                                .font(TypeStyle.bold(9)).tracking(0.6).foregroundStyle(Palette.red)
                        }
                        Text(song.title).font(TypeStyle.headline(17)).foregroundStyle(Palette.ink).lineLimit(2)
                        Text(song.artist).font(TypeStyle.body(14)).foregroundStyle(Palette.muted).lineLimit(1)
                    }
                    Spacer(minLength: 2)
                    Text(song.playedAt, format: .dateTime.hour().minute())
                        .font(TypeStyle.body(11)).foregroundStyle(Palette.muted)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Details for \(song.title) by \(song.artist)")
            Button { radio.toggleFavorite(song) } label: {
                Image(systemName: radio.favorites.contains(song.favoriteID) ? "heart.fill" : "heart")
                    .font(.system(size: 20))
                    .foregroundStyle(Palette.red)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(radio.favorites.contains(song.favoriteID) ? "Remove \(song.title) from favorites" : "Add \(song.title) to favorites")
        }
        .padding(.vertical, 9)
        .sheet(isPresented: $showingDetail) { SongDetailView(song: song) }
        .task(id: "\(song.id)|\(radio.favorites.contains(song.favoriteID))") {
            if thumbnailSongID != song.id {
                thumbnailSongID = song.id
                thumbnail = radio.cachedArtwork(for: song)
            } else if thumbnail == nil {
                thumbnail = radio.cachedArtwork(for: song)
            }
            guard radio.favorites.contains(song.favoriteID) || radio.timelineSongs.prefix(8).contains(song) else { return }
            if let cached = await ArtworkService.shared.cachedImageData(title: song.title, artist: song.artist) {
                guard !Task.isCancelled else { return }
                displayArtwork(cached)
                if let refreshed = await ArtworkService.shared.imageData(title: song.title, artist: song.artist),
                   refreshed != cached, !Task.isCancelled {
                    displayArtwork(refreshed)
                }
                return
            }
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled else { return }
            if let data = await ArtworkService.shared.imageData(title: song.title, artist: song.artist) {
                guard !Task.isCancelled else { return }
                displayArtwork(data)
            }
        }
    }

    private func displayArtwork(_ data: Data) {
        guard let image = UIImage(data: data) else { return }
        thumbnail = image
        radio.receiveArtwork(image, for: song)
    }
}

private struct SongDetailView: View {
    @EnvironmentObject private var radio: RadioStore
    @Environment(\.dismiss) private var dismiss
    @State private var artwork: UIImage?
    @State private var artworkSongID: String?
    let song: Song

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 17) {
                    ArtworkCard(image: (artworkSongID == song.id ? artwork : nil) ?? radio.cachedArtwork(for: song) ?? SongArtwork.image(title: song.title, artist: song.artist), height: 270)
                    Text(song.title).font(TypeStyle.headline(30)).foregroundStyle(Palette.ink)
                    Text(song.artist).font(TypeStyle.body(18)).foregroundStyle(Palette.muted)
                    Text("Played on WFUV · \(song.playedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(TypeStyle.body(13)).foregroundStyle(Palette.muted)
                    Link(destination: song.spotifySearchURL) {
                        Label("Find on Spotify", systemImage: "magnifyingglass")
                            .font(TypeStyle.bold(16))
                            .frame(maxWidth: .infinity).frame(height: 52)
                            .background(Palette.ink, in: RoundedRectangle(cornerRadius: 11))
                            .foregroundStyle(.white)
                    }
                    Button { radio.toggleFavorite(song) } label: {
                        Label(radio.favorites.contains(song.favoriteID) ? "Favorite song" : "Add to favorites", systemImage: radio.favorites.contains(song.favoriteID) ? "heart.fill" : "heart")
                            .font(TypeStyle.bold(15)).foregroundStyle(Palette.red)
                            .frame(maxWidth: .infinity).frame(height: 48)
                    }
                }
                .padding(22)
            }
            .background(Palette.cream.ignoresSafeArea())
            .navigationTitle("Song")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
            .task(id: song.id) {
                artworkSongID = song.id
                artwork = radio.cachedArtwork(for: song)
                if artwork == nil,
                   let cached = await ArtworkService.shared.cachedImageData(title: song.title, artist: song.artist),
                   let image = UIImage(data: cached), !Task.isCancelled {
                    artwork = image
                    radio.receiveArtwork(image, for: song)
                }
                guard let data = await ArtworkService.shared.imageData(title: song.title, artist: song.artist) else { return }
                guard !Task.isCancelled, let image = UIImage(data: data) else { return }
                artwork = image
                radio.receiveArtwork(image, for: song)
            }
        }
    }
}

private struct DiscoverView: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("GO DEEPER").font(TypeStyle.bold(11)).tracking(1.5).foregroundStyle(Palette.red)
                        Text("Music discovery lives here.")
                            .font(TypeStyle.headline(23)).foregroundStyle(Palette.ink)
                        Text("Shows, sessions, and stories straight from WFUV.")
                            .font(TypeStyle.body(14)).foregroundStyle(Palette.muted)
                    }
                    .padding(.vertical, 13)
                }
                Section("Explore") {
                    NavigationLink {
                        ShowsView()
                    } label: {
                        Label("Shows & schedule", systemImage: "calendar")
                            .foregroundStyle(Palette.ink)
                            .font(TypeStyle.body(16))
                    }
                    stationLink("Live sessions", icon: "waveform", url: "https://wfuv.org/fuvlive")
                    stationLink("Archives", icon: "archivebox", url: "https://wfuv.org/archives")
                    stationLink("Full playlist", icon: "music.note.list", url: "https://wfuv.org/playlist")
                }
                Section("Support the music") {
                    stationLink("Become a member", icon: "heart", url: "https://wfuv.org/membership")
                }
                Section {
                    Text("An independent listener app. WFUV owns its broadcast and branding. This app plays the station’s stream as provided, including ads and station messages.")
                        .font(TypeStyle.body(12)).foregroundStyle(Palette.muted)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.cream)
            .navigationTitle("Discover")
        }
    }

    private func stationLink(_ title: String, icon: String, url: String) -> some View {
        Link(destination: URL(string: url)!) {
            Label(title, systemImage: icon)
                .font(TypeStyle.body(16))
                .foregroundStyle(Palette.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 5)
        }
    }
}

private struct ShowsView: View {
    private struct Program: Identifiable {
        let day: String
        let time: String
        let title: String
        let host: String
        let url: String
        var id: String { title }
    }

    private let shows: [Program] = [
        Program(day: "SATURDAY", time: "4–8 PM", title: "Mixed Bag", host: "Don McGee", url: "https://wfuv.org/content/mixed-bag"),
        Program(day: "SATURDAY", time: "8–11 PM", title: "Shocking Blue", host: "Delphine Blue", url: "https://wfuv.org/showshostsschedule"),
        Program(day: "SUNDAY", time: "8–11 AM", title: "A Thousand Welcomes", host: "Kathleen Biggins", url: "https://wfuv.org/content/thousand-welcomes"),
        Program(day: "SUNDAY", time: "NOON–4 PM", title: "Ceol na nGael", host: "WFUV", url: "https://wfuv.org/showshostsschedule"),
        Program(day: "SUNDAY", time: "4–7 PM", title: "Cavalcade", host: "Paul Cavalconte", url: "https://wfuv.org/cavalcade"),
        Program(day: "SUNDAY", time: "7–8 PM", title: "UKNY", host: "Kara Manning", url: "https://wfuv.org/showshostsschedule")
    ]

    var body: some View {
        List {
            Section {
                Text("Music discovery all week, with specialty shows on the weekend. Times are Eastern.")
                    .font(TypeStyle.headline(18))
                    .padding(.vertical, 8)
            }
            ForEach(["SATURDAY", "SUNDAY"], id: \.self) { day in
                Section(day.capitalized) {
                    ForEach(shows.filter { $0.day == day }) { show in
                        Link(destination: URL(string: show.url)!) {
                            HStack(alignment: .top, spacing: 15) {
                                Text(show.time)
                                    .font(TypeStyle.bold(11))
                                    .frame(width: 90, alignment: .leading)
                                    .foregroundStyle(Palette.red)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(show.title).font(TypeStyle.headline(17))
                                    Text(show.host).font(TypeStyle.body(13)).foregroundStyle(Palette.muted)
                                }
                                Spacer()
                                Image(systemName: "arrow.up.right").font(.caption).foregroundStyle(.secondary)
                            }
                            .foregroundStyle(Palette.ink)
                            .padding(.vertical, 6)
                        }
                    }
                }
            }
            Section {
                Link("Check WFUV's full schedule", destination: URL(string: "https://wfuv.org/showshostsschedule")!)
                    .foregroundStyle(Palette.red)
            } footer: {
                Text("Show times are based on WFUV’s published schedule and may change. Check the station for the latest information.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Palette.cream)
        .navigationTitle("Shows")
    }
}
