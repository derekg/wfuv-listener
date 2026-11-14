# FUV Listener

An independent, open source iPhone listener for WFUV. It plays WFUV's own live stream, including station messages and ads. Listen combines a live player with the full timestamped playlist in one scroll; a compact player stays at the top as the feed moves underneath. Favorite songs have their own tab.

## Open and run

Open `FUVListener.xcodeproj` in Xcode 16 or later. Select an iPhone simulator or device and run. The app targets iOS 17 and later. For a device build, choose your development team in Signing & Capabilities.

## Screenshots

[Listen](Screenshots/listen.png), [compact player](Screenshots/compact-player.png), [Favorites](Screenshots/favorites.png), and [Markdown share sheet](Screenshots/share-sheet.png).

## Sources

- High-quality 128 kbps MP3 stream (default): `https://onair.wfuv.org/onair-hi`
- Data-saving 64 kbps AAC+ stream: `https://onair.wfuv.org/onair-aacplus`
- Now-playing metadata: `https://wfuv.org/sites/default/files/player/playlist/now_playing.json`
- Recent playlist RSS: `https://wfuv.org/playlist/feed`

These addresses were taken from WFUV's own player and playlist on November 14, 2026. The app does not remove station audio, ads, or announcements. Playlist history grows while the app is used; the station feed contains only recent entries, and iOS may suspend metadata refresh in the background. Listen shows the latest entry and last successful check time; its refresh button and pull gesture request fresh feed URLs. If live metadata lags behind a newer playlist song, the player temporarily shows that song as **Latest played** until WFUV's live feed catches up. If live metadata advances first, its song appears as an **On air · live feed** first row until the playlist catches up, keeping the player and first row aligned. The native weekend show guide follows WFUV's published schedule as of November 2026 and links to the station for updates. Archives open on WFUV's site.

The main player, song detail, compact player, and system Now Playing show a clear square cover when available. The player and playlist rows share artwork results, so a cover found by a row appears in the player for the same song. Otherwise, the app searches separate recording and artist fields through [MusicBrainz](https://musicbrainz.org/) and uses [Cover Art Archive](https://coverartarchive.org/) art when an official release has a cover. It checks up to 100 recordings, prefers studio albums ahead of live, broadcast, soundtrack, and compilation releases, and prioritizes earlier album releases. If a release group has no selected front image, it also checks a few official releases in that group. Missing or ambiguous covers use a song-specific typographic graphic with three stable color families; station announcements use a station graphic. Downloaded covers are resized to at most 600 pixels and stored in the app's Application Support directory, capped at 400 files and 80 MB on disk. Favorites are retained first when pruning. Cover artwork is supplied by third parties and may be unavailable.

Tap a song in Listen or Favorites to search for it on Spotify. Favorites remain available after they leave the recent playlist limit. Tap **Share favorites** in Favorites to create `WFUV-favorites.md` in **Files → On My iPhone → FUV Listener** and open the iOS share sheet. The Markdown includes song, artist, play time, and Spotify search URL, ready for an LLM, Mail, Files, or another share destination. This version does not write to a Spotify playlist or require Spotify sign-in. The Lock Screen and Dynamic Island use the system Now Playing presentation with supplied metadata and artwork; iOS determines their layout.

The app bundles Bitter and Heebo fonts under the SIL Open Font License; license files are in `FUVListener/Fonts`. The visual review is in [DESIGN_REVIEW.md](DESIGN_REVIEW.md), and the current rules are in [DESIGN_GUIDE.md](DESIGN_GUIDE.md).

This project is independent and is not affiliated with or endorsed by WFUV or Fordham University. WFUV's name identifies the stream being played. Please support the station through its membership link in the app.

## License

MIT. See `LICENSE`.
