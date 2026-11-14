# FUV Listener design guide

## Product shape

The app has three destinations: **Listen**, **Favorites**, and **Discover**. Listen combines the live player and the station's timestamped playlist in one continuous scroll. Favorites holds the songs the listener marked with a heart, with Markdown sharing. Discover holds station links and the show guide. There is no separate History tab or three-song preview.

The expanded player leads the Listen screen. As it scrolls away, a compact player stays fixed at the top, above the playlist. The compact player shows current cover or designed fallback art, title, artist, and one playback control. Titles may wrap to three lines. Playlist rows continue underneath it.

## Visual hierarchy

1. **Current song:** Bitter Bold at 32 points in the expanded player, up to three lines; artist in Heebo at 21 points. The title should remain readable without relying on artwork text.
2. **Playback:** one circular red play/pause control. Icon-only on screen, with a descriptive accessibility label. AirPlay and stream settings are smaller secondary controls.
3. **Playlist:** day heading, 17-point Bitter song title, 14-point Heebo artist, time, and 44-point save target. Tap the song for Spotify and details.
4. **Station identity:** small 90.7 WFUV header and an independent-app label. No duplicate "live from" slogan or oversized station tile on Listen.

## Color and artwork

- Base surfaces: warm white `#F9F8F5`, near black `#141416`, WFUV-inspired red `#CF1F37`.
- Missing-cover artwork uses three deterministic color families: wine, midnight blue, and rust. The variant is derived from song metadata so it stays stable across visits.
- The expanded player uses the cover as a soft background and shows a clear square on the same left grid as the page header, playlist thumbnails, and compact player. Title and artist remain live text below.
- When a reliable external cover exists, show it in the expanded player, song detail, list thumbnails, and system Now Playing. Prefer an ordinary album release group to a soundtrack or compilation. Do not accept a multi-artist credit as a match for a single artist.
- When no cover exists, use a title-and-artist graphic in detail, thumbnails, and Now Playing. Station announcements use a station graphic.

## Interaction rules

- One shape and behavior for primary playback: red circle, play or pause icon, 68 points expanded and 48 points compact.
- Secondary actions use plain icons or quiet text with at least 44-point touch areas. Favorite uses a heart; Favorites has a standard top-right share button that opens the native share sheet.
- Favorites remain after they leave the 500-item recent feed. Sharing first writes `WFUV-favorites.md` to the app's Files folder, then offers that same file to other apps.
- Spotify opens a search for the chosen track; the app does not require Spotify sign-in.
- The playlist heading shows the newest entry time and the last successful check. Its refresh button and pull gesture both request a fresh feed URL. If the request fails, show an error even when older entries remain.
- Compare the live metadata timestamp with the newest playlist entry. A newer, recent playlist song may drive the player temporarily, but label it **Latest played** until the live endpoint confirms it. Coalesce simultaneous refresh requests so only one pair of feed requests updates state.
- If the live endpoint advances before the playlist, prepend its song as a labeled **On air · live feed** row. The first visible row and player should name the same song. Remove that provisional row once the playlist includes the song. A heart identifies title and artist across repeated broadcasts, not a single timestamp.
- Playlist refresh failure appears as a compact Retry notice and dismisses after six seconds. Keep the last successful check visible.

## Storage and limits

External artwork is resized to at most 600 pixels and cached in Application Support. Keep at most 400 files and 80 MB on disk, retaining Favorites ahead of recent art when pruning. Memory caches are capped at 24 MB for generated artwork and 20 MB for fetched encoded images. Generate list placeholders at 160 pixels and load playlist rows lazily. Generated fallback art is not written to disk. Preserve existing downloaded art while revalidating older cache entries, and store the image source and release choice in the cache index. MusicBrainz lookup remains rate limited to roughly one request per second, with a shared pause after service errors. Search recording and artist fields separately and prioritize studio albums over live, broadcast, soundtrack, and compilation releases.

## Verification and remaining work

Check initial Listen, scrolled compact player, Favorites, and song detail on simulator and iPhone. Verify play/pause, favorite, export, and Spotify actions. Album-art coverage depends on station metadata and third-party catalogs, so the designed fallback is a normal state. Dynamic Type and physical Lock Screen expansion still merit a separate visual audit.
