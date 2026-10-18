#pragma once
#include <stdbool.h>
#include <stddef.h>
// Custom server support for the macOS WoW client that runs natively inside
// this process. The client keeps Blizzard's trusted server keys in a heap
// CertStore of 12 entries; a custom server signs its login certificate with
// its own key, so the client rejects it until the matching group is replaced.
// The client also reads its auth portal from WTF/Config.wtf.
//
// The launcher calls cs_configure before ng_initialize. The watcher then runs
// in this process: the guest's heap is our heap, so no debugger, ptrace or
// task_for_pid is involved. It never touches the executable or files beyond
// the config the launcher writes.
bool cs_configure(const char *key_hex, unsigned group, const char *portal);
// A DNS lookup or connect the guest performed. If it names the configured
// portal, the watcher scans continuously around the login attempt.
void cs_note_host(const char *host);
void cs_note_connect(const void *sockaddr);
// Start the watcher. Idempotent. Call once, after the guest's initializers and
// before its main runs. Stop it when the guest returns; a failure leaves the
// launcher process alive.
void cs_start(void);
void cs_stop(void);
#ifdef CS_TEST
// Regression tests: scan one already-readable range without starting the
// watcher. The whole-process scanner is the same code. Reset the tracked
// addresses so a test starts from the same state as a fresh process.
void cs_scan_range_for_test(void *start, size_t size);
void cs_reset_for_test(void);
// The test fixture's own copy of the key table must not be patched by the
// whole-process watcher.
void cs_ignore_range_for_test(const void *start, size_t size);
#endif
