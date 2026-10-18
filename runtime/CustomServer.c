#include "CustomServer.h"
#include <arpa/inet.h>
#include <errno.h>
#include <mach/mach.h>
#include <netdb.h>
#include <netinet/in.h>
#include <pthread.h>
#include <pthread/qos.h>
#include <stdatomic.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <sys/socket.h>
#include <time.h>
#include <unistd.h>

// The client's NetClient::CertStore keeps 12 trusted server keys. Each entry
// is a 4-byte group number, a 32-byte Ed25519 public key, one flag byte and
// three bytes of padding (7f 00 00); the 12 entries are 40 bytes apart. A
// second copy in the same store may be laid out differently, so the scanner
// also replaces a group key found near any other known key.
#define CS_KEYS 12
#define CS_KEY_BYTES 32
#define CS_ENTRY_BYTES 40
#define CS_STORE_BYTES (CS_ENTRY_BYTES * CS_KEYS)
#define CS_PAGE 4096
#define CS_CHUNK (4u * 1024u * 1024u)
#define CS_NEAR (16u * 1024u)
// A sparse reservation can be enormous. The certificate store lives in a
// normal heap allocation; do not walk multi-gigabyte reservations looking for
// it, and keep one pass bounded.
#define CS_REGION_LIMIT (1ull * 1024u * 1024u * 1024u)
#define CS_SCAN_BUDGET (2ull * 1024u * 1024u * 1024u)
#define CS_PATCH_LIMIT 64
#define CS_ACTIVITY_MS 30000
#define CS_MAX_PORTAL_ADDRESSES 8

static const uint8_t kKnownKeys[CS_KEYS][CS_KEY_BYTES] = {
    {0x9B,0x06,0x71,0xC8,0x15,0xDF,0xF5,0x13,0xBF,0xD4,0xA2,0xB2,0x6A,0xE1,0xF8,0x4E,
     0xC9,0x10,0x68,0x41,0xB2,0xFB,0x62,0x0D,0xB6,0x5F,0x6A,0xDE,0x7C,0x21,0xAD,0x06},
    {0x11,0x24,0x51,0xB9,0x84,0x3C,0x27,0x99,0xE4,0x75,0x0A,0xA3,0xD9,0xB9,0xAF,0xAB,
     0xF5,0x36,0xA6,0x45,0xB8,0x63,0xC4,0xAD,0xB2,0x07,0x8B,0x93,0x2B,0x35,0x4E,0x04},
    {0xA6,0xB8,0x58,0x48,0x57,0x48,0xBF,0x38,0xBE,0x19,0x35,0x17,0xAB,0x90,0xF8,0xDE,
     0x16,0x9E,0xFF,0x09,0x89,0xEA,0x93,0x60,0xDB,0x34,0x6A,0x37,0x8B,0x0F,0xFE,0x15},
    {0x50,0xFF,0xDE,0xB8,0x07,0xF8,0xFF,0x73,0xA2,0x99,0xA1,0x60,0x00,0xAA,0x65,0x75,
     0xC5,0x94,0x5B,0xE8,0x75,0xAD,0xFC,0x87,0x95,0x37,0x4E,0xD3,0x41,0x52,0x49,0xAC},
    {0x9F,0x84,0x2D,0x07,0x87,0x55,0x64,0x7C,0x00,0x8E,0x5F,0xE3,0xE1,0x2B,0x83,0x9A,
     0x98,0x1D,0xE0,0x2A,0x1F,0x52,0x0C,0xB2,0x54,0x5C,0xC0,0x4C,0xD2,0x32,0x3E,0x0E},
    {0xB8,0xCC,0x75,0x86,0x4D,0x8E,0xF4,0x61,0xD8,0xDD,0x6A,0xA7,0x42,0x5E,0x2C,0x63,
     0xC2,0x4D,0x39,0x82,0x06,0x6B,0x8D,0x77,0x3A,0x15,0x49,0xBF,0xE2,0x4E,0x05,0xEE},
    {0x76,0xBB,0x7B,0xBD,0xD9,0xF3,0x4E,0x12,0x4A,0x45,0x73,0xC3,0xAA,0x22,0x7E,0x3C,
     0x87,0xCC,0x60,0x35,0x06,0x69,0x7D,0x05,0x4F,0x6F,0xDE,0xC3,0x42,0xE5,0x6E,0xBF},
    {0x1F,0xD6,0xDD,0x8F,0xA0,0xEC,0x30,0xD3,0x9E,0x3F,0x72,0xE7,0x55,0xB8,0xA0,0x45,
     0xBD,0xE0,0xF7,0x04,0x49,0xDC,0x71,0x00,0x8B,0x76,0x7C,0x2E,0xAA,0x89,0xFB,0x9F},
    {0x15,0xD6,0x18,0xBD,0x7D,0xB5,0x77,0xBD,0x9A,0x8D,0x45,0x76,0x9C,0x59,0xE4,0xFC,
     0x63,0x16,0x33,0xBF,0x44,0x73,0x98,0xA4,0xB4,0x89,0xB4,0xC2,0x6F,0xBC,0x03,0xAD},
    {0xB3,0x4E,0xC5,0x92,0xD2,0xAC,0x49,0x93,0xF5,0xFF,0xC8,0x5B,0x15,0xC3,0xDA,0x90,
     0x78,0x69,0x40,0x51,0xCB,0x22,0x43,0x45,0x59,0x2A,0xF7,0x13,0x6D,0x79,0x6C,0x99},
    {0x9E,0x91,0x58,0x6D,0xD4,0xB1,0x15,0xAB,0x05,0x68,0xB2,0x19,0x59,0xE1,0x81,0xF6,
     0x54,0x59,0x10,0xBC,0x5E,0x2F,0x30,0xB8,0x97,0x5C,0xA0,0x9D,0x7B,0xC3,0xEF,0xCE},
    {0x76,0x9C,0x82,0x4A,0x1D,0xAD,0xD1,0x9A,0xEE,0xFA,0x42,0x04,0x14,0xD1,0x73,0x2D,
     0xAF,0x44,0x53,0x7F,0x98,0xAA,0x22,0x9F,0xC5,0x47,0x7B,0xCA,0x55,0xF9,0xD5,0x9A},
};
static const uint8_t kFlags[CS_KEYS] = {1,1,1,1,1,1,1,1,0,1,1,1};

static uint8_t sServerKey[CS_KEY_BYTES];
static unsigned sGroup = 8;
static bool sConfigured;
static char sPortalHost[256];
static struct sockaddr_storage sPortalAddresses[CS_MAX_PORTAL_ADDRESSES];
static size_t sPortalAddressCount;
static atomic_uint_fast64_t sActivityUntil;
static atomic_bool sResolved;
static atomic_bool sStop;
static uint64_t sStarted;
static pthread_once_t sOnce = PTHREAD_ONCE_INIT;

typedef struct {
    uintptr_t address;
} Patch;
static Patch sPatches[CS_PATCH_LIMIT];
static size_t sPatchCount;
static bool sPatchLimitReported;
#ifdef CS_TEST
static uintptr_t sIgnoreFrom, sIgnoreTo;
#endif
static unsigned long long sScannedBytes;
static unsigned long long sAnchorHits;
static unsigned long long sTargetHits;
static uint64_t sLastLog;

static uint64_t cs_now_ms(void) {
    struct timespec ts;
    if (clock_gettime(CLOCK_MONOTONIC,&ts)) return 0;
    return (uint64_t)ts.tv_sec*1000 + (uint64_t)ts.tv_nsec/1000000;
}

static void cs_sleep_ms(unsigned ms) {
    struct timespec ts={(time_t)(ms/1000),(long)(ms%1000)*1000000};
    while (nanosleep(&ts,&ts) && errno==EINTR) {}
}

static void cs_log(const char *format, ...) __attribute__((format(printf,1,2)));
static void cs_log(const char *format, ...) {
    va_list arguments;
    va_start(arguments,format);
    fputs("[custom-server] ",stderr);
    vfprintf(stderr,format,arguments);
    fputc('\n',stderr);
    fflush(stderr);
    va_end(arguments);
}

static bool cs_read(uintptr_t address, void *buffer, size_t size) {
    vm_size_t read = 0;
    kern_return_t status = vm_read_overwrite(mach_task_self(), (vm_address_t)address,
        (vm_size_t)size, (vm_address_t)(uintptr_t)buffer, &read);
    return status == KERN_SUCCESS && read == size;
}

static bool cs_write(uintptr_t address, const uint8_t *bytes, size_t size) {
    return vm_write(mach_task_self(), (vm_address_t)address,
        (vm_offset_t)(uintptr_t)bytes, (mach_msg_type_number_t)size) == KERN_SUCCESS;
}

static int cs_hex_digit(char c) {
    if (c>='0' && c<='9') return c-'0';
    if (c>='a' && c<='f') return c-'a'+10;
    if (c>='A' && c<='F') return c-'A'+10;
    return -1;
}

static void cs_portal_host(const char *portal, char *host, size_t size) {
    if (!portal || !size) return;
    size_t n = strlen(portal);
    if (n >= size) n = size - 1;
    memcpy(host,portal,n); host[n]=0;
    char *scheme = strstr(host,"://");
    if (scheme) memmove(host,scheme+3,strlen(scheme+3)+1);
    char *slash = strchr(host,'/');
    if (slash && slash!=host) *slash=0;
    if (host[0]=='[') {
        char *close = strchr(host,']');
        if (close) close[1]=0;
        return;
    }
    char *colon = strrchr(host,':');
    if (colon && !strchr(colon+1,':')) *colon=0;
}

bool cs_configure(const char *key_hex, unsigned group, const char *portal) {
    if (!key_hex || strlen(key_hex)!=CS_KEY_BYTES*2 || group<1 || group>CS_KEYS) return false;
    for (size_t i=0;i<CS_KEY_BYTES;i++) {
        int high = cs_hex_digit(key_hex[i*2]), low = cs_hex_digit(key_hex[i*2+1]);
        if (high<0 || low<0) return false;
        sServerKey[i]=(uint8_t)(high<<4|low);
    }
    sGroup = group;
    sPortalHost[0]=0;
    if (portal && portal[0]) cs_portal_host(portal,sPortalHost,sizeof sPortalHost);
    sConfigured = true;
    return true;
}

static void cs_activity(void) {
    if (!sConfigured) return;
    uint64_t until = cs_now_ms() + CS_ACTIVITY_MS;
    uint64_t previous = atomic_load(&sActivityUntil);
    while (until > previous && !atomic_compare_exchange_weak(&sActivityUntil,&previous,until)) {}
}

void cs_note_host(const char *host) {
    if (!sConfigured) return;
    if (cs_now_ms()>sStarted+8000) { cs_activity(); return; }
    if (!host || !sPortalHost[0]) return;
    size_t n = strlen(host);
    while (n && host[n-1]=='.') n--;
    if (n == strlen(sPortalHost) && !strncasecmp(host,sPortalHost,n)) cs_activity();
}

static bool cs_same_address(const struct sockaddr *address) {
    if (!address) return false;
    for (size_t i=0;i<sPortalAddressCount;i++) {
        const struct sockaddr *known=(const struct sockaddr *)&sPortalAddresses[i];
        if (known->sa_family!=address->sa_family) continue;
        if (address->sa_family==AF_INET) {
            const struct sockaddr_in *a=(const struct sockaddr_in *)address;
            const struct sockaddr_in *b=(const struct sockaddr_in *)known;
            if (a->sin_addr.s_addr==b->sin_addr.s_addr) return true;
        } else if (address->sa_family==AF_INET6) {
            const struct sockaddr_in6 *a=(const struct sockaddr_in6 *)address;
            const struct sockaddr_in6 *b=(const struct sockaddr_in6 *)known;
            if (!memcmp(&a->sin6_addr,&b->sin6_addr,sizeof a->sin6_addr)) return true;
        }
    }
    return false;
}

void cs_note_connect(const void *sockaddr) {
    if (!sConfigured) return;
    // Startup talks to the CDN before the login screen. After that, any new
    // connection can be the auth attempt, so watch quickly around it whether
    // or not the game resolved the portal through us.
    if (cs_same_address((const struct sockaddr *)sockaddr) || cs_now_ms()>sStarted+8000) cs_activity();
}

static void cs_resolve_portal(void) {
    if (!sPortalHost[0] || atomic_load(&sResolved)) return;
    atomic_store(&sResolved,true);
    struct addrinfo hints = {0};
    hints.ai_family = AF_UNSPEC;
    hints.ai_socktype = SOCK_STREAM;
    struct addrinfo *result = NULL;
    if (getaddrinfo(sPortalHost,NULL,&hints,&result)) return;
    for (struct addrinfo *entry=result; entry && sPortalAddressCount<CS_MAX_PORTAL_ADDRESSES; entry=entry->ai_next) {
        if (entry->ai_addrlen>sizeof sPortalAddresses[0]) continue;
        memcpy(&sPortalAddresses[sPortalAddressCount],entry->ai_addr,entry->ai_addrlen);
        sPortalAddressCount++;
    }
    freeaddrinfo(result);
}

// Never patch the scanner's own tables. A writable copy of either array
// would otherwise look like one more key copy.
static bool cs_own_data(uintptr_t address) {
    uintptr_t known=(uintptr_t)kKnownKeys, known_end=known+sizeof kKnownKeys;
    uintptr_t server=(uintptr_t)sServerKey, server_end=server+sizeof sServerKey;
    if ((address>=known && address<known_end) || (address>=server && address<server_end)) return true;
#ifdef CS_TEST
    if (address>=sIgnoreFrom && address<sIgnoreTo) return true;
#endif
    return false;
}

static bool cs_track(uintptr_t address) {
    for (size_t i=0;i<sPatchCount;i++) if (sPatches[i].address==address) return true;
    if (sPatchCount>=CS_PATCH_LIMIT) {
        if (!sPatchLimitReported) { sPatchLimitReported=true; cs_log("more key copies than the tracker holds; further copies are not rechecked"); }
        return false;
    }
    sPatches[sPatchCount++].address=address;
    return true;
}

static bool cs_patch_at(uintptr_t address) {
    if (cs_own_data(address)) return false;
    uint8_t current[CS_KEY_BYTES];
    if (!cs_read(address,current,sizeof current)) return false;
    if (!memcmp(current,sServerKey,sizeof current)) { cs_track(address); return true; }
    const uint8_t *original = kKnownKeys[sGroup-1];
    if (memcmp(current,original,sizeof current)) return false;
    if (!cs_write(address,sServerKey,sizeof sServerKey)) return false;
    uint8_t check[CS_KEY_BYTES];
    if (!cs_read(address,check,sizeof check) || memcmp(check,sServerKey,sizeof check)) return false;
    cs_track(address);
    cs_log("group %u key installed at 0x%llx",sGroup,(unsigned long long)address);
    return true;
}

// The store's group numbers alone identify the contiguous layout even when a
// client build changes the keys themselves: 1..12 at 40-byte strides.
static bool cs_layout_bytes(const uint8_t *raw, size_t length) {
    if (length<CS_STORE_BYTES) return false;
    for (size_t entry=0;entry<CS_KEYS;entry++) {
        uint32_t group;
        memcpy(&group,raw+entry*CS_ENTRY_BYTES,sizeof group);
        if (group!=(uint32_t)entry+1) return false;
    }
    return true;
}

static bool cs_layout_at(uintptr_t base) {
    if (base&3) return false;
    uint8_t raw[CS_STORE_BYTES];
    if (!cs_read(base,raw,sizeof raw)) return false;
    return cs_layout_bytes(raw,sizeof raw);
}

// Replace the configured group's key in a layout-validated store. Unlike the
// known-key path, this does not require the client's key to be one we know.
static void cs_patch_layout(uintptr_t base) {
    uintptr_t key=base+(sGroup-1)*CS_ENTRY_BYTES+4;
    if (cs_own_data(key)) return;
    uint8_t current[CS_KEY_BYTES];
    if (!cs_read(key,current,sizeof current)) return;
    if (!memcmp(current,sServerKey,sizeof current)) { cs_track(key); return; }
    if (!cs_write(key,sServerKey,sizeof sServerKey)) return;
    uint8_t check[CS_KEY_BYTES];
    if (!cs_read(key,check,sizeof check) || memcmp(check,sServerKey,sizeof check)) return;
    cs_track(key);
    cs_log("group %u key installed at 0x%llx (certificate store layout)",sGroup,(unsigned long long)key);
}

// The contiguous layout: 12 entries, each group number, key, flag and tail.
// Returns -1 when the bytes are not that store, 0 original, 1 patched.
// Windows stores 7f 00 00 after the flag; the same client under Wine/Proton
// zeroes it, and a macOS build may do either.
static bool cs_tail_ok(const uint8_t *tail) {
    return (tail[0]==0x7f || tail[0]==0x00) && tail[1]==0x00 && tail[2]==0x00;
}

static int cs_store_state(uintptr_t array) {
    uint8_t raw[CS_STORE_BYTES];
    if (!cs_read(array,raw,sizeof raw)) return -1;
    for (size_t entry=0;entry<CS_KEYS;entry++) {
        const uint8_t *base=raw+entry*CS_ENTRY_BYTES;
        uint32_t group;
        memcpy(&group,base,sizeof group);
        if (group!=(uint32_t)entry+1) return -1;
        const uint8_t *key=base+4;
        bool known=!memcmp(key,kKnownKeys[entry],CS_KEY_BYTES);
        if (entry+1==sGroup && !known) known=!memcmp(key,sServerKey,CS_KEY_BYTES);
        if (!known) return -1;
        if (base[36]!=kFlags[entry] || !cs_tail_ok(base+37)) return -1;
    }
    return memcmp(raw+(sGroup-1)*CS_ENTRY_BYTES+4,sServerKey,CS_KEY_BYTES)?0:1;
}

static size_t cs_search(const uint8_t *haystack, size_t length, const uint8_t *needle) {
    if (length<CS_KEY_BYTES) return (size_t)-1;
    const uint8_t *hit=(const uint8_t *)memmem(haystack,length,needle,CS_KEY_BYTES);
    return hit?(size_t)(hit-haystack):(size_t)-1;
}

// A target key is only replaced when it belongs to a certificate store: its
// own entry validates, or one of the other known keys is close by.
static bool cs_target_entry_valid(uintptr_t key) {
    if (key>=4 && (key&3)==0) {
        uint32_t group=0;
        uint8_t tail[4];
        if (cs_read(key-4,&group,sizeof group) && group==sGroup &&
            cs_read(key+CS_KEY_BYTES,tail,sizeof tail) &&
            tail[0]==kFlags[sGroup-1] && cs_tail_ok(tail+1)) return true;
    }
    size_t size = CS_NEAR*2;
    uintptr_t start = key>CS_NEAR?key-CS_NEAR:0;
    uint8_t *window=(uint8_t *)malloc(size);
    if (!window) return false;
    bool valid=false;
    if (cs_read(start,window,size)) {
        for (size_t i=0;i<CS_KEYS && !valid;i++)
            valid = cs_search(window,size,kKnownKeys[i]) != (size_t)-1;
    }
    free(window);
    return valid;
}

// Replace every copy of the group key within the store around an anchor. The
// Windows/Linux clients use more than one layout, and this covers them. A copy
// that already holds the server key is only remembered, so a rescan after the
// client rebuilt the store does not forget it.
static void cs_patch_near(uintptr_t anchor) {
    const uint8_t *patterns[2];
    size_t count=0;
    patterns[count++]=kKnownKeys[sGroup-1];
    if (memcmp(kKnownKeys[sGroup-1],sServerKey,CS_KEY_BYTES)) patterns[count++]=sServerKey;
    size_t radius = CS_NEAR;
    for (int attempt=0; attempt<4 && radius>256; attempt++, radius/=2) {
        size_t size=radius*2;
        uintptr_t start=anchor>radius?anchor-radius:0;
        uint8_t *window=(uint8_t *)malloc(size);
        if (!window) return;
        bool read=cs_read(start,window,size);
        if (read) {
            for (size_t pattern=0; pattern<count; pattern++) {
                size_t position=0;
                while (position+CS_KEY_BYTES<=size) {
                    size_t found=cs_search(window+position,size-position,patterns[pattern]);
                    if (found==(size_t)-1) break;
                    position+=found;
                    uintptr_t address=start+position;
                    if ((address&3)==0) cs_patch_at(address);
                    position++;
                }
            }
            free(window);
            return;
        }
        free(window);
    }
}

static void cs_handle_anchor(uintptr_t key) {
    sAnchorHits++;
    if ((key&3)==0) {
        uintptr_t array=key-4;
        int state=cs_store_state(array);
        if (state>=0) {
            cs_patch_at(array+(sGroup-1)*CS_ENTRY_BYTES+4);
            cs_patch_near(key);
            return;
        }
    }
    cs_patch_near(key);
}

static void cs_handle_target(uintptr_t key) {
    sTargetHits++;
    if (!cs_target_entry_valid(key)) return;
    cs_patch_at(key);
}

static void cs_search_pattern(uintptr_t base, const uint8_t *buffer, size_t length,
                              const uint8_t *needle, bool anchor) {
    size_t position=0;
    while (position+CS_KEY_BYTES<=length) {
        size_t found=cs_search(buffer+position,length-position,needle);
        if (found==(size_t)-1) break;
        position+=found;
        if (anchor) cs_handle_anchor(base+position);
        else cs_handle_target(base+position);
        position++;
    }
}

static void cs_search_buffer(uintptr_t base, const uint8_t *buffer, size_t length) {
    // The group numbers find the store whatever its keys are; the known-key
    // paths then cover a store that is not one contiguous array.
    static const uint8_t one[4]={1,0,0,0};
    size_t position=0;
    while (position+sizeof one<=length) {
        const uint8_t *hit=(const uint8_t *)memmem(buffer+position,length-position,one,sizeof one);
        if (!hit) break;
        position=(size_t)(hit-buffer);
        uintptr_t address=base+position;
        if ((address&3)==0) {
            bool layout = position+CS_STORE_BYTES<=length ?
                cs_layout_bytes(buffer+position,length-position) : cs_layout_at(address);
            if (layout) cs_patch_layout(address);
        }
        position++;
    }
    cs_search_pattern(base,buffer,length,kKnownKeys[0],true);
    if (sGroup!=1) cs_search_pattern(base,buffer,length,kKnownKeys[sGroup-1],false);
    cs_search_pattern(base,buffer,length,sServerKey,false);
}

static void cs_scan_region(uintptr_t start, size_t size, uint8_t *buffer, size_t *budget) {
    size_t offset=0;
    while (offset<size && *budget) {
        size_t take=size-offset;
        if (take>CS_CHUNK) take=CS_CHUNK;
        if (take>*budget) take=*budget;
        vm_size_t got=0;
        kern_return_t status=vm_read_overwrite(mach_task_self(),(vm_address_t)(start+offset),
            (vm_size_t)take,(vm_address_t)(uintptr_t)buffer,&got);
        if (status!=KERN_SUCCESS || got==0) {
            if (take>CS_PAGE) take=CS_PAGE;
            else { offset+=CS_PAGE; continue; }
            status=vm_read_overwrite(mach_task_self(),(vm_address_t)(start+offset),
                (vm_size_t)take,(vm_address_t)(uintptr_t)buffer,&got);
            if (status!=KERN_SUCCESS || got==0) { offset+=CS_PAGE; continue; }
        }
        sScannedBytes+=got;
        *budget-=got<*budget?got:*budget;
        cs_search_buffer(start+offset,buffer,got);
        size_t advance=got;
        if (advance>CS_KEY_BYTES-1) advance-=CS_KEY_BYTES-1;
        else advance=CS_PAGE;
        offset+=advance;
    }
}

typedef struct {
    uintptr_t start;
    size_t size;
} PSRegion;

#define CS_MAX_REGIONS 8192

static int cs_region_compare(const void *left, const void *right) {
    size_t a=((const PSRegion *)left)->size, b=((const PSRegion *)right)->size;
    return a<b?-1:(a>b?1:0);
}

static void cs_scan_once(void) {
    uint8_t *buffer=(uint8_t *)malloc(CS_CHUNK);
    if (!buffer) return;
    PSRegion *regions=(PSRegion *)malloc(sizeof *regions * CS_MAX_REGIONS);
    if (!regions) { free(buffer); return; }
    size_t count=0;
    vm_address_t address=0;
    while (count<CS_MAX_REGIONS) {
        vm_size_t size=0;
        vm_region_basic_info_data_64_t info;
        mach_msg_type_number_t info_count=VM_REGION_BASIC_INFO_COUNT_64;
        mach_port_t object=MACH_PORT_NULL;
        kern_return_t status=vm_region_64(mach_task_self(),&address,&size,
            VM_REGION_BASIC_INFO_64,(vm_region_info_t)&info,&info_count,&object);
        if (status!=KERN_SUCCESS) break;
        if (object!=MACH_PORT_NULL) mach_port_deallocate(mach_task_self(),object);
        uintptr_t start=(uintptr_t)address;
        address=(vm_address_t)(start+(uintptr_t)size);
        if (!size) break;
        // Only writable, readable, private pages can hold the heap copy, and
        // executable pages belong to code or a JIT, not the certificate store.
        if ((info.protection&VM_PROT_READ)==0 || (info.protection&VM_PROT_WRITE)==0) continue;
        if (info.protection&VM_PROT_EXECUTE) continue;
        if (info.shared) continue;
        if ((uint64_t)size>CS_REGION_LIMIT) continue;
        regions[count++]=(PSRegion){start,(size_t)size};
    }
    static bool reported;
    if (!reported) { reported=true; cs_log("eligible regions %zu%s",count,count==CS_MAX_REGIONS?" (table full)":""); }
    // The store is a small allocation. Scan small regions first so a large
    // sparse heap reservation cannot use the whole budget before it.
    qsort(regions,count,sizeof *regions,cs_region_compare);
    size_t budget=CS_SCAN_BUDGET;
    for (size_t i=0;i<count && budget;i++)
        cs_scan_region(regions[i].start,regions[i].size,buffer,&budget);
    free(regions);
    free(buffer);
}

static void cs_verify(void) {
    size_t kept=0;
    for (size_t i=0;i<sPatchCount;i++) {
        uintptr_t address=sPatches[i].address;
        uint8_t current[CS_KEY_BYTES];
        if (!cs_read(address,current,sizeof current)) continue;
        if (memcmp(current,sServerKey,sizeof current)) {
            const uint8_t *original=kKnownKeys[sGroup-1];
            if (memcmp(current,original,sizeof current)) continue;
            if (!cs_write(address,sServerKey,sizeof sServerKey)) continue;
            cs_log("client restored the original key at 0x%llx; reinstalled",(unsigned long long)address);
        }
        sPatches[kept++].address=address;
    }
    sPatchCount=kept;
}

static void *cs_thread(void *context) {
    (void)context;
    pthread_set_qos_class_self_np(QOS_CLASS_UTILITY,0);
    cs_sleep_ms(2000);
    cs_resolve_portal();
    uint64_t started=cs_now_ms();
    uint64_t last_full_scan=started;
    unsigned scans=0;
    while (!atomic_load(&sStop)) {
        if (sPatchCount==0) {
            uint64_t before=cs_now_ms();
            cs_scan_once();
            scans++;
            uint64_t after=cs_now_ms();
            bool active = after < atomic_load(&sActivityUntil);
            if (sPatchCount==0 && (scans==1 || (scans%10==0 && after-sLastLog>=60000))) {
                cs_log("scanned %llu MB; %llu anchor hit(s), %llu key hit(s); waiting for the certificate store",
                    sScannedBytes>>20,sAnchorHits,sTargetHits);
                sLastLog=after;
            } else if (sPatchCount && sLastLog==0) {
                sLastLog=after;
            }
            unsigned delay=active?500:(after-started<30000?2000:10000);
            if (after-before>(uint64_t)delay) delay=500;
            cs_sleep_ms(delay);
        } else {
            cs_verify();
            // A reconnect can build a second store after the first one was
            // freed. The tracked addresses remain patched; look for new ones
            // once a minute without scanning the heap continuously.
            uint64_t now=cs_now_ms();
            if (now-last_full_scan>=60000) { cs_scan_once(); last_full_scan=now; }
            cs_sleep_ms(2000);
        }
    }
    return NULL;
}

static void cs_start_thread(void) {
    pthread_attr_t attributes;
    if (pthread_attr_init(&attributes)) return;
    pthread_attr_setdetachstate(&attributes,PTHREAD_CREATE_DETACHED);
    pthread_t thread;
    if (pthread_create(&thread,&attributes,cs_thread,NULL)) cs_log("could not start the watcher");
    pthread_attr_destroy(&attributes);
}

void cs_start(void) {
    if (!sConfigured) return;
    sStarted=cs_now_ms();
    cs_log("custom server mode: portal %s, certificate group %u",sPortalHost[0]?sPortalHost:"(default)",sGroup);
    pthread_once(&sOnce,cs_start_thread);
}

void cs_stop(void) {
    atomic_store(&sStop,true);
}

#ifdef CS_TEST
void cs_scan_range_for_test(void *start, size_t size) {
    if (!start || !size) return;
    uint8_t *buffer=(uint8_t *)malloc(CS_CHUNK);
    if (!buffer) return;
    size_t budget=(size_t)-1;
    cs_scan_region((uintptr_t)start,size,buffer,&budget);
    free(buffer);
}
void cs_reset_for_test(void) {
    sPatchCount=0;
    sScannedBytes=0;
    sAnchorHits=0;
    sTargetHits=0;
    sLastLog=0;
}
void cs_ignore_range_for_test(const void *start, size_t size) {
    sIgnoreFrom=(uintptr_t)start;
    sIgnoreTo=sIgnoreFrom+size;
}
#endif
