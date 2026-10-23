// Independent feasibility harness based on the operation names and signatures
// reported in KiwiDesk issues #884/#889. No KiwiDesk implementation is copied.
#include "space-runtime.h"
#import <ApplicationServices/ApplicationServices.h>
#import <objc/message.h>
#import <objc/runtime.h>
#include <fcntl.h>
#include <unistd.h>
#include <poll.h>
#include <signal.h>

@interface NSObject (BridgeProbeInitializers)
- (instancetype)initWithOptions:(uint32_t)options windows:(NSArray *)windows;
- (instancetype)initWithWindows:(NSArray *)windows spaceID:(uint64_t)space;
@end

static Class bridgeClass(NSString *name) {
    return NSClassFromString([@"SLSBridged" stringByAppendingString:name]);
}

static id readOperation(id op) {
    SEL perform = NSSelectorFromString(@"performWithWMBridgeDelegate");
    NSMethodSignature *signature = [op methodSignatureForSelector:perform];
    if (!signature || strcmp(signature.methodReturnType, @encode(id)) != 0
        || signature.numberOfArguments != 2) {
        failure = @"read-operation-signature-unavailable"; return nil;
    }
    return ((id (*)(id, SEL))(void *)objc_msgSend)(op, perform);
}

static NSArray *arrayField(id result, NSString *name) {
    SEL field = NSSelectorFromString(name);
    if (![result respondsToSelector:field]) { failure = @"bridge-result-field-absent"; return nil; }
    id value = ((id (*)(id, SEL))(void *)objc_msgSend)(result, field);
    if (![value isKindOfClass:NSArray.class]) { failure = @"bridge-result-not-array"; return nil; }
    return value;
}

static NSArray *bridgeWindowSpaces(uint32_t wid) {
    Class cls = bridgeClass(@"CopySpacesForWindowsOperation");
    SEL init = NSSelectorFromString(@"initWithOptions:windows:");
    if (![cls instancesRespondToSelector:init]) { failure = @"bridge-window-query-absent"; return nil; }
    id op = [[cls alloc] initWithOptions:7 windows:@[@(wid)]];
    NSArray *values = arrayField(readOperation(op), @"numbers");
    return values ? numericStrings(values) : nil;
}

static BOOL bridgeMove(uint32_t wid, uint64_t destination) {
    Class cls = bridgeClass(@"MoveWindowsToManagedSpaceOperation");
    SEL init = NSSelectorFromString(@"initWithWindows:spaceID:");
    if (![cls instancesRespondToSelector:init]) return NO;
    id op = [[cls alloc] initWithWindows:@[@(wid)] spaceID:destination];
    SEL perform = NSSelectorFromString(@"performWithWMBridgeDelegate");
    NSMethodSignature *signature = [op methodSignatureForSelector:perform];
    if (!signature || strcmp(signature.methodReturnType,@encode(void)) != 0
        || signature.numberOfArguments != 2) return NO;
    ((void (*)(id, SEL))(void *)objc_msgSend)(op, perform);
    return YES;
}

#include "bridge-owned-window.h"

static NSDictionary *windowFacts(uint32_t wid, pid_t pid) {
    CFArrayRef raw=CGWindowListCopyWindowInfo(kCGWindowListOptionIncludingWindow,wid);
    for (NSDictionary *entry in CFBridgingRelease(raw)) {
        if ([entry[(__bridge NSString *)kCGWindowNumber] unsignedIntValue]==wid
            && [entry[(__bridge NSString *)kCGWindowOwnerPID] intValue]==pid) {
            return @{@"ownedByExpectedPID": @YES,
                @"onScreen": [entry[(__bridge NSString *)kCGWindowIsOnscreen] boolValue] ? @YES : @NO};
        }
    }
    return nil;
}

static NSDictionary *bridgeForeignMove(uint64_t source, uint64_t target) {
    NSDictionary *start=snapshot();
    if (!start) return nil;
    NSString *from=@(source).stringValue,*to=@(target).stringValue;
    BOOL adjacent=NO;
    for (NSDictionary *display in start[@"displays"]) {
        if (![display[@"activeSpaceID"] isEqual:from]) continue;
        NSMutableArray *users=[NSMutableArray array];
        for (NSDictionary *space in display[@"spaces"])
            if ([space[@"type"] isEqual:@"user"]) [users addObject:space[@"id"]];
        NSUInteger a=[users indexOfObject:from],b=[users indexOfObject:to];
        adjacent=a!=NSNotFound && b!=NSNotFound && (a+1==b || b+1==a);
    }
    if (![start[@"focusedSpaceID"] isEqual:from] || !adjacent) {
        failure=@"source-or-adjacent-target-check-failed"; return nil;
    }
    // Only this freshly spawned host's self-reported and PID-verified window
    // may be moved. The CLI has no arbitrary foreign-window-ID argument.
    NSString *path=[NSBundle.mainBundle.bundlePath.stringByDeletingLastPathComponent
        stringByAppendingPathComponent:@"WindowProbe.app/Contents/MacOS/window-probe"];
    NSTask *host=[[NSTask alloc] init];
    host.executableURL=[NSURL fileURLWithPath:path];
    host.arguments=@[@"disposable-host"];
    NSPipe *output=[NSPipe pipe],*input=[NSPipe pipe];
    host.standardOutput=output; host.standardInput=input; host.standardError=[NSFileHandle fileHandleWithNullDevice];
    NSMutableDictionary *result=[@{@"schemaVersion": @1,@"command": @"bridge-probe-foreign",
        @"ok": @NO,@"axTrusted": AXIsProcessTrusted() ? @YES : @NO,
        @"sourceSpaceID": from,@"targetSpaceID": to,@"moveRequests": @0} mutableCopy];
    uint32_t wid=0;
    NSDate *began=NSDate.date;
    @try {
        NSError *error=nil;
        if (![host launchAndReturnError:&error]) @throw [NSException exceptionWithName:@"HostLaunchFailed" reason:nil userInfo:nil];
        int fd=output.fileHandleForReading.fileDescriptor;
        struct pollfd descriptor={.fd=fd,.events=POLLIN};
        if (poll(&descriptor,1,3000)<=0) @throw [NSException exceptionWithName:@"HostReadyTimeout" reason:nil userInfo:nil];
        char bytes[256]; ssize_t count=read(fd,bytes,sizeof(bytes));
        NSData *data=count>0 ? [NSData dataWithBytes:bytes length:(NSUInteger)count] : nil;
        NSDictionary *ready=data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
        uint64_t parsed=0;
        if (![ready isKindOfClass:NSDictionary.class]
            || ![ready[@"windowID"] isKindOfClass:NSString.class]
            || !readID([ready[@"windowID"] UTF8String],UINT32_MAX,&parsed)
            || [ready[@"pid"] intValue]!=host.processIdentifier || host.processIdentifier==getpid())
            @throw [NSException exceptionWithName:@"HostIdentityFailed" reason:nil userInfo:nil];
        wid=(uint32_t)parsed;
        result[@"windowID"]=@(wid).stringValue;
        result[@"foreignProcess"]=@YES;
        NSDictionary *facts=windowFacts(wid,host.processIdentifier);
        NSArray *before=spacesForWindow(wid);
        result[@"beforeSpaceIDs"]=before ?: @[];
        result[@"beforeFacts"]=facts ?: @{};
        if (!facts || ![facts[@"onScreen"] boolValue] || ![before isEqual:@[from]] || activeSpace(connection)!=source)
            @throw [NSException exceptionWithName:@"HostSourceFailed" reason:nil userInfo:nil];
        if (!bridgeMove(wid,target)) @throw [NSException exceptionWithName:@"MoveNotDispatched" reason:nil userInfo:nil];
        result[@"moveRequests"]=@1;
        int matches=0;
        for (int i=0;i<30 && activeSpace(connection)==source;i++) {
            pump(0.1);
            NSArray *c=spacesForWindow(wid),*bridge=bridgeWindowSpaces(wid);
            NSDictionary *after=windowFacts(wid,host.processIdentifier);
            result[@"afterSpaceIDs"]=c ?: @[];
            result[@"afterBridgeSpaceIDs"]=bridge ?: @[];
            result[@"afterFacts"]=after ?: @{};
            BOOL moved=[c isEqual:@[to]] && [bridge isEqual:@[to]] && after && ![after[@"onScreen"] boolValue];
            matches=moved ? matches+1 : 0;
            if (matches>=2) break;
        }
        BOOL verified=matches>=2 && activeSpace(connection)==source;
        result[@"ok"]=verified ? @YES : @NO;
        if (!verified) result[@"reason"]=@"foreign-window-move-not-verified";
    } @catch (NSException *exception) {
        result[@"reason"]=exception.name;
    } @finally {
        if (host.running) {
            (void)write(input.fileHandleForWriting.fileDescriptor,"q",1);
            NSDate *deadline=[NSDate dateWithTimeIntervalSinceNow:1];
            while (host.running && deadline.timeIntervalSinceNow>0) pump(0.02);
            if (host.running) [host terminate]; // only the exact child we launched
        }
        result[@"hostExited"]=!host.running ? @YES : @NO;
        result[@"windowRemoved"]=wid && !windowFacts(wid,host.processIdentifier) ? @YES : @NO;
        result[@"activeSpaceUnchanged"]=activeSpace(connection)==source ? @YES : @NO;
        result[@"seconds"]=@(-began.timeIntervalSinceNow);
    }
    if (![result[@"hostExited"] boolValue] || ![result[@"windowRemoved"] boolValue]) {
        result[@"ok"]=@NO; result[@"reason"]=@"cleanup-not-verified";
    }
    if (![result[@"activeSpaceUnchanged"] boolValue]) {
        result[@"ok"]=@NO; result[@"reason"]=@"active-space-changed";
    }
    return result;
}

#include "rex-probe.h"

static NSArray *topology(NSArray *displays) {
    NSMutableArray *out = [NSMutableArray array];
    for (NSDictionary *display in displays) {
        if (![display isKindOfClass:NSDictionary.class]) return nil;
        NSString *uuid = display[@"Display Identifier"];
        NSDictionary *current = display[@"Current Space"];
        NSArray *spaces = display[@"Spaces"];
        if (![uuid isKindOfClass:NSString.class] || ![current isKindOfClass:NSDictionary.class]
            || ![spaces isKindOfClass:NSArray.class]) return nil;
        NSNumber *active = current[@"ManagedSpaceID"];
        if (![active isKindOfClass:NSNumber.class]) return nil;
        NSMutableArray *ids = [NSMutableArray array];
        for (NSDictionary *space in spaces) {
            if (![space isKindOfClass:NSDictionary.class]) return nil;
            NSNumber *sid = space[@"ManagedSpaceID"];
            NSNumber *type = space[@"type"];
            if (![sid isKindOfClass:NSNumber.class] || ![type isKindOfClass:NSNumber.class]) return nil;
            [ids addObject:@{@"id": sid.stringValue, @"type": type}];
        }
        [out addObject:@{@"display": uuid, @"activeSpaceID": active.stringValue, @"spaces": ids}];
    }
    return out;
}

static NSDictionary *bridgeQuery(void) {
    uint64_t before = activeSpace(connection);
    NSMutableDictionary *classes = [NSMutableDictionary dictionary];
    for (NSString *name in @[@"CopyManagedDisplaySpacesOperation", @"CopySpacesForWindowsOperation",
        @"MoveWindowsToManagedSpaceOperation"]) classes[name] = bridgeClass(name) ? @YES : @NO;
    Class cls = bridgeClass(@"CopyManagedDisplaySpacesOperation");
    NSArray *bridge = arrayField(readOperation([[cls alloc] init]), @"propertyListArray");
    if (!bridge) return nil;
    CFArrayRef raw = managedDisplays(connection);
    if (!raw) { failure = @"c-api-topology-unavailable"; return nil; }
    NSArray *expected = topology(CFBridgingRelease(raw));
    NSArray *actual = topology(bridge);
    if (!expected || !actual || ![expected isEqual:actual]) { failure = @"bridge-topology-mismatch"; return nil; }
    NSMutableOrderedSet *sample = [NSMutableOrderedSet orderedSet];
    for (NSDictionary *display in actual) {
        for (NSDictionary *space in display[@"spaces"]) {
            NSArray *windows = windowsForSpace([space[@"id"] longLongValue]);
            if (!windows) return nil;
            for (NSString *wid in windows) if (sample.count < 16) [sample addObject:wid];
        }
    }
    for (NSString *wid in sample) {
        NSArray *a = spacesForWindow(wid.intValue), *b = bridgeWindowSpaces(wid.intValue);
        if (!a || !b || ![[NSSet setWithArray:a] isEqual:[NSSet setWithArray:b]]) {
            failure = @"bridge-window-membership-mismatch"; return nil;
        }
    }
    if (!before || activeSpace(connection) != before) { failure = @"active-space-changed"; return nil; }
    return @{@"schemaVersion": @1, @"ok": @YES, @"command": @"bridge-query",
        @"axTrusted": AXIsProcessTrusted() ? @YES : @NO, @"classes": classes,
        @"topologyMatchesCAPI": @YES, @"windowMembershipMatchesCAPI": @YES,
        @"checkedWindows": @(sample.count), @"topology": actual,
        @"activeSpaceUnchanged": @YES, @"osVersion": NSProcessInfo.processInfo.operatingSystemVersionString};
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        signal(SIGPIPE,SIG_IGN); // A test host exiting early must not kill cleanup.
        // LaunchServices app runs use a fresh temporary report file. Refuse
        // overwriting anything; the runtime report never belongs in Git.
        const char *reportPath=NULL;
        if (argc >= 4 && strcmp(argv[argc-2],"--report") == 0) {
            reportPath=argv[argc-1]; argc-=2;
        }
        BOOL help=argc==2 && strcmp(argv[1],"help")==0;
        uint64_t from=0,to=0;
        BOOL query = argc==2 && strcmp(argv[1],"bridge-query")==0;
        BOOL inventory = argc==2 && strcmp(argv[1],"rex-inventory")==0;
        BOOL own = argc==4 && strcmp(argv[1],"bridge-probe-own")==0
            && readID(argv[2],UINT64_MAX,&from) && readID(argv[3],UINT64_MAX,&to) && from!=to;
        BOOL foreign = argc==4 && strcmp(argv[1],"bridge-probe-foreign")==0
            && readID(argv[2],UINT64_MAX,&from) && readID(argv[3],UINT64_MAX,&to) && from!=to;
        BOOL rex = argc==5 && strcmp(argv[1],"bridge-probe-rex")==0
            && readID(argv[2],UINT64_MAX,&from) && readID(argv[3],UINT64_MAX,&to) && from!=to;
        BOOL follow = argc==5 && strcmp(argv[1],"bridge-probe-rex-follow")==0
            && readID(argv[2],UINT64_MAX,&from) && readID(argv[3],UINT64_MAX,&to) && from!=to;
        BOOL restore = argc==4 && strcmp(argv[1],"bridge-restore-rex")==0 && readID(argv[2],UINT64_MAX,&to);
        if (!query && !own && !foreign && !help && !inventory && !rex && !restore && !follow)
            return reject(@"usage: bridge-query | rex-inventory | bridge-probe-own SOURCE TARGET | bridge-probe-foreign SOURCE TARGET | bridge-probe-rex SOURCE TARGET RECEIPT | bridge-restore-rex TARGET RECEIPT | help",64);
        if (reportPath) {
            int fd=open(reportPath,O_WRONLY|O_CREAT|O_EXCL|O_NOFOLLOW,0600);
            if (fd<0) return 73;
            if (dup2(fd,STDOUT_FILENO)<0) { close(fd); return 73; }
            close(fd);
        }
        if (help) return emit(@{@"schemaVersion": @1,@"ok": @YES,
            @"commands": @[@"bridge-query",@"rex-inventory",@"bridge-probe-own SOURCE TARGET",@"bridge-probe-foreign SOURCE TARGET",@"bridge-probe-rex SOURCE TARGET RECEIPT",@"bridge-probe-rex-follow SOURCE TARGET RECEIPT",@"bridge-restore-rex TARGET RECEIPT",@"help"],
            @"existingWindowTargetsAllowed": @NO,@"rexCreationReceiptRequired": @YES,@"requestAccessibilityPermission": @NO},0);
        if (!loadAPI()) return reject(failure,69);
        // Real AppKit initialization is required by this private bridge.
        [NSApplication sharedApplication];
        [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
        @try {
            NSDictionary *value = restore ? restoreRexView(to,@(argv[3])) : (rex || follow) ? bridgeRexMove(from,to,@(argv[4]),follow) : inventory ? rexInventory()
                : own ? bridgeOwnMove(from,to) : foreign ? bridgeForeignMove(from,to) : bridgeQuery();
            return value ? emit(value,[value[@"ok"] boolValue] ? 0 : 69)
                : reject(failure ?: @"bridge-probe-failed",69);
        } @catch (__unused NSException *exception) {
            return reject(@"bridge-query-exception",69);
        }
    }
}
