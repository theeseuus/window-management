static void pump(NSTimeInterval seconds) {
    NSDate *end = [NSDate dateWithTimeIntervalSinceNow:seconds];
    while (end.timeIntervalSinceNow > 0) {
        [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];
    }
}

// Intentionally cannot accept an existing window ID: only the NSWindow created
// in this function can reach the private move API.
static NSDictionary *bridgeOwnMove(uint64_t source, uint64_t destination) {
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
    if (!bridgeClass(@"MoveWindowsToManagedSpaceOperation")) { failure = @"move-class-unavailable"; return nil; }

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
        @"axTrusted": AXIsProcessTrusted() ? @YES : @NO,
        @"sourceSpaceID": from, @"targetSpaceID": to, @"moveRequests": @0,
        @"method": @"SLSBridgedMoveWindowsToManagedSpaceOperation"} mutableCopy];
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
            // The asynchronous bridge returns void. Dispatch once, then require
            // two consecutive membership readbacks; dispatch is not success.
            result[@"moveRequests"] = @1;
            if (!bridgeMove(wid,destination)) @throw [NSException exceptionWithName:@"BridgeUnavailable" reason:nil userInfo:nil];
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
    if (![result[@"activeSpaceUnchanged"] boolValue] || ![result[@"windowClosed"] boolValue]) {
        result[@"ok"]=@NO; result[@"reason"]=@"cleanup-or-active-space-check-failed";
    }
    return result;
}

