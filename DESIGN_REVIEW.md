# WFUV Listener design review

Reviewed November 14, 2026 against the [WFUV site](https://wfuv.org/), the [station playlist](https://wfuv.org/playlist), and iOS 27 simulator and iPhone 17 screenshots. The first score describes the original 1.0 app; the second rates the refreshed 1.1 build.

| Area | Before → after / 10 | What works | Main issue | Improvement |
| --- | ---: | --- | --- | --- |
| Brand fit | 4 → 8 | WFUV-inspired red, ink, warm white, and editorial typography | Independent app cannot use the station's official visual identity as its own | Keep the independent label, refine spacing and type on smaller phones |
| Listen screen | 6 → 8 | Live cover, current song, controls, and recent songs fit together | Long titles can still push the recent list downward | Tune layout for large text and compact devices |
| History and saving | 6 → 8 | Larger hearts, day grouping, search, Spotify links, and CSV export | Rows use a generic note thumbnail even when cover art exists | Load and cache matched artwork for visible rows |
| Discover | 5 → 6 | Clear station links and support path with a stronger introduction | Still mostly a list of external links | Add richer station content previews when a stable feed is available |
| Shows | 5 → 6 | Weekend guide is readable and links to WFUV | Schedule is manually maintained | Read live schedule data if the station publishes a supported feed |
| Lock Screen / Dynamic Island | 4 → 6 | Now Playing receives current metadata, play/pause state, and album or fallback artwork | iOS chooses the presentation; a physical Lock Screen and Island visual check remains | Verify on device during active playback and tune art if needed |
| Accessibility | 6 → 7 | Native controls, larger hit areas, relative custom fonts, and clear contrast | Large Dynamic Type and VoiceOver flow have not been audited end to end | Test those modes on device and fix clipping or reading order |
| App icon | 5 → 8 | Red/black 90.7 FUV Listener icon matches the app palette | Fine text is small at icon scale | Simplify secondary text if legibility is weak on Home Screen |

## Implementation priorities

1. Make the player and system Now Playing surfaces feel like one coherent WFUV-inspired product.
2. Keep the first screen compact enough to show what is playing and at least one recent song.
3. Make saved songs useful outside the app through CSV export and Spotify search links.
4. Use station artwork first, then a careful album-art lookup only when title and artist match. Fall back to branded artwork when no reliable image is available.
5. Keep the station feed and show schedule as the source of truth; the app remains independent and does not reproduce the station's proprietary logo asset.

## Constraints

- Spotify links can open search without account access. Writing directly to a Spotify playlist needs a registered Spotify developer app and OAuth; that integration is outside this version by user choice.
- Album covers can be missing or ambiguous. Do not show a guessed cover for a weak match.
- iOS controls Lock Screen media layout and Dynamic Island presentation; the app supplies metadata, artwork, and play/pause commands through Now Playing.

## Verification

- The 1.1 iPhone device build compiled, installed, and launched on a paired iPhone 17. A device screenshot showed a real album cover for the live track.
- Simulator UI checks covered the main screens, a song detail sheet with Spotify link, saving and exporting, and background playback after Home. The app's Now Playing metadata is supplied through the system media APIs.
- A physical Lock Screen and Dynamic Island screenshot during active playback remains the main unverified visual detail. The simulator Home Screen capture did not establish how iOS renders those system surfaces on the phone.

## Second design pass · November 14, 2026

The user reported that album covers did not persist, the wide artwork panel looked like a centered square, the play button had too little emphasis, and the saved-song share sheet appeared blank. A separate read-only Claude review scored the previous player hierarchy **5/10**, artwork **3/10**, export clarity **3/10**, History **6/10**, and system media **7/10**. It independently identified the in-memory-only artwork cache, equal-weight controls, ambiguous export icon, and a second data-loss risk: saved songs could disappear when History reached its 500-song limit.

| Area | Before → revised / 10 | Change | Remaining issue |
| --- | ---: | --- | --- |
| Player hierarchy | 5 → 8 | Full-width 68-point red play/pause control; output and options moved to a subdued row | Long song titles still move controls downward |
| Artwork | 3 → 7 | Blurred cover backdrop, gradient, framed cover, persistent disk cache, and saved/recent thumbnails | Some recordings lack art, and a matched release can be a compilation or soundtrack rather than the original album |
| Export clarity | 3 → 9 | Explicit labeled action writes CSV to the app's Files folder and confirms its location | The user still has to open Files to share or move the CSV |
| History and saving | 6 → 8 | Saved entries now store complete song records and survive the 500-song History cap | Older unsaved songs still depend on the station's limited playlist feed |
| System media | 7 → 7 | Cached art reaches Now Playing on repeat plays; a compact WFUV tile was observed in the iPhone's Dynamic Island | Expanded Island and Lock Screen presentation still need a playback visual check |

The revised simulator build passed UI checks for the main screens, saved-song persistence across relaunch, and the export success alert. The resulting CSV was inspected in the simulator app's `Documents` folder and contained the expected songs and Spotify URLs. Apple's [File Provider documentation](https://developer.apple.com/documentation/fileprovider) confirms that the two enabled document-sharing keys expose that folder in Files.

## Third pass · missing artwork

The user still saw many missing covers on iPhone and found the generic station tile unhelpful for songs. The app now generates a distinct song cover with title, artist, and a subdued WFUV cue whenever no reliable release image arrives. This is used in Listen, song detail, recent rows, and the system Now Playing metadata. The active button is text-only **Pause**, with the fuller action retained as its accessibility label.

MusicBrainz results exposed a matching error: testing only whether *one* credited artist matched could select a multi-artist soundtrack entry for a single artist. Matching now requires the full credited artist string to match, and official album release groups rank ahead of soundtracks and compilations. This can reduce cover hit rate for songs with incomplete station credits, but the generated cover keeps the player informative. The artwork cache was versioned to avoid continuing to display earlier mismatches; covers will be fetched again as songs appear.

Revised artwork score: **8/10** for a coherent presentation whether a cover is found or not. Catalog coverage and original-album identification remain imperfect.

## Fourth pass · one timeline and a fixed player

The separate History tab duplicated the three-song preview on Listen. Listen now contains the full timestamped station playlist in one scroll, and Saved holds only the songs the listener kept. The expanded player uses larger live title and artist text over a colored backdrop, with one prominent circular play/pause button. It collapses to a fixed title, artist, and play/pause bar while the playlist moves beneath it. Output and stream settings remain secondary actions. Missing covers use three stable color families, and fetched artwork has explicit memory and disk limits.

| Area | Current / 10 | Evidence and next refinement |
| --- | ---: | --- |
| Navigation | 9 | Listen, Saved, Discover each have a distinct job; the separate History destination is gone. |
| Player hierarchy | 8 | Large title and primary play/pause control are clear; live song metadata can be absent when the station feed has no current track. |
| Playlist readability | 8 | Larger title/artist, visible timestamps, and full day-grouped scroll; very long titles still wrap to two lines. |
| Missing-cover treatment | 8 | Title and artist appear in wine, blue, or rust artwork instead of a generic station square; tiny thumbnails cannot show every word at full size. |
| Saved and export | 9 | Saved songs are separate from recent history and CSV export has a labeled completion path. |
| Cache discipline | 9 | Generated art memory is capped at 24 MB; fetched art memory at 20 MB; fetched disk files at 80 or 30 MB, whichever is reached first. |
| Lock Screen / Dynamic Island | 6 | Now Playing supplies album or generated art and playback state; expanded system surfaces have not been visually verified on the physical phone. |

The current simulator and signed iPhone builds passed. Simulator UI checks passed for the compact player, play/pause, and saved-song export. The updated app installed and launched on the paired iPhone 17; a device screenshot confirms the compact bar stays above the scrolled playlist with the current song title and artist. Cover matching still depends on the station's metadata and MusicBrainz/Cover Art Archive coverage. See the [design guide](DESIGN_GUIDE.md) for the interaction and storage rules used in this pass.

## Fifth pass · cover search and sharing

The compact bar now retains a 52-point cover, or the designed song/station fallback, beside a title that can wrap to three lines. The expanded player borrows the available cover as a soft background. MusicBrainz search checks 40 candidates instead of 10, ranks ordinary albums ahead of soundtrack and compilation release groups, and uses release date and WFUV album metadata when available to choose among albums. Transient lookup failures pause retries; a long-running live track is eligible for another attempt after five minutes. The disk cache was versioned so older mismatches are not carried forward.

WFUV's current-song JSON sometimes returns its generic placeholder image and an empty album field. MusicBrainz returned HTTP 503 during this review, so the revised search cannot guarantee higher cover coverage until the service responds. Its [published rate limit](https://musicbrainz.org/doc/MusicBrainz_API/Rate_Limiting) supports the app's one-request-per-second pacing and error backoff. Apple's [iTunes Search API terms](https://developer.apple.com/library/archive/documentation/AudioVideo/Conceptual/iTuneSearchAPI/) restrict its artwork to promotion near an Apple store link; using it as a background source in this Spotify-focused radio player would not fit that stated use.

Saved songs now export as a readable Markdown file with artist, timestamp, and Spotify link. Tapping Share writes the file to the app's Files folder first, then opens the native iOS share sheet. The simulator showed the file preview and actions including Copy and Save to Files. Available destinations depend on apps installed on the phone.

| Area | Current / 10 | Remaining limit |
| --- | ---: | --- |
| Compact player | 9 | Album image still depends on an available, matched source. |
| Cover matching | 7 | Third-party outages and incomplete station metadata still leave some songs with fallback art. |
| Saved-song sharing | 9 | Destination apps decide whether they accept a Markdown attachment. |

## Sixth pass · playlist freshness and image speed

WFUV's RSS endpoint was returning an HTTP 200 response with `Cache-Control: max-age=3600, public` and an `Age` value of 56 seconds. Its newest song advanced during the check, so the station feed was publishing; a pull could still appear unchanged while an edge cache served an older response. The app now adds a fresh request key, rejects malformed or empty feeds, shows the latest song time and last successful check, and offers a visible refresh button. The simulator showed a 1:14 PM song with a 1:16 PM check time and passed the refresh UI check.

The Listen timeline now places song rows directly in a lazy stack. Small fallback covers render at 160 pixels instead of 800 pixels, while the player keeps full-size artwork. A brief row delay gives the live track a chance to request artwork first; MusicBrainz service failures now pause all queued lookups, and cover downloads have shorter timeouts. This keeps the designed fallback visible immediately while external images load. The Saved screen now has a single “Share N songs” action without repeated instructions; the native share sheet and Markdown file remain intact. Simulator UI checks passed for refresh, compact playback layout, and sharing.

## Seventh pass · stale live metadata

The user's screenshot showed a 1:18 PM song in the playlist while the main player still displayed a 1:14 PM song. WFUV serves the playlist and live metadata from separate endpoints; the live endpoint had caught up by the next check, but the app could retain an old live response or apply an older overlapping refresh after a newer one. Both requests now bypass web caches, and the app compares their timestamps. When a recent playlist entry is newer, the player shows it with a **Latest played** label; when the live endpoint catches up, it regains priority. A stale live item older than 30 minutes is cleared. Overlapping refreshes cannot overwrite newer results. The timestamp-selection check and simulator compact-player UI check passed.

## Eighth pass · artwork and state

The next iPhone screenshot showed a real album cover in the newest playlist row while the expanded player used only a dark text background. The row and player requested artwork independently; the player could stop retrying for five minutes before the row found and cached the cover. The row and song detail now pass a matched cover to the player and system Now Playing as soon as it arrives. Artwork requests for the same song share one in-flight lookup, and a completed lookup cannot paint a different current song. The expanded player also shows a clear cover at the top right over its soft artwork background.

The state review found duplicate refreshes when the app became active and queued AVPlayer observation callbacks that could outlive a reconnect. Refresh callers now await one in-flight request, a new live response cannot replace a newer station timestamp, and playback observers check that they still belong to the current player item. The simulator build and three UI checks passed for Listen and its compact header, play/pause, and Saved export. MusicBrainz returned a busy response during this pass, so the simulator screenshot shows the designed fallback; the album cover already visible in a playlist row on the iPhone should now flow into its main player.

## Ninth pass · stable covers and Favorites

The user observed covers swapping back to fallback artwork and pointed out that a heart means Favorite, not Saved. The player had keyed cover state to WFUV's album and artwork URL as well as the song, so a metadata change for the same song could clear a real cover. It now keys covers to title and artist, retains the image through same-song refreshes, and keeps a bounded 24 MB memory cache shared by the player, recent rows, Favorites, and detail. Rows read the existing disk cache before delaying a new lookup; a row recreated by a tab switch or favorite toggle can show a cached cover immediately. The disk cache remains bounded at 30 MB and 80 files.

The heart destination, row actions, detail button, share action, Markdown heading, and export filename now say **Favorites**. Existing favorite records keep their storage keys so the update does not discard the user's selections. The simulator build and three UI cases passed, and the signed app installed on the paired iPhone.

## Tenth pass · shared first row and alignment

The user saw the expanded player advance before the playlist's first row and found the top-right cover disconnected from the left-aligned page and compact player. The cover, status, and title now use the same left grid as the header and playlist thumbnails. The card retains a small outer margin and a larger internal player surface.

The live and playlist endpoints can advance in either order. When the playlist is newer, its top entry temporarily drives the player as **Latest played**. When the live endpoint is newer, the player keeps the confirmed live track and a labeled **On air · live feed** row appears above older playlist entries. The row disappears when the playlist catches up. Playlist commits immediately recompute the player selection, so a fast playlist response cannot leave the list ahead of the player while the live request is still pending. Favorites now key on song and artist instead of one broadcast timestamp, so the heart remains filled when a provisional row becomes a playlist row. A model check covered both feed orders and repeated-song favorite identity; the simulator build and visual layout check passed.

The user also found the large share card awkward. Favorites now uses the standard top-right share button, leaving the list as the screen's main content. Its Markdown file and native share sheet are unchanged. A focused simulator UI check passed and showed `WFUV-favorites.md` with Copy and Save to Files actions.

The final signed build installed and launched on the paired iPhone. A device capture showed the same song, “Silent All These Years,” in the player and first playlist row, with both cover tiles loaded. Its cover came from a radio broadcast release rather than the original album, so release choice remains an artwork-matching limitation separate from the timeline sync.

## Eleventh pass · artwork coverage and cache

The prior search combined song and artist into one loose MusicBrainz query and inspected only 40 recordings. It now uses recording and artist fields separately and examines up to 100 recordings. Release ranking demotes live, broadcast, soundtrack, and compilation releases. MusicBrainz's search response often omits the release-group date; ranking now uses the earliest date among each group's releases. In a live lookup, “Silent All These Years” by Tori Amos selected **Little Earthquakes** instead of the earlier broadcast cover.

Downloaded images are downsampled through ImageIO to a 600-pixel maximum and encoded as JPEG before caching. The disk budget is now 400 images or 80 MB. Favorites are retained ahead of recent songs when pruning. A small index records the selected source and release, allowing older unindexed covers to remain visible while a better match is checked and negative results to expire after a day. The player revisits an unresolved cover without clearing the currently displayed image. A 1206×2622 screenshot compressed from 3.9 MB to 35 KB at 276×600; the Tori cover cached at 500×500 and 42 KB, then loaded from disk immediately on a second run. A pruning check retained a pinned Favorite while enforcing both limits. The simulator build and focused Listen UI check passed. Some songs still lack a reliable match or archive image, so the designed fallback remains necessary.

The Cover Art Archive can lack a community-selected image for a release group while an individual official release has a front image. The lookup now tries up to two dated official releases in a group after the group endpoint misses. A second isolated live lookup still selected the original **Little Earthquakes** cover at 500×500 and 42 KB.

Playlist request errors now use a compact Retry notice that dismisses after six seconds. The last successful check time remains visible, so failure feedback can be brief.
