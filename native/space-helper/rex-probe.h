// Explicit Rex-only pilot. A before-creation receipt identifies the one new
// disposable window; ordinary foreign-window targeting remains unavailable.
static NSDictionary *rexInventory(void) {
    NSArray *apps=[NSRunningApplication runningApplicationsWithBundleIdentifier:@"com.superlogical.rex"];
    if (apps.count!=1) { failure=@"rex-process-absent-or-ambiguous"; return nil; }
    NSRunningApplication *app=apps.firstObject;
    NSMutableDictionary *windows=[NSMutableDictionary dictionary];
    CFArrayRef raw=CGWindowListCopyWindowInfo(kCGWindowListOptionAll,kCGNullWindowID);
    for (NSDictionary *entry in CFBridgingRelease(raw)) {
        if ([entry[(__bridge NSString *)kCGWindowOwnerPID] intValue]!=app.processIdentifier
            || [entry[(__bridge NSString *)kCGWindowLayer] intValue]!=0) continue;
        CGRect bounds=CGRectZero;
        if (!CGRectMakeWithDictionaryRepresentation((__bridge CFDictionaryRef)entry[(__bridge NSString *)kCGWindowBounds],&bounds)
            || bounds.size.width<100 || bounds.size.height<100) continue;
        uint32_t wid=[entry[(__bridge NSString *)kCGWindowNumber] unsignedIntValue];
        NSArray *spaces=spacesForWindow(wid);
        if (!spaces) return nil;
        windows[@(wid).stringValue]=spaces;
    }
    NSDictionary *info=[NSBundle bundleWithURL:app.bundleURL].infoDictionary;
    return @{@"schemaVersion": @1,@"ok": @YES,@"command": @"rex-inventory",
        @"pid": @(app.processIdentifier),@"bundleID": app.bundleIdentifier,
        @"bundlePath": app.bundleURL.path,@"build": info[@"CFBundleVersion"] ?: @"unknown",
        @"version": info[@"CFBundleShortVersionString"] ?: @"unknown",
        @"windows": windows,@"focusedSpaceID": @(activeSpace(connection)).stringValue};
}

static NSDictionary *restoreRexView(uint64_t target,NSString *receiptPath) {
    NSDictionary *start=snapshot(),*inventory=rexInventory();
    NSData *data=[NSData dataWithContentsOfFile:receiptPath];
    NSDictionary *receipt=data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
    uint64_t parsed=0;
    if (!start || !inventory) return nil;
    if (![receipt isKindOfClass:NSDictionary.class] || ![receipt[@"windowID"] isKindOfClass:NSString.class]
        || !readID([receipt[@"windowID"] UTF8String],UINT32_MAX,&parsed)
        || ![receipt[@"beforeWindows"] isKindOfClass:NSDictionary.class]
        || ![receipt[@"pid"] isEqual:inventory[@"pid"]]) { failure=@"invalid-rex-creation-receipt"; return nil; }
    NSString *wid=@(parsed).stringValue,*to=@(target).stringValue;
    NSDictionary *before=receipt[@"beforeWindows"];
    NSMutableDictionary *expected=[before mutableCopy];
    if (before[wid] || !inventory[@"windows"][wid]) { failure=@"replacement-window-not-new"; return nil; }
    expected[wid]=inventory[@"windows"][wid];
    if (![expected isEqual:inventory[@"windows"]]) { failure=@"rex-baseline-mismatch"; return nil; }
    BOOL valid=NO;
    for (NSDictionary *display in start[@"displays"])
        for (NSDictionary *space in display[@"spaces"])
            if ([space[@"id"] isEqual:to] && [space[@"type"] isEqual:@"user"]) valid=YES;
    if (!valid || !windowFacts((uint32_t)parsed,[inventory[@"pid"] intValue])) {
        failure=@"replacement-owner-or-target-invalid"; return nil;
    }
    uint64_t active=activeSpace(connection);
    if (!bridgeMove((uint32_t)parsed,target)) { failure=@"restore-not-dispatched"; return nil; }
    int matches=0;
    for (int i=0;i<30 && activeSpace(connection)==active;i++) {
        pump(0.1);
        BOOL correct=[spacesForWindow((uint32_t)parsed) isEqual:@[to]]
            && [bridgeWindowSpaces((uint32_t)parsed) isEqual:@[to]]
            && [windowsForSpace(target) containsObject:wid];
        matches=correct ? matches+1 : 0;
        if (matches>=2) break;
    }
    expected[wid]=@[to];
    BOOL unchanged=[rexInventory()[@"windows"] isEqual:expected];
    BOOL ok=matches>=2 && unchanged && activeSpace(connection)==active;
    return @{@"schemaVersion": @1,@"ok": ok ? @YES : @NO,@"command": @"bridge-restore-rex",
        @"windowID": wid,@"targetSpaceID": to,@"moveRequests": @1,
        @"membershipVerified": matches>=2 ? @YES : @NO,
        @"otherRexWindowsUnchanged": unchanged ? @YES : @NO,
        @"activeSpaceUnchanged": activeSpace(connection)==active ? @YES : @NO,
        @"axTrusted": AXIsProcessTrusted() ? @YES : @NO};
}

static BOOL verifyRexLocation(uint32_t wid,pid_t pid,NSString *space,BOOL onscreen,uint64_t source) {
    int matches=0;
    for (int i=0;i<30 && activeSpace(connection)==source;i++) {
        pump(0.1);
        NSDictionary *facts=windowFacts(wid,pid);
        BOOL correct=facts && [facts[@"onScreen"] boolValue]==onscreen
            && [spacesForWindow(wid) isEqual:@[space]]
            && [bridgeWindowSpaces(wid) isEqual:@[space]];
        matches=correct ? matches+1 : 0;
        if (matches>=2) return YES;
    }
    return NO;
}

#include "rex-follow.h"

static NSDictionary *bridgeRexMove(uint64_t source,uint64_t destination,NSString *receiptPath,BOOL follow) {
    NSDictionary *start=snapshot(),*inventory=rexInventory();
    if (!start || !inventory) return nil;
    NSString *from=@(source).stringValue,*to=@(destination).stringValue;
    BOOL adjacent=NO;
    NSString *displayID=nil;
    for (NSDictionary *display in start[@"displays"]) {
        if (![display[@"activeSpaceID"] isEqual:from]) continue;
        displayID=display[@"display"];
        NSMutableArray *users=[NSMutableArray array];
        for (NSDictionary *space in display[@"spaces"])
            if ([space[@"type"] isEqual:@"user"]) [users addObject:space[@"id"]];
        NSUInteger a=[users indexOfObject:from],b=[users indexOfObject:to];
        adjacent=a!=NSNotFound && b!=NSNotFound && (a+1==b || b+1==a);
    }
    if (![start[@"focusedSpaceID"] isEqual:from] || !adjacent) {
        failure=@"source-or-adjacent-target-check-failed"; return nil;
    }
    if (follow && (!AXIsProcessTrusted() || !axWindowID() || !followClassesAvailable())) {
        failure=@"follow-needs-existing-ax-trust-and-bridge-classes"; return nil;
    }
    NSData *data=[NSData dataWithContentsOfFile:receiptPath];
    NSDictionary *receipt=data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
    uint64_t parsed=0;
    if (![receipt isKindOfClass:NSDictionary.class]
        || ![receipt[@"windowID"] isKindOfClass:NSString.class]
        || !readID([receipt[@"windowID"] UTF8String],UINT32_MAX,&parsed)
        || ![receipt[@"beforeWindows"] isKindOfClass:NSDictionary.class]
        || ![receipt[@"pid"] isEqual:inventory[@"pid"]]) {
        failure=@"invalid-rex-creation-receipt"; return nil;
    }
    uint32_t wid=(uint32_t)parsed;
    pid_t pid=[inventory[@"pid"] intValue];
    NSString *key=@(wid).stringValue;
    NSDictionary *before=receipt[@"beforeWindows"];
    NSMutableDictionary *expected=[before mutableCopy];
    expected[key]=@[from];
    if (before[key] || ![expected isEqual:inventory[@"windows"]]
        || ![windowFacts(wid,pid)[@"onScreen"] boolValue]
        || activeSpace(connection)!=source) {
        failure=@"rex-new-window-or-baseline-check-failed"; return nil;
    }
    NSMutableDictionary *result=[@{@"schemaVersion": @1,@"ok": @NO,@"command": follow ? @"bridge-probe-rex-follow" : @"bridge-probe-rex",
        @"windowID": key,@"pid": @(pid),@"version": inventory[@"version"],@"build": inventory[@"build"],
        @"axTrusted": AXIsProcessTrusted() ? @YES : @NO,@"sourceSpaceID": from,@"targetSpaceID": to,
        @"outboundVerified": @NO,@"returnVerified": @NO,@"moveRequests": @0} mutableCopy];
    __block NSUInteger changes=0;
    id observer=nil;
    NSArray *candidates=follow ? sourceVisibilityCandidates(wid,from) : nil;
    if (follow) observer=[NSWorkspace.sharedWorkspace.notificationCenter
        addObserverForName:NSWorkspaceActiveSpaceDidChangeNotification object:nil queue:nil
        usingBlock:^(__unused NSNotification *note) { changes++; }];
    NSDate *began=NSDate.date;
    @try {
        if (!bridgeMove(wid,destination)) @throw [NSException exceptionWithName:@"OutboundNotDispatched" reason:nil userInfo:nil];
        result[@"moveRequests"]=@1;
        result[@"outboundVerified"]=verifyRexLocation(wid,pid,to,NO,source) ? @YES : @NO;
        result[@"outboundCSpaces"]=spacesForWindow(wid) ?: @[];
        result[@"outboundBridgeSpaces"]=bridgeWindowSpaces(wid) ?: @[];
        result[@"outboundFacts"]=windowFacts(wid,pid) ?: @{};
        if (follow) {
            if (![result[@"outboundVerified"] boolValue] || !switchForFollow(source,destination,displayID))
                @throw [NSException exceptionWithName:@"FollowSwitchNotDispatched" reason:nil userInfo:nil];
            result[@"followVerified"]=verifyFollow(pid,wid,destination,candidates) ? @YES : @NO;
            result[@"sourceWindowsChecked"]=@(candidates.count);
            result[@"sourceWindowsHidden"]=sourceCandidatesHidden(candidates) ? @YES : @NO;
            result[@"targetActiveSpaceID"]=@(activeSpace(connection)).stringValue;
            result[@"targetWindowFocused"]=focusedRexWindow(pid,wid) ? @YES : @NO;
            if ([result[@"followVerified"] boolValue]) pump(10);
        } else pump(0.5);
    } @catch (NSException *exception) { result[@"reason"]=exception.name; }
    @finally {
        // Return only the same PID-verified test window. No desktop switch,
        // application activation, close action or generic window selector.
        if (windowFacts(wid,pid) && ![spacesForWindow(wid) isEqual:@[from]]) {
            if (bridgeMove(wid,source)) result[@"moveRequests"]=@([result[@"moveRequests"] intValue]+1);
        }
        if (follow && activeSpace(connection)==destination) {
            result[@"returnSwitchDispatched"]=switchForFollow(destination,source,displayID) ? @YES : @NO;
            result[@"returnFollowVerified"]=verifyFollow(pid,wid,source,nil) ? @YES : @NO;
        }
        result[@"returnVerified"]=verifyRexLocation(wid,pid,from,YES,source) ? @YES : @NO;
        result[@"returnCSpaces"]=spacesForWindow(wid) ?: @[];
        result[@"returnBridgeSpaces"]=bridgeWindowSpaces(wid) ?: @[];
        result[@"returnFacts"]=windowFacts(wid,pid) ?: @{};
        NSDictionary *after=rexInventory();
        result[@"existingRexWindowsUnchanged"]=[after[@"windows"] isEqual:expected] ? @YES : @NO;
        result[@"activeSpaceUnchanged"]=activeSpace(connection)==source ? @YES : @NO;
        result[@"seconds"]=@(-began.timeIntervalSinceNow);
        if (observer) {
            [NSWorkspace.sharedWorkspace.notificationCenter removeObserver:observer];
            result[@"spaceChangeNotifications"]=@(changes);
        }
    }
    BOOL ok=[result[@"outboundVerified"] boolValue] && [result[@"returnVerified"] boolValue]
        && [result[@"existingRexWindowsUnchanged"] boolValue] && [result[@"activeSpaceUnchanged"] boolValue];
    if (follow) {
        // The initial live probe observed no NSWorkspace change notifications
        // despite verified focus, membership and compositor flags in both
        // directions. Notification delivery is diagnostic, not move success.
        ok=ok && [result[@"followVerified"] boolValue] && [result[@"returnFollowVerified"] boolValue];
        result[@"functionalChecksPassed"]=ok ? @YES : @NO;
        result[@"spaceChangeNotificationObserved"]=changes>0 ? @YES : @NO;
    }
    result[@"ok"]=ok ? @YES : @NO;
    if (!ok && !result[@"reason"]) result[@"reason"]=@"rex-round-trip-not-verified";
    return result;
}
