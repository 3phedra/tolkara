# Wolkara

**World of Warcraft on iPhone and iPad, built on [Tolkara](https://github.com/tolkara/tolkara).**

Wolkara is an independent, experimental fork focused on the WoW experience:
choose an edition, download its macOS client on the device, keep it updated,
and play with touch controls or a physical controller. The game runs locally
through Tolkara's compatibility layer; it is not streamed from a Mac.

Tolkara is a do-it-yourself developer project. You build it yourself
([docs/BUILDING.md](docs/BUILDING.md)) and bring your own legally obtained copy
of the macOS application; that is the way Tolkara is meant to be used. For
Developer service and Local signing you sign it with your own Apple developer
account. For External JIT you build it without a signing team
(`tools/package_ipa.sh`) and the tool you sideload it with signs it. As a convenience for External JIT only,
each [release](https://github.com/tolkara/tolkara/releases) also carries that
unsigned build, `Tolkara-unsigned.ipa`, made from the tagged source and holding
only Tolkara's own code; it is not the main way to get Tolkara. Releases also
carry Tolkara Management, a Mac app that does the self-build for you: it
builds Tolkara on your Mac and signs it with your own account
([docs/MANAGEMENT.md](docs/MANAGEMENT.md)). Nothing here is distributed through the App
Store, and the repository and releases contain no third-party application code
or assets.

This tree also carries the WoW launcher: a themed home that downloads and
updates the WoW Forever client from Blizzard's CDN on the iPad itself
([docs/WOW_LAUNCHER.md](docs/WOW_LAUNCHER.md)), merged from the Wolkara fork.

## Try it with Xcode

Tested on an iPad Pro (M5) with iPadOS 27. The first application validated end
to end, with Developer service, is World of Warcraft Classic (Classic Era macOS
client): login, world entry, movement, combat, quests, audio and intro
cinematics work, at up to 120 FPS on reduced resolution. With Local signing,
both WoW Classic clients (Classic Era and the Forever beta) log in and play,
with no debugger, helper or tunnel. Through a compatibility runtime, Wine with
FEX, the Windows game Heroes of Might and Magic III: Horn of the Abyss plays
with Developer service ([docs/WINDOWS.md](docs/WINDOWS.md)). See
[COMPATIBILITY.md](COMPATIBILITY.md) for details and known problems. Other
applications will need more API coverage; reports and patches are welcome.

iPhone support is experimental: on an iPhone 16 Pro Max with iOS 27, the WoW
Forever client logs in and plays with Developer service. Optional on-screen
keyboard and touch-trackpad controls, shown by default on iPhone, stand in for
a keyboard and mouse. See [docs/IPHONE.md](docs/IPHONE.md).

Notable limits today: with Developer service, preparing executable memory takes
time at every launch, about 3 MB per second (33 seconds for Heroes III), and
switching apps during startup can interrupt it. With Local signing, the page
container of an application that unpacks its own code, as both WoW clients do,
must be built from a capture of its final code pages, which Tolkara cannot
produce on its own yet; a program whose code is generated while it runs, such
as a Windows game under FEX, cannot use Local signing at all. External JIT has
not been run on a device yet.
Helper processes that an app launches separately
(for example a voice-chat helper) are not supported.

This is a source release for people comfortable with Xcode. There is no tested
public Wolkara IPA, App Store/TestFlight release or AltStore PAL install path.
A successful build alone does not prove that a signing profile permits startup.

## Features

- A single WoW home screen with edition, region and language selection.
- On-device installation and automatic update checks; required updates finish
  before Play becomes available.
- Resumable downloads, checksum verification and reuse of verified unchanged
  game data. Updates preserve settings and addons.
- An iOS keyboard with dictation and an editable draft that replaces the focused
  game field, plus a touch trackpad with two-finger scrolling.
- Physical controller support and an on-screen controller when none is connected.
- Movable touch controls, opacity and size settings, an alignment grid and haptics.

## What has been tested

The developer reports **60 FPS at graphics quality 4 on an iPhone 16 Pro Max**
playing WoW Forever (Classic beta). This is a gameplay report, not a benchmark
or a promise for every scene/device. Render scale was not specified in this
latest report; the earlier quality-2 session used 50% render scale.

| Module | Role |
| --- | --- |
| [`runtime/`](runtime) | Mach-O loader: maps the original image and the libraries it carries in its own bundle, applies dyld rebases and binds (including chained fixups), sets up TLS and Objective-C metadata, and enters the original initializers and `main`. For Local signing it validates the page container against the executable and maps its signed pages (`SignedImage`). Also a software MMU and a small interpreter used for testing. |
| [`translation/`](translation) | The macOS API layer: AppKit on UIKit, Metal device/shader-library adaptation, CoreAudio/AudioToolbox, Carbon keyboard, CoreGraphics displays, Security. One library per macOS framework; anything not hand-written gets a generated logging stub. |
| [`authorization/`](authorization) | Developer service. iPadOS only lets a development-signed app run code it did not sign after a debugger has prepared that memory. This module does that on the iPad itself: a bundled packet-tunnel extension reaches the device's own developer service, prepares the memory, and detaches before any application code runs. No Mac is needed after the one-time enrollment. |
| [`launcher/`](launcher) | The UIKit app: the app library, the execution-mode choice, starting apps, and a separate Diagnostics menu. |
| [`profiles/`](profiles) | Small data files that describe a tested application: its name and where its files live. No code. |
| [`management/`](management) | Tolkara Management, the Mac app that guides a user through building, installing and setting up an application ([docs/MANAGEMENT.md](docs/MANAGEMENT.md)). |

The updater has synthetic regression coverage, isolated Mac-copy tests and a
recorded device patch installations. Xcode logs also confirm that the latest
metadata-recovery fix completed an on-device update. A complete first download
into an empty iPhone installation still needs end-to-end validation. Follow the [fresh-install checklist](docs/FRESH_INSTALL_TEST.md)
and report the exact commit and client build you tried.

## Current limits

**The easy way:** download `Tolkara-Management.dmg` from the
[releases](https://github.com/tolkara/tolkara/releases). Tolkara Management
is a Mac app that checks every requirement step by step, builds Tolkara on
your Mac with your own Apple developer account, installs it on your iPad and
copies your game, such as World of Warcraft Forever. You still need a paid
Apple Developer Program membership, Xcode and your own copy of the game. See
[docs/MANAGEMENT.md](docs/MANAGEMENT.md).

**By hand:** you need a Mac with Xcode, [XcodeGen](https://github.com/yonaskolb/XcodeGen),
Python 3, an Apple developer account, and an iPad or an
[experimentally supported iPhone](docs/IPHONE.md) with Developer Mode enabled.
The full walkthrough, including signing and Developer Mode, is in
**[docs/BUILDING.md](docs/BUILDING.md)**. In short:

## Development

```bash
tools/test_emulation.sh
```

Focused updater tests: `tools/test_wow_launcher.sh`. UIKit fixtures:
`tools/test_wow_launcher_ui.sh` (set `SIMULATOR` to an available simulator).
Read [CONTRIBUTING.md](CONTRIBUTING.md) before contributing.

- [Launcher and updater](docs/WOW_LAUNCHER.md)
- [Touch input](docs/TOUCH_INPUT.md)
- [Touch controller](docs/TOUCH_CONTROLLER_PROPOSAL.md)
- [Engine architecture](docs/ARCHITECTURE.md)
- [Advanced Tolkara build and execution modes](docs/BUILDING.md)
- [Distribution research and unverified routes](docs/WOLKARA_DISTRIBUTION.md)

The shared engine, adapters and non-WoW test fixtures remain in this fork to
preserve upstream compatibility and regression coverage. Public Wolkara builds
use the WoW home; alternative loaders/modes are development tools.

## What Tolkara does to the application

So that you can judge this yourself rather than take our word for it:

- The original executable is imported as a file, verified by SHA-256, and mapped
  into memory. It is never edited, re-signed, or included in the app bundle. The
  loader applies the same rebases and binds dyld would; those are runtime state
  in memory, not changes to the file. With Local signing, a copy of its final
  code pages is signed with your identity in a separate page container that
  stays on your Mac and your iPad.
- The loader answers a short, fixed list of calls itself instead of passing them
  to iPadOS, because they concern how the image was loaded: `mmap`, `mprotect`,
  `munmap`, `memcpy`, `memmove`, `memset`, `__clear_cache` (for the separate
  read-write and executable views of code memory), `pthread_jit_write_protect_np`, `dladdr`,
  `dlsym`, `_NSGetExecutablePath`, `CFBundleGetMainBundle`, `_tlv_bootstrap`,
  `dyld_stub_binder`, `__ulock_wait` and `sigaction` (the last only when you
  opt into crash logging). The list is in
  [`runtime/NativeGuest.m`](runtime/NativeGuest.m).
- Everything else the application imports resolves to the real iPadOS framework,
  to a translation library in [`translation/`](translation), or to a library the
  application carries in its own bundle. An import that nothing provides
  becomes a stub that logs and returns zero: generated at build time for the
  executable of a build made for it, and made at launch in a generic build (made
  for no particular application) and for the libraries an application carries.
  In a build made for one application, an import of its executable that nothing
  provides at launch stops the launch instead.
- Nothing in Tolkara exists to hide the environment from the application. It does
  not conceal debuggers, processes, the device model or the operating system.
  With Developer service, the debugger used to prepare memory detaches before
  the first application instruction runs, and nothing attaches afterwards.
  With External JIT, Tolkara asks the enabler's debugger to detach and does not
  start the application while any debugger is attached. Local signing uses no
  debugger.

## Policy

Wolkara builds on Tolkara as a compatibility layer. This fork will not accept:

- reading or changing an application's memory for any purpose other than
  loading it, including "trainers", overlays, bots or input automation;
- workarounds for anti-cheat, licence or integrity checks;
- redistribution of third-party application code, assets or operating-system
  components in this repository or its releases. The updater obtains game
  content directly from the vendor for the user's installation.

## Online games

Wolkara is not approved or supported by Blizzard. Successful execution does not
establish publisher approval or guarantee the safety of an online account.
The project provides no anti-cheat, license or integrity-check workarounds.

## Legal

Wolkara and the upstream Tolkara code are released under the [MIT License](LICENSE).
No game files or Apple operating-system components are included. Third-party
adaptations and reference material are credited in [NOTICE.md](NOTICE.md).

Wolkara is an independent project and is not affiliated with, sponsored by or
endorsed by Apple Inc. or Blizzard Entertainment, Inc. macOS, iPadOS, iPad,
Metal and Xcode are trademarks of Apple Inc. World of Warcraft and Blizzard are
trademarks of Blizzard Entertainment, Inc. Other names are the property of their
owners and are used only to describe compatibility.

You are responsible for having the right to use any application you run with
Wolkara, and for complying with its licence.

Wolkara: [source and issues](https://github.com/fJavierLasso/wolkara).
Upstream engine: [Tolkara](https://github.com/tolkara/tolkara) · [tolkara.org](https://tolkara.org).
