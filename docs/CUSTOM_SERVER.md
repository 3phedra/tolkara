# Custom server

This branch adds an opt-in custom-server mode for **World of Warcraft Forever
(Classic beta)**. It is a local fork feature; it is not part of upstream
Tolkara and does not change what Tolkara ships by default. It deliberately
performs an in-memory key replacement, which `AGENTS.md` excludes for ordinary
apps; this branch is the owner-requested exception, limited to this server.

A custom auth server is reached in two places:

1. **`WTF/Config.wtf`** — `SET portal "<auth host>"` selects the auth service.
2. **The client's trusted server keys** — the client's
   `NetClient::CertStore` holds Blizzard's 12 Ed25519 server keys in a heap
   object. The custom server signs its login certificate with its own key, so
   the certificate group the server uses has to hold that key.

The original Windows method (`patch_linux.sh`) finds the store in another
process with `/proc/<pid>/mem` and writes 32 bytes. On iPad there is no other
process to attach to: Tolkara runs the macOS client natively in its own
process, so the store is in Tolkara's address space. The runtime scans its own
writable heap (`vm_region_64` + `vm_read_overwrite`) and writes the key with
`vm_write`. No debugger, `task_for_pid`, executable patch or re-signing is
involved.

## Enable it

1. Install a normal Forever beta copy and start it once.
2. Open Tolkara, tap the gear, then **Custom server: off**.
3. Enter the server's auth host, its 64-digit Ed25519 key and the client
   certificate group (default 8). No portal or key is built in. Tap
   **Save and enable**.
4. Start the game and log in. The first attempt may reach the realm and fail;
   wait a moment and log in again without closing the game. This is the same
   retry the desktop patch needs.

The settings are stored in `Documents/CustomServer.plist`. The portal is
written to `Documents/World of Warcraft/_classic_beta_/WTF/Config.wtf` when the
game launches; the previous portal is kept in the plist and restored when the
mode is disabled. Graphics, account and addon settings are untouched. The
launcher also adds `agentUID`, `textLocale` and `audioLocale` only when they are
missing, matching the config the server's Android port creates.

## What the watcher looks for

The client's store has two observed shapes:

- a contiguous 12-entry array: a 4-byte group number, the 32-byte key, a flag
  and `7f 00 00`, all 40 bytes apart; and
- copies laid out differently around the same keys (the desktop logs showed
  the target group's key from about 1.2 KB to 12 KB from the group-1 key).

The watcher checks, in order:

1. 12 group numbers `1..12` at 40-byte strides. This finds the array even if a
   client build changes Blizzard's key values. The configured group is
   replaced.
2. The known group-1 key as an anchor; a valid 40-byte block is validated and
   the configured group replaced. Copies of that group's key within 16 KB of
   any known key are also replaced (the second layout).
3. A known group key index/flags/tail entry, or any configured-group key with
   another known key within 16 KB, as a last resort.

After the first write, every tracked address is reread every two seconds. If
the client restores Blizzard's key, it is written again. If the store was
freed, the address is dropped and the watcher searches again on the next
network activity.

The scanner starts before the client's `main`, scans every two seconds for the
first 30 seconds (then every ten while it waits), and scans twice a second
for 30 seconds around a DNS lookup or connection. Startup connects to the CDN;
by the time the login screen is reached, any new connection is treated as the
auth attempt. The portal hostname match is used when the client resolves it
through the host's resolver.

## Limits

- This is an integrity workaround for a specific custom server. It is not
  supported by Blizzard and can change or stop working with any client update.
- The server must accept the client's build. The desktop script was measured on
  1.60.1.69977/69913; this iPad branch runs the macOS builds (70338, 70374,
  70425 were tested as inputs). If the server rejects the version, no key
  replacement will help.
- If a future client keeps the keys and the store outside the scanned writable
  private pages, or encrypts them, the watcher will not find them. The log
  says so: `Documents/native-guest.log`, lines beginning `[custom-server]`.
- Only one guest startup is allowed per Tolkara process. Change the setting and
  reopen the game, not just the play screen.
- The server key is a public key, not a credential. Account credentials are
  never read, logged or written by this code.

## Code

- `runtime/CustomServer.c` — scanner, layouts, patch, reinstall and network
  trigger.
- `runtime/NativeGuest.m` — `ng_set_custom_server`, the `connect`/`connectx`/
  `getaddrinfo`/`gethostbyname` notifications and the watcher start before the
  guest's `main`.
- `launcher/App/CustomServerConfig.{h,m}` — settings and `Config.wtf` editing.
- `launcher/WoW/WoWViewController.m` — the **Custom server** settings sheet.
- `tests/test_custom_server.c` and `tests/test_custom_server_config.m` —
  layout, patch, false-positive and config tests.
