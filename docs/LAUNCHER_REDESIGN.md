# Launcher redesign

This branch rebuilds the public launcher around a game-first shell: a small set
of persistent destinations, one clear primary action, and settings that are
reachable without hunting through an action sheet. Lightforge's Battle.net
replacement is the reference for the information architecture and the visual
restraint, not a source of code.

The existing engine stays: editions, the on-device updater, custom-server
patching, the add-on manager, diagnostics, execution modes and the app library
are not being reimplemented in this phase.

## Goals

- Put **Play** at the centre: edition, installation state, version and the one
  action that matters, always visible.
- Give **Add-ons**, **Library** and **Settings** their own real destinations.
- Make **custom servers**, **touch controls** and **diagnostics** first-class
  settings instead of hidden action-sheet entries.
- Keep every existing launch argument and accessibility identifier working.
- Leave room for a download queue and a resumable update state machine without
  moving the updater again later.

## Information architecture

```
Tolkara
├── Play                 WoW home, edition, status, install/update/play
├── Add-ons              Discover / Installed / Workarounds / Backups
├── Library              Imported apps, execution mode, diagnostics
└── Settings
    ├── Game             edition, region/language, installation summary
    ├── Installation     update, verify/repair, remove edition/all data
    ├── Startup          execution mode, touch controls, custom server
    ├── Diagnostics      diagnostics & logs, native log, host report
    └── Advanced         app library, about and open-source licenses
```

The root is a `UITabBarController` with one navigation controller per tab.
On iPad the system tab bar floats and the Play page uses its wide layout; on
iPhone the same tabs collapse to the bottom bar. Selecting Library or Settings
does not disturb a running download or a prepared game.

## Play

- Hero: wordmark, edition capsule, region/language capsule, status pill.
- Action card: state title, detail, progress, primary button
  (`Install`, `Update`, `Repair`, `Play`), and the startup note.
- Quick actions: Add-ons, Verify files, Custom server (Forever only),
  Settings.
- Version line: installed / available / last checked.
- Startup failure keeps the inline status and exposes Diagnostics.

Accessibility identifiers remain `wow.title`, `wow.primary`, `wow.status`,
`wow.detail`, `wow.version`, `wow.progress`, `wow.scroll`, `wow.edition`,
`wow.preferences`, `wow.addons`, `wow.startup`, `wow.updates` and
`wow.diagnostics`, so the existing synthetic UI fixture keeps testing the
install/update state machine.

## Settings

The old `Settings` action sheet becomes a grouped table:

- **Game**: edition, download region and language. Changing either refreshes
  the update plan.
- **Installation**: installed version, selected edition path, check for
  updates, verify and repair, remove edition files, remove all game data.
  Destructive rows confirm first and are disabled while an update or a game
  session is running.
- **Startup**: execution mode, touch controls, custom server. Custom server is
  shown only for the Forever beta product. It opens a real form (enable,
  portal, Ed25519 key, certificate group) instead of a stack of alert text
  fields.
- **Diagnostics**: the existing `TKDiagnosticsViewController` sections, plus a
  shortcut to the native guest log.
- **Advanced**: the app library and the licence text.

Settings observes a `TKWoWStateDidChangeNotification` from the Play controller
and reloads values when an update, repair or edition change finishes.

## Design system

`launcher/UI/LauncherTheme` holds the tokens; screens do not invent colours.

- Background `#0B0D10`, surface `#14171C`, raised `#1B2027`.
- Text `#E8EDF2`, muted `#8A94A3`.
- Gold is the Play/brand accent; blue is install/update; red is destructive.
- Spacing 4 / 8 / 16 / 24 / 32; cards use a 16 pt radius and a hairline border.
- The primary control is 56 pt tall; machine text (versions, paths, keys) is
  monospaced.

## Install and update structure

Phase 1, in this branch, keeps `TKWoWClient` and `TKWoWUpdater` and extracts the
state the UI needs into explicit properties (`busy`, `updating`, `installation`,
`error`) plus a change notification. Settings can trigger and observe the same
operations as Play.

Later phases, once the shell is stable:

1. Move the plan/update lifecycle into a `TKWoWUpdateCoordinator` owned by the
   scene, so an update continues when the Play tab is not visible.
2. Add a persistent queue and a tab-bar/status accessory for active downloads.
3. Add a resumable installation record (plan revision, staged files, bytes
   verified) so relaunching the app resumes instead of re-planning.
4. Add a preflight for free space and a verification report before Play is
   enabled.

## Migration

1. Theme, tab shell, Settings, Add-ons tab, Library tab (this change).
2. Restyle Play into the hero/action-card layout; keep identifiers.
3. Move custom-server and touch-controls forms out of alerts (this change
   starts with dedicated controllers).
4. Update coordinator and download queue.
5. Extend `tests/test_wow_launcher_app.m` and add a shell fixture that checks
   tab switching, settings persistence and the add-ons empty state.

## Non-goals

- No new network service and no Battle.net authentication.
- No bundled Blizzard artwork; the launcher uses the existing wordmark and
  system imagery.
- No change to the runtime, the updater protocol or the custom-server memory
  patcher.
