#pragma once
// Standalone Spaces feasibility probe. No Lua/Hammerspoon dependency.
// Private API declarations and masks follow Hammerspoon 1.1.1's MIT-licensed
// extensions/spaces/private.h and libspaces.m; see THIRD_PARTY_NOTICES.md.
#import <Cocoa/Cocoa.h>
#import <CoreGraphics/CoreGraphics.h>
#include <dlfcn.h>
#include <errno.h>
#include <limits.h>

typedef int (*MainConnectionFn)(void);
typedef CFArrayRef (*ManagedDisplaysFn)(int);
typedef uint64_t (*ActiveSpaceFn)(int);
typedef int (*SpaceTypeFn)(int, uint64_t);
typedef CFArrayRef (*WindowSpacesFn)(int, int, CFArrayRef);
typedef CFArrayRef (*SpaceWindowsFn)(int, uint32_t, CFArrayRef, uint32_t, uint64_t *, uint64_t *);
typedef void (*MoveWindowsFn)(int, CFArrayRef, uint64_t);

static int connection;
static ManagedDisplaysFn managedDisplays;
static ActiveSpaceFn activeSpace;
static SpaceTypeFn spaceType;
static WindowSpacesFn windowSpaces;
static SpaceWindowsFn spaceWindows;
static NSString *failure;
static void *skyLightHandle;

static int emit(NSDictionary *value, int status) {
    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:value options:NSJSONWritingSortedKeys error:&error];
    if (!data) { fprintf(stderr, "could-not-encode-json\n"); return 70; }
    fwrite(data.bytes, 1, data.length, stdout);
    fputc('\n', stdout);
    fflush(stdout);
    return status;
}

static int reject(NSString *reason, int status) {
    return emit(@{@"schemaVersion": @1, @"ok": @NO, @"reason": reason}, status);
}

static BOOL readID(const char *text, uint64_t maximum, uint64_t *value) {
    if (!text || !*text) return NO;
    for (const char *p = text; *p; p++) if (*p < '0' || *p > '9') return NO;
    errno = 0;
    char *end = NULL;
    unsigned long long parsed = strtoull(text, &end, 10);
    if (errno || *end || !parsed || parsed > maximum) return NO;
    *value = parsed;
    return YES;
}

static BOOL loadAPI(void) {
    void *handle = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY | RTLD_LOCAL);
    if (!handle) { failure = @"skylight-unavailable"; return NO; }
    skyLightHandle = handle;
    MainConnectionFn mainConnection = (MainConnectionFn)dlsym(handle, "SLSMainConnectionID");
    managedDisplays = (ManagedDisplaysFn)dlsym(handle, "SLSCopyManagedDisplaySpaces");
    activeSpace = (ActiveSpaceFn)dlsym(handle, "SLSGetActiveSpace");
    spaceType = (SpaceTypeFn)dlsym(handle, "SLSSpaceGetType");
    windowSpaces = (WindowSpacesFn)dlsym(handle, "SLSCopySpacesForWindows");
    spaceWindows = (SpaceWindowsFn)dlsym(handle, "SLSCopyWindowsWithOptionsAndTags");
    if (!mainConnection || !managedDisplays || !activeSpace || !spaceType || !windowSpaces || !spaceWindows) {
        failure = @"required-symbol-unavailable"; return NO;
    }
    connection = mainConnection();
    return YES;
}

static NSArray *numericStrings(NSArray *values) {
    if (![values isKindOfClass:NSArray.class]) { failure = @"invalid-id-array"; return nil; }
    NSMutableArray *result = [NSMutableArray array];
    for (id value in values) {
        if (![value isKindOfClass:NSNumber.class] || [value unsignedLongLongValue] == 0) {
            failure = @"invalid-id-value"; return nil;
        }
        [result addObject:[value stringValue]];
    }
    return result;
}

static NSArray *spacesForWindow(uint32_t wid) {
    NSArray *ids = @[@(wid)];
    CFArrayRef raw = windowSpaces(connection, 0x7, (__bridge CFArrayRef)ids);
    if (!raw) { failure = @"window-spaces-unavailable"; return nil; }
    return numericStrings(CFBridgingRelease(raw));
}

static NSArray *windowsForSpace(uint64_t sid) {
    NSArray *ids = @[@(sid)];
    uint64_t setTags = 0, clearTags = 0;
    CFArrayRef raw = spaceWindows(connection, 0, (__bridge CFArrayRef)ids, 0x7, &setTags, &clearTags);
    if (!raw) { failure = @"space-windows-unavailable"; return nil; }
    return numericStrings(CFBridgingRelease(raw));
}

static NSString *kindForType(int type) {
    if (type == 0) return @"user";
    if (type == 4) return @"fullscreen";
    return @"unknown";
}

static NSDictionary *snapshot(void) {
    uint64_t before = activeSpace(connection);
    CFArrayRef raw = managedDisplays(connection);
    if (!raw) { failure = @"display-spaces-unavailable"; return nil; }
    NSArray *displays = CFBridgingRelease(raw);
    if (![displays isKindOfClass:NSArray.class] || !displays.count || !before) {
        failure = @"invalid-display-spaces"; return nil;
    }
    NSMutableArray *result = [NSMutableArray array];
    for (NSDictionary *display in displays) {
        if (![display isKindOfClass:NSDictionary.class]) { failure = @"invalid-display"; return nil; }
        NSString *identifier = display[@"Display Identifier"];
        NSArray *spaces = display[@"Spaces"];
        NSDictionary *current = display[@"Current Space"];
        NSNumber *currentID = [current isKindOfClass:NSDictionary.class] ? current[@"ManagedSpaceID"] : nil;
        if (![identifier isKindOfClass:NSString.class] || ![spaces isKindOfClass:NSArray.class]
            || ![currentID isKindOfClass:NSNumber.class]) { failure = @"invalid-display-shape"; return nil; }
        NSMutableArray *ordered = [NSMutableArray array];
        for (NSDictionary *space in spaces) {
            NSNumber *sid = [space isKindOfClass:NSDictionary.class] ? space[@"ManagedSpaceID"] : nil;
            if (![sid isKindOfClass:NSNumber.class] || !sid.unsignedLongLongValue) {
                failure = @"invalid-space-id"; return nil;
            }
            int type = spaceType(connection, sid.unsignedLongLongValue);
            NSArray *windows = windowsForSpace(sid.unsignedLongLongValue);
            if (!windows) return nil;
            [ordered addObject:@{@"id": sid.stringValue, @"type": kindForType(type),
                @"typeCode": @(type), @"windowIDs": windows}];
        }
        [result addObject:@{@"display": identifier, @"activeSpaceID": currentID.stringValue, @"spaces": ordered}];
    }
    uint64_t after = activeSpace(connection);
    if (before != after) { failure = @"active-space-changed"; return nil; }
    return @{@"schemaVersion": @1, @"ok": @YES, @"command": @"snapshot",
        @"osVersion": NSProcessInfo.processInfo.operatingSystemVersionString,
        @"focusedSpaceID": @(after).stringValue, @"displays": result};
}

