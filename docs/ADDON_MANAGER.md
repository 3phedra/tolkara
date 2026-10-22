# Add-ons

The launcher has a native **Add-ons** screen for the selected WoW
installation: Retail, Classic, Classic Era or Forever Beta. Open it from the WoW
home. It never enables in-game features on the user's behalf; it only manages
files in that edition's `Interface/AddOns` and backs up its `WTF`.

## Discover

The Discover tab searches four online providers and accepts local ZIP imports:

- **Tukui** — public catalog and direct packages.
- **GitHub** — public repository search. A package is installed from the
  repository's own release. When a repository publishes several components with
  prefixed tags, such as `spoken/v3.5.0` and `zones-audio-deDE/v2.1.1`, the
  release whose tag prefix matches the repository is chosen, so a voice pack
  published later does not replace the add-on on install or update. A package
  stored with a `repo#component` identity follows that component's releases
  instead. Repositories without a ready-to-install ZIP asset point at their
  page and the ZIP import fallback.
- **CurseForge** — search and downloads require an API key entered from the
  add-ons menu and stored in the device Keychain. Files are selected for the
  selected installation's exact game version and required dependencies are
  installed first. Without a key the entry still links to the project page for
  a manual ZIP import.
- **Wago** — the public add-on page is read directly, so no API key or ad token
  is needed. Wago's own site search is web-only: search an exact name or paste
  the add-on URL from **Add from Wago URL…**. The public page's release for the
  selected flavor is downloaded through its signed link; the release's
  `supported_<flavor>_patches` and the package TOC are checked.

The recommended row includes RestedXP Guides (GitHub) and common CurseForge
projects. The providers are queried concurrently; provider failures become
messages and do not block the other results.

## Game version target

The manager reads the selected installation's `.build.info` and derives the
product, game version, build and add-on Interface. The screen footer shows the
target, for example `Forever Beta 1.60.1 · Interface 16001` or
`Retail 11.0.5 · Interface 110005`. Each edition keeps its own folder, so Retail,
Classic and Forever add-ons cannot cross-contaminate.

Multi-flavor packages are supported: a package may ship separate TOCs such as
`Addon.toc`, `Addon_Classic.toc` and `Addon_Vanilla.toc`. The manager accepts it
when the TOC for the selected Interface is present, ignores the other flavors'
TOCs for compatibility, and uses the matching TOC for the installed row.

- A package with no TOC declaring the selected Interface is rejected before any
  file is written. An absent Interface is allowed but is not evidence of
  compatibility.
- CurseForge file selection uses the exact game version, not a loose branch.
  Search results with no matching file are marked and cannot be installed.
- Tukui results are checked against the provider's patch list.
- GitHub release assets and imported ZIPs are validated after download through
  the same TOC check.
- Installed rows show their Interface and are marked incompatible when they do
  not match the selected game.

## CurseForge API key

CurseForge's API is keyed per **third-party application**, not per user. The key is
free but is issued only after Overwolf reviews an application submitted through
the [CurseForge API application form](https://forms.monday.com/forms/dce5ccb7afda9a1c21dab1a1aa1d84eb?r=use1)
linked from [this support article](https://support.curseforge.com/support/solutions/articles/9000208346-about-the-curseforge-api-and-how-to-apply-for-a-key).
The form asks for contact details, a project description, links and expected API
use, and requires accepting the third-party API terms. Overwolf reviews the
impact on author earnings, CurseForge's servers and CDN, and author consent for
third-party distribution. The key is emailed to the developer after approval; it
is not instant and approval is not guaranteed.

For a Tolkara application, describe the on-device add-on manager for the iPad
WoW clients, that the key is user-supplied and stored in the device Keychain,
that there is no backend or redistribution of add-ons, and that the API is used
only for search, metadata, files and provider download URLs. Apply with the
project/repository links and your contact address. The key is private: never
commit it, put it in the app binary or share it. Enter it under **Add-ons menu →
CurseForge API key**; it is sent only to `api.curseforge.com`.

If you do not have an approved key, leave it empty: CurseForge results show their
source page and the package can be downloaded there and installed with **Import
ZIP**. Tukui and GitHub work without any key.

WoWUp does not provide a reusable key either. Its standard build ships with
CurseForge disabled (it uses Wago), while the CurseForge-enabled Overwolf build
injects its own approved key from a build secret; the repository's pre-commit
hook exists to stop that key from being committed. Its localisation still says
that a user who has requested a CurseForge API key can enter it. That is the
same model used here.

## Installed

The Installed tab scans top-level folders with a `.toc` and the ownership
manifest. A row offers:

- **Update** when a source reports a different version;
- **Check for update** for managed or TOC-identified packages;
- **Disable / Enable** by moving the package out of and into `AddOns`;
- **Remove**, which deletes only files the manager owns and keeps WTF settings.

Updates keep one previous copy under the app's Library. Installs, removals and
disable/enable operations share the updater's `update.lock`; if a game update is
committing, the manager refuses to touch the folder.

## Backups

The Backups tab creates a ZIP of the game's `WTF` folder: addon saved
variables, per-character settings and `Config.wtf`. Backups are stored in
`Documents/Add-On Backups` and can be shared, restored or deleted. Restoring
makes a safety backup of the current WTF first and replaces it; add-on files are
untouched. Close the game before restoring.

## Storage

- `Interface/AddOns/.wolkara-addons.json` — ownership manifest. It travels with
  `Interface` through game updates.
- `Library/Application Support/Wolkara/AddOns/Disabled/<package>` — disabled
  payloads.
- `Library/Application Support/Wolkara/AddOns/Previous/<package>` — the one
  retained previous install.
- `Library/Application Support/Wolkara/AddOns/Staging` — extraction staging.

Packages may contain nested `.toc` files for libraries inside an add-on (Questie
ships `Questie` and `QuestieDB` with nested `Libs`, for example). Only the
shallowest TOC level identifies the add-on folders; nested libraries are part
of their parent and are copied with it rather than becoming separate add-ons.

Every ZIP entry is checked for traversal, absolute paths, links/special files,
duplicate or case-colliding names, encryption and unsupported compression, with
bounded entry and expanded sizes. A bad package never writes outside staging or
the resolved add-on directory.

## Workarounds

The Workarounds tab manages local compatibility patches for installed add-ons.
Each entry names its target add-on and version, shows whether it is applied, and
can be turned off or reapplied. The enabled state is kept in the manager's
support directory, not in the add-on ownership manifest, so it survives add-on
updates and reinstallations. After an add-on install or update the manager
reapplies every enabled workaround that matches the new package; a workaround
whose patches no longer match is left unapplied and reported as incompatible.

The bundled Spoken 3.5.0 workarounds cover the Camelot/Forever client: the
welcome frame and settings pages avoid the Blizzard-only Settings UI, while the
sound workaround keeps the Dialog channel mute for Silence NPC Voices and skips
the protected volume and out-of-date CVar writes. They are version-gated to
3.5.x and are reapplied after a Spoken update.

## Limits

- CurseForge one-click downloads depend on an approved API key and the
  provider's distribution settings. A missing key is not an error.
- GitHub search is repository-based; it is intentionally broader and noisier
  than the curated providers. Search installs the repository's main component:
  the release whose tag prefix matches the repository name. Packages recorded
  with a component identity (`owner/repo#component`, such as a voice pack
  imported from a `quests-audio/...` release) are updated from that component's
  releases instead.
- Wago search is exact-name/slug or URL only. The full Wago search needs their
  API's short-lived ad token or a Wago access key; that integration is not
  present, so the public add-on page and Import ZIP are the supported paths.
- The Add-ons screen follows the selected installation. The custom-server
  settings remain Forever-beta-only.
- Pinning and selecting a specific historical release are not exposed yet.
- Publisher compatibility declarations are shown, not guaranteed gameplay
  compatibility. Test an add-on on the iPad before relying on it.

## Code and tests

- `launcher/WoW/AddOns/AddOnsViewController.*` — Discover, Installed, Backups,
  import, provider settings.
- `AddOnsManager.*` — manifest, scan, install/update/disable/remove, lock,
  WTF backup/restore.
- `AddOnsSources.*` — Tukui, GitHub, CurseForge, Wago public pages and
  Keychain settings.
- `AddOnsZip.*`, `AddOnsTOC.*`, `AddOnsModel.*` — bounded archive handling,
  TOC metadata and models.
- `tests/test_addons.m` exercises TOC parsing, ZIP round-trips, install,
  update/previous, disable/enable, import, backup/restore and remove, including
  a Questie-style package with nested library TOCs and `QuestieDB`, multi-flavor
  Interface display, stale top-level folders left by an update, and the workaround
  engine's apply/status/revert path.
- `tests/test_wago_source.m` exercises the Wago public-page parser, flavor and
  patch matching and the signed download link extraction.
- `tests/test_github_source.m` exercises GitHub release selection when a
  repository publishes a main add-on and separately versioned data packs.
- `tools/test_addons_ui.sh` runs a simulator fixture for the Add-ons loading
  state after a background refresh and across tab switches.
