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

static void pump(NSTimeInterval seconds) {
    NSDate *end = [NSDate dateWithTimeIntervalSinceNow:seconds];
    while (end.timeIntervalSinceNow > 0) {
        [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];
    }
}

// Intentionally cannot accept an existing window ID: only the NSWindow created
// in this function can reach the private move API.
static NSDictionary *probeMove(uint64_t source, uint64_t destination) {
    NSDictionary *start = snapshot();
    if (!start) return nil;
    NSString *from = @(source).stringValue, *to = @(destination).stringValue;
    if (![start[@"focusedSpaceID"] isEqual:from] || source == destination) {
        failure = @"source-space-not-current-or-target-identical"; return nil;
    }
    BOOL adjacent = NO;
    for (NSDictionary *display in start[@"displays"]) {
        if (![display[@"activeSpaceID"] isEqual:from]) continue;
        NSMutableArray *users = [NSMutableArray array];
        for (NSDictionary *space in display[@"spaces"])
            if ([space[@"type"] isEqual:@"user"]) [users addObject:space[@"id"]];
        NSUInteger a = [users indexOfObject:from], b = [users indexOfObject:to];
        adjacent = a != NSNotFound && b != NSNotFound && (a + 1 == b || b + 1 == a);
    }
    if (!adjacent || spaceType(connection, source) != 0 || spaceType(connection, destination) != 0) {
        failure = @"target-not-an-adjacent-user-space-on-source-display"; return nil;
    }
    MoveWindowsFn moveWindows = (MoveWindowsFn)dlsym(skyLightHandle, "SLSMoveWindowsToManagedSpace");
    if (!moveWindows) { failure = @"move-symbol-unavailable"; return nil; }

    [NSApplication sharedApplication];
    [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
    NSScreen *screen = NSScreen.mainScreen;
    if (!screen) { failure = @"no-screen"; return nil; }
    NSRect frame = screen.visibleFrame;
    NSRect rect = NSMakeRect(NSMidX(frame)-180, NSMidY(frame)-65, 360, 130);
    NSWindow *window = [[NSWindow alloc] initWithContentRect:rect
        styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable
        backing:NSBackingStoreBuffered defer:NO];
    window.releasedWhenClosed = NO;
    window.title = @"Window Factory — disposable Space probe";
    NSTextField *label = [NSTextField wrappingLabelWithString:
        @"Native Space helper proof\nThis disposable window closes automatically.\nNo existing application window is moved."];
    label.frame = NSMakeRect(20, 20, 320, 90);
    [window.contentView addSubview:label];
    NSDate *began = NSDate.date;
    NSMutableDictionary *result = [@{@"schemaVersion": @1, @"ok": @NO, @"command": @"probe-move",
        @"sourceSpaceID": from, @"targetSpaceID": to, @"moveRequests": @0,
        @"method": @"SLSMoveWindowsToManagedSpace"} mutableCopy];
    @try {
        [window orderFrontRegardless];
        pump(0.6);
        uint32_t wid = (uint32_t)window.windowNumber;
        result[@"windowID"] = @(wid).stringValue;
        NSArray *before = spacesForWindow(wid);
        result[@"beforeSpaceIDs"] = before ?: @[];
        BOOL owned = NO;
        CFArrayRef info = CGWindowListCopyWindowInfo(kCGWindowListOptionIncludingWindow, wid);
        for (NSDictionary *entry in CFBridgingRelease(info)) {
            if ([entry[(__bridge NSString *)kCGWindowNumber] unsignedIntValue] == wid
                && [entry[(__bridge NSString *)kCGWindowOwnerPID] intValue] == NSProcessInfo.processInfo.processIdentifier)
                owned = YES;
        }
        if (!wid || !owned || ![before isEqual:@[from]] || activeSpace(connection) != source) {
            result[@"reason"] = @"new-window-ownership-or-source-check-failed";
        } else {
            // This legacy API has no return value. Dispatch once, then require
            // two consecutive membership readbacks; dispatch is not success.
            result[@"moveRequests"] = @1;
            moveWindows(connection, (__bridge CFArrayRef)@[@(wid)], destination);
            int matches = 0;
            NSArray *after = @[];
            for (int i=0; i<30 && activeSpace(connection)==source; i++) {
                pump(0.1);
                after = spacesForWindow(wid) ?: @[];
                matches = [after isEqual:@[to]] ? matches+1 : 0;
                if (matches >= 2) break;
            }
            BOOL verified = matches>=2 && activeSpace(connection)==source;
            result[@"afterSpaceIDs"] = after;
            result[@"ok"] = verified ? @YES : @NO;
            if (!verified) result[@"reason"] = activeSpace(connection)!=source
                ? @"active-space-changed" : @"move-not-verified";
        }
    } @catch (__unused NSException *exception) {
        result[@"ok"] = @NO;
        result[@"reason"] = @"native-probe-exception";
    } @finally {
        [window close];
        result[@"windowClosed"] = !window.visible ? @YES : @NO;
        result[@"activeSpaceUnchanged"] = activeSpace(connection)==source ? @YES : @NO;
        result[@"seconds"] = @(-began.timeIntervalSinceNow);
    }
    return result;
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc == 2 && strcmp(argv[1], "help") == 0) {
            return emit(@{@"schemaVersion": @1, @"ok": @YES,
                @"commands": @[@"snapshot", @"window-spaces WINDOW_ID", @"probe-move SOURCE_SPACE_ID TARGET_SPACE_ID", @"help"],
                @"moveOwnWindowOnly": @YES}, 0);
        }
        uint64_t wid = 0;
        BOOL readSnapshot = argc == 2 && strcmp(argv[1], "snapshot") == 0;
        BOOL readWindow = argc == 3 && strcmp(argv[1], "window-spaces") == 0
            && readID(argv[2], UINT32_MAX, &wid);
        uint64_t from=0, to=0;
        BOOL moveProbe = argc==4 && strcmp(argv[1], "probe-move")==0
            && readID(argv[2], UINT64_MAX, &from) && readID(argv[3], UINT64_MAX, &to) && from!=to;
        if (!readSnapshot && !readWindow && !moveProbe)
            return reject(@"usage: snapshot | window-spaces WINDOW_ID | probe-move SOURCE_SPACE_ID TARGET_SPACE_ID | help", 64);
        if (!loadAPI()) return reject(failure, 69);
        if (moveProbe) {
            NSDictionary *value = probeMove(from,to);
            return value ? emit(value, [value[@"ok"] boolValue] ? 0 : 69) : reject(failure,69);
        }
        if (readSnapshot) {
            NSDictionary *value = snapshot();
            return value ? emit(value, 0) : reject(failure, 69);
        }
        NSArray *spaces = spacesForWindow((uint32_t)wid);
        return spaces ? emit(@{@"schemaVersion": @1, @"ok": @YES, @"command": @"window-spaces",
            @"windowID": @(wid).stringValue, @"spaceIDs": spaces}, 0) : reject(failure, 69);
    }
}
