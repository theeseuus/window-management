// Native follow pilot: bridge switching plus existing AX trust for exact focus.
@interface NSObject (FollowProbeInitializers)
- (instancetype)initWithDisplayIdentifier:(NSString *)display spaceID:(uint64_t)space;
- (instancetype)initWithSpaces:(NSArray *)spaces;
@end

static BOOL dispatchFollowOperation(id op) {
    SEL sel=NSSelectorFromString(@"performWithWMBridgeDelegate");
    NSMethodSignature *signature=[op methodSignatureForSelector:sel];
    if (!signature || strcmp(signature.methodReturnType,@encode(void))!=0
        || signature.numberOfArguments!=2) return NO;
    ((void (*)(id,SEL))(void *)objc_msgSend)(op,sel);
    return YES;
}

static BOOL followClassesAvailable(void) {
    return [bridgeClass(@"ManagedDisplaySetCurrentSpaceOperation") instancesRespondToSelector:
        NSSelectorFromString(@"initWithDisplayIdentifier:spaceID:")]
        && [bridgeClass(@"HideSpacesOperation") instancesRespondToSelector:NSSelectorFromString(@"initWithSpaces:")];
}

static BOOL switchForFollow(uint64_t from,uint64_t to,NSString *display) {
    if (activeSpace(connection)!=from || !followClassesAvailable()) return NO;
    id set=[[bridgeClass(@"ManagedDisplaySetCurrentSpaceOperation") alloc]
        initWithDisplayIdentifier:display spaceID:to];
    id hide=[[bridgeClass(@"HideSpacesOperation") alloc] initWithSpaces:@[@(from)]];
    // Prepare both objects before dispatch. The pointer write alone does not
    // establish a compositor transition; hide the origin only after dispatch.
    if (!set || !hide || !dispatchFollowOperation(set)) return NO;
    return dispatchFollowOperation(hide);
}

typedef AXError (*AXWindowIDFn)(AXUIElementRef,CGWindowID *);
static AXWindowIDFn axWindowID(void) {
    return (AXWindowIDFn)dlsym(RTLD_DEFAULT,"_AXUIElementGetWindow");
}

static BOOL focusedRexWindow(pid_t pid,uint32_t wid) {
    AXWindowIDFn getID=axWindowID();
    if (!getID || NSWorkspace.sharedWorkspace.frontmostApplication.processIdentifier!=pid) return NO;
    AXUIElementRef app=AXUIElementCreateApplication(pid);
    AXUIElementSetMessagingTimeout(app,0.3);
    CFTypeRef raw=NULL;
    AXError status=AXUIElementCopyAttributeValue(app,kAXFocusedWindowAttribute,&raw);
    CGWindowID actual=0;
    BOOL ok=status==kAXErrorSuccess && raw && getID((AXUIElementRef)raw,&actual)==kAXErrorSuccess && actual==wid;
    if (raw) CFRelease(raw);
    CFRelease(app); return ok;
}

static BOOL focusRexWindow(pid_t pid,uint32_t wid) {
    AXWindowIDFn getID=axWindowID();
    if (!AXIsProcessTrusted() || !getID) return NO;
    AXUIElementRef app=AXUIElementCreateApplication(pid);
    AXUIElementSetMessagingTimeout(app,0.3);
    CFTypeRef raw=NULL;
    AXError status=AXUIElementCopyAttributeValue(app,kAXWindowsAttribute,&raw);
    BOOL found=NO;
    if (status==kAXErrorSuccess && raw && CFGetTypeID(raw)==CFArrayGetTypeID()) {
        for (id element in (__bridge NSArray *)raw) {
            CGWindowID actual=0;
            AXUIElementRef window=(__bridge AXUIElementRef)element;
            if (getID(window,&actual)!=kAXErrorSuccess || actual!=wid) continue;
            AXUIElementSetAttributeValue(window,kAXMainAttribute,kCFBooleanTrue);
            AXUIElementPerformAction(window,kAXRaiseAction);
            [[NSRunningApplication runningApplicationWithProcessIdentifier:pid] activateWithOptions:0];
            found=YES; break;
        }
    }
    if (raw) CFRelease(raw);
    CFRelease(app); return found;
}

static NSArray *sourceVisibilityCandidates(uint32_t except,NSString *source) {
    NSMutableArray *out=[NSMutableArray array];
    CFArrayRef raw=CGWindowListCopyWindowInfo(kCGWindowListOptionOnScreenOnly,kCGNullWindowID);
    for (NSDictionary *entry in CFBridgingRelease(raw)) {
        uint32_t wid=[entry[(__bridge NSString *)kCGWindowNumber] unsignedIntValue];
        if (wid==except || [entry[(__bridge NSString *)kCGWindowLayer] intValue]!=0) continue;
        CGRect bounds=CGRectZero;
        if (!CGRectMakeWithDictionaryRepresentation((__bridge CFDictionaryRef)entry[(__bridge NSString *)kCGWindowBounds],&bounds)
            || bounds.size.width<100 || bounds.size.height<100 || ![spacesForWindow(wid) isEqual:@[source]]) continue;
        [out addObject:@{@"wid": @(wid),@"pid": entry[(__bridge NSString *)kCGWindowOwnerPID]}];
    }
    return out;
}

static BOOL sourceCandidatesHidden(NSArray *candidates) {
    for (NSDictionary *candidate in candidates) {
        NSDictionary *facts=windowFacts([candidate[@"wid"] unsignedIntValue],[candidate[@"pid"] intValue]);
        if (!facts || [facts[@"onScreen"] boolValue]) return NO;
    }
    return candidates.count>0;
}

static BOOL verifyFollow(pid_t pid,uint32_t wid,uint64_t space,NSArray *oldCandidates) {
    int matches=0;
    BOOL focusRequested=NO;
    for (int i=0;i<40;i++) {
        pump(0.1);
        if (activeSpace(connection)==space && !focusRequested) focusRequested=focusRexWindow(pid,wid);
        NSDictionary *facts=windowFacts(wid,pid);
        BOOL ok=activeSpace(connection)==space && [facts[@"onScreen"] boolValue]
            && [spacesForWindow(wid) isEqual:@[@(space).stringValue]]
            && [bridgeWindowSpaces(wid) isEqual:@[@(space).stringValue]]
            && focusedRexWindow(pid,wid) && (!oldCandidates || sourceCandidatesHidden(oldCandidates));
        matches=ok ? matches+1 : 0;
        if (matches>=2) return YES;
    }
    return NO;
}
