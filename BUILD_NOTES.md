# Playtest Vault — Build Notes

Version 1.0.0 · Bundle ID `dev.joe.playtestvault` · iOS 26.0 · Swift 5
Project: `PlaytestVault.xcodeproj`, scheme `PlaytestVault`, app folder `PlaytestVault/`
Structure mirrors the GTA 6 Hub template (objectVersion 77, PBXFileSystemSynchronizedRootGroup — new .swift files in `PlaytestVault/` are picked up automatically).

## File list

| File | Purpose |
| --- | --- |
| `PlaytestVault/ContentView.swift` | @main app entry, 4-tab TabView (Discover / Demos / Vault / More), QA badge (QA config only) |
| `PlaytestVault/AppStore.swift` | Tab selection + language state; launch-arg hooks (-QAStartTab, -UITestMode) |
| `PlaytestVault/Models.swift` | Lang (DE/EN), DateParser, Countdown wording, PlaytestItem/PlaytestFeed, VaultStatus/VaultEntry, SteamDemo/SteamGameDetails |
| `PlaytestVault/Glass.swift` | VaultAccent (teal #2DD4BF), AppBackdrop (black + subtle teal glow), VaultPage, GlassCard, glassPill, TintedPill, DeadlineChip, CoverArt/CoverImage |
| `PlaytestVault/FeedService.swift` | FeedStore: playtests.json fetch + UserDefaults cache + pull-to-refresh; SampleData for -UITestMode |
| `PlaytestVault/SteamService.swift` | Steam demo search (HTML parsing) + appdetails; TextTools (HTML strip / entity decode) |
| `PlaytestVault/VaultStore.swift` | Vault persistence (UserDefaults "vault.entries.v1"), first-launch seeds, add/update/delete, sorting |
| `PlaytestVault/DiscoverView.swift` | Discover tab: search, glass feed cards, deadline chips |
| `PlaytestVault/PlaytestDetailView.swift` | Shared feed detail: info card, live countdown, open page, add to vault |
| `PlaytestVault/DemosView.swift` | Demos tab: New/Popular segmented control, live Steam rows |
| `PlaytestVault/SteamDetailView.swift` | Demo detail via appdetails (full game id), links to the demo store page |
| `PlaytestVault/VaultView.swift` | Vault tab: sorted list, swipe delete/edit, add/edit sheet, empty state |
| `PlaytestVault/MoreView.swift` | More/Settings: language toggle (de_DE/en_US), data sources note, version row 1.0.0 |
| `PlaytestVault/LaunchScreen.storyboard` | Black launch screen (copied from Hub) |
| `PlaytestVault/Assets.xcassets` | AppIcon (generated 1024 PNG: teal vault wheel + play hub on dark glass), AccentColor (teal) |
| `playtests.json` (project root) | Seed feed for the GitHub raw URL — 6 real entries, all deadlines null, images null |

## Endpoints

- Discover feed: `https://raw.githubusercontent.com/joe-design9/playtest-vault/main/playtests.json` (GET at launch + pull-to-refresh; last good payload cached in UserDefaults key `feed.cache.v1`, shown offline)
- Steam demo search: `https://store.steampowered.com/search/results/?query&start=0&count=50&dynamic_data=&sort_by={Released_DESC|_ASC}&force_infinite=1&category1=10&infinite=1&json=1&cc=de&l={german|en}` — parses `results_html`: `data-ds-appid` = demo id (images), href `/app/<id>/` = full game id (details), `span.title` = name
- Steam details: `https://store.steampowered.com/api/appdetails?appids=<fullGameID>&cc=de&l={german|en}`; "Open Steam page" links to `https://store.steampowered.com/app/<demoAppID>/`
- Capsule art: `https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/<demoAppID>/capsule_231x87.jpg` (header.jpg fallback)
- All requests send a Safari/iOS user agent; 20 s timeout; non-2xx = error state with retry

## QA hooks

Launch arguments are read in every configuration (not gated on the QA compilation condition):

- `-QAStartTab <0..3>` — preselects a tab (0 Discover, 1 Demos, 2 Vault, 3 More)
- `-UITestMode` — offline demo mode: Discover shows 3 bundled sample items, Demos shows 3 sample rows with gradient placeholders (no Steam fetch), the Vault is seeded with 3 demo entries in memory (nothing persisted)

The `QA` build configuration (cloned from Debug, Hub pattern) defines the `QA` compilation condition, which only adds the red QA badge overlay (tab/feed/vault counts) used for simulator screenshots.

Example: `PlaytestVault -UITestMode -QAStartTab 2`

## Build configurations & signing

- Debug / QA: `CODE_SIGN_STYLE = Automatic` (simulator + local signing, Hub pattern)
- Release: `CODE_SIGNING_ALLOWED = NO`, `CODE_SIGNING_REQUIRED = NO`, manual style — unsigned IPA build like the Hub
- Portrait only (`UIInterfaceOrientationPortrait`), dark appearance forced, display name "Playtest Vault" via `INFOPLIST_KEY_CFBundleDisplayName`

## Notes / decisions

- Language is stored as full locale codes (`de_DE` / `en_US`) in `appLanguage`; default is the device language. `Lang.steamLanguage` maps that to `german` / `en` for the Steam `l` parameter.
- Keyboard dismissal is tap-outside (`onTapGesture` clearing focus) plus `.scrollDismissesKeyboard(.interactively)` — there is no toolbar Done/Fertig button anywhere. The entry editor uses in-form Cancel/Save buttons.
- Vault seeds on first launch (flag `vault.seeded.v1`): Fantum playtest (access), Project SCOOP (done), Escape From Playtime (applied), players.gg applications (applied). Notes are seeded in the app language active at first launch.
- Feed status strings map to vault statuses on "Add to Vault": "Live now" → access, "Ended" → done, everything else → discovered.
- playtests.json seed entries stick to verifiable items (two known titles + Xbox Insider / PlayStation Beta programs + Steam Next Fest + FirstLook); deadlines are null where no date is certain.

## Open points

- None for source completeness. Not built/verified here (no Xcode in this environment) — first CI/QA build should confirm the glass modifiers and Steam HTML parsing against the live store response.
