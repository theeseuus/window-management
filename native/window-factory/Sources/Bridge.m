// Query signatures/masks follow MIT-licensed Hammerspoon 1.1.1 spaces.
// See native/space-helper/THIRD_PARTY_NOTICES.md. No Space mutation here.
#import "Bridge.h"
#include <dlfcn.h>
typedef int (*MainFn)(void);
typedef CFArrayRef (*DisplaysFn)(int);
typedef int (*TypeFn)(int,uint64_t);
typedef CFArrayRef (*MembershipFn)(int,int,CFArrayRef);
typedef AXError (*WindowIDFn)(AXUIElementRef,CGWindowID *);
static void *handle;
static MainFn connection;
static DisplaysFn displays;
static TypeFn spaceType;
static MembershipFn membership;
static WindowIDFn getWindowID;
static void load(void) {
    static dispatch_once_t once;
    dispatch_once(&once,^{
        handle=dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight",RTLD_LAZY|RTLD_LOCAL);
        if (!handle) return;
        connection=(MainFn)dlsym(handle,"SLSMainConnectionID");
        displays=(DisplaysFn)dlsym(handle,"SLSCopyManagedDisplaySpaces");
        spaceType=(TypeFn)dlsym(handle,"SLSSpaceGetType");
        membership=(MembershipFn)dlsym(handle,"SLSCopySpacesForWindows");
        getWindowID=(WindowIDFn)dlsym(RTLD_DEFAULT,"_AXUIElementGetWindow");
    });
}
BOOL WFContext(CGDirectDisplayID display,uint64_t *space,int *type) {
    load(); if (!handle || !connection || !displays || !spaceType) return NO;
    CFUUIDRef uuid=CGDisplayCreateUUIDFromDisplayID(display);
    if (!uuid) return NO;
    NSString *identifier=CFBridgingRelease(CFUUIDCreateString(NULL,uuid)); CFRelease(uuid);
    NSArray *list=CFBridgingRelease(displays(connection()));
    if (![list isKindOfClass:NSArray.class]) return NO;
    for (id object in list) {
        if (![object isKindOfClass:NSDictionary.class]) return NO;
        NSDictionary *entry=object;
        if (![entry[@"Display Identifier"] isEqual:identifier] && ![entry[@"Display Identifier"] isEqual:@"Main"]) continue;
        id current=entry[@"Current Space"];
        if (![current isKindOfClass:NSDictionary.class]) return NO;
        NSNumber *sid=current[@"ManagedSpaceID"];
        if (![sid isKindOfClass:NSNumber.class] || !sid.unsignedLongLongValue) return NO;
        *space=sid.unsignedLongLongValue; *type=spaceType(connection(),*space); return YES;
    }
    return NO;
}
NSArray *WFWindowSpaces(CGWindowID window) {
    load(); if (!handle || !connection || !membership) return nil;
    CFArrayRef raw=membership(connection(),7,(__bridge CFArrayRef)@[@(window)]);
    NSArray *spaces=CFBridgingRelease(raw);
    if (![spaces isKindOfClass:NSArray.class]) return nil;
    for (id item in spaces) if (![item isKindOfClass:NSNumber.class]) return nil;
    return spaces;
}
CGWindowID WFWindowID(AXUIElementRef window) {
    load(); CGWindowID wid=0;
    return getWindowID && getWindowID(window,&wid)==kAXErrorSuccess ? wid : 0;
}
BOOL WFReadFrame(AXUIElementRef window,CGRect *frame) {
    CFTypeRef p=NULL,s=NULL;
    AXError pe=AXUIElementCopyAttributeValue(window,kAXPositionAttribute,&p);
    AXError se=AXUIElementCopyAttributeValue(window,kAXSizeAttribute,&s);
    CGPoint point; CGSize size;
    BOOL ok=pe==0 && se==0 && p && s && CFGetTypeID(p)==AXValueGetTypeID() && CFGetTypeID(s)==AXValueGetTypeID()
        && AXValueGetValue((AXValueRef)p,kAXValueCGPointType,&point)
        && AXValueGetValue((AXValueRef)s,kAXValueCGSizeType,&size);
    if (p) CFRelease(p); if (s) CFRelease(s);
    if (ok) *frame=(CGRect){point,size}; return ok;
}
AXError WFSetPosition(AXUIElementRef window,CGPoint position) {
    AXValueRef value=AXValueCreate(kAXValueCGPointType,&position);
    AXError error=AXUIElementSetAttributeValue(window,kAXPositionAttribute,value); CFRelease(value); return error;
}
AXError WFSetSize(AXUIElementRef window,CGSize size) {
    AXValueRef value=AXValueCreate(kAXValueCGSizeType,&size);
    AXError error=AXUIElementSetAttributeValue(window,kAXSizeAttribute,value); CFRelease(value); return error;
}
