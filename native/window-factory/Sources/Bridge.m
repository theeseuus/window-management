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

// Scoped Enhanced UI handling follows the Hammerspoon 1.1.1 frame helper.
// Unsupported attributes are left alone; never leave an app's setting changed.
AXError WFApplyDirectFrame(AXUIElementRef window,CGRect frame) {
    CGRect current=CGRectZero;
    if (WFReadFrame(window,&current) && fabs(current.size.width-frame.size.width)<=2
        && fabs(current.size.height-frame.size.height)<=2) return WFSetPosition(window,frame.origin);
    pid_t pid=0; AXUIElementGetPid(window,&pid);
    AXUIElementRef app=AXUIElementCreateApplication(pid);
    CFTypeRef enhanced=NULL; BOOL changed=NO;
    if (AXUIElementCopyAttributeValue(app,CFSTR("AXEnhancedUserInterface"),&enhanced)==kAXErrorSuccess
        && enhanced && CFGetTypeID(enhanced)==CFBooleanGetTypeID() && CFBooleanGetValue(enhanced)) {
        changed=AXUIElementSetAttributeValue(app,CFSTR("AXEnhancedUserInterface"),kCFBooleanFalse)==kAXErrorSuccess;
    }
    AXError first=WFSetSize(window,frame.size);
    AXError position=WFSetPosition(window,frame.origin);
    AXError last=WFSetSize(window,frame.size);
    if (changed) AXUIElementSetAttributeValue(app,CFSTR("AXEnhancedUserInterface"),kCFBooleanTrue);
    if (enhanced) CFRelease(enhanced);
    CFRelease(app);
    return first ? first : position ? position : last;
}

#import <Carbon/Carbon.h>
static EventHotKeyRef wfKeys[64];
static EventHandlerRef wfHandler;
static WFHotKeyCallback wfKeyCallback;
static void *wfKeyContext;
static OSStatus wfHotKeyEvent(EventHandlerCallRef next,EventRef event,void *context) {
    (void)next; (void)context;
    EventHotKeyID hotkey={0};
    OSStatus status=GetEventParameter(event,kEventParamDirectObject,typeEventHotKeyID,NULL,sizeof(hotkey),NULL,&hotkey);
    if (status!=noErr || hotkey.signature!='WFGC' || !wfKeyCallback) return eventNotHandledErr;
    wfKeyCallback(hotkey.id,wfKeyContext); return noErr;
}
void WFUnregisterHotKeys(void) {
    for (unsigned i=0;i<64;i++) if (wfKeys[i]) { UnregisterEventHotKey(wfKeys[i]); wfKeys[i]=NULL; }
    if (wfHandler) { RemoveEventHandler(wfHandler); wfHandler=NULL; }
    wfKeyCallback=NULL; wfKeyContext=NULL;
}
int32_t WFRegisterHotKeys(const uint32_t *keys,const uint32_t *modifiers,uint32_t count,
                         WFHotKeyCallback callback,void *context,uint32_t *failedIndex) {
    WFUnregisterHotKeys(); *failedIndex=0;
    if (!count || count>64) return paramErr;
    EventTypeSpec type={kEventClassKeyboard,kEventHotKeyPressed};
    OSStatus result=InstallEventHandler(GetApplicationEventTarget(),wfHotKeyEvent,1,&type,NULL,&wfHandler);
    if (result!=noErr) return result;
    wfKeyCallback=callback; wfKeyContext=context;
    for (uint32_t i=0;i<count;i++) {
        EventHotKeyID id={'WFGC',i};
        result=RegisterEventHotKey(keys[i],modifiers[i],id,GetApplicationEventTarget(),kEventHotKeyExclusive,&wfKeys[i]);
        if (result!=noErr) { *failedIndex=i; WFUnregisterHotKeys(); return result; }
    }
    return noErr;
}

// Directional focus has an independent registry and event signature.
static EventHotKeyRef wfFocusKeys[4];
static EventHandlerRef wfFocusHandler;
static WFHotKeyCallback wfFocusCallback;
static void *wfFocusContext;
static OSStatus wfFocusEvent(EventHandlerCallRef next,EventRef event,void *context) {
    (void)next; (void)context; EventHotKeyID key={0};
    OSStatus status=GetEventParameter(event,kEventParamDirectObject,typeEventHotKeyID,NULL,sizeof(key),NULL,&key);
    if (status!=noErr || key.signature!='WFFC' || !wfFocusCallback) return eventNotHandledErr;
    wfFocusCallback(key.id,wfFocusContext); return noErr;
}
void WFUnregisterFocusHotKeys(void) {
    for(unsigned i=0;i<4;i++) if(wfFocusKeys[i]) { UnregisterEventHotKey(wfFocusKeys[i]); wfFocusKeys[i]=NULL; }
    if(wfFocusHandler) { RemoveEventHandler(wfFocusHandler); wfFocusHandler=NULL; }
    wfFocusCallback=NULL; wfFocusContext=NULL;
}
int32_t WFRegisterFocusHotKeys(const uint32_t *keys,uint32_t count,WFHotKeyCallback callback,void *context,uint32_t *failedIndex) {
    WFUnregisterFocusHotKeys(); *failedIndex=0;
    if(count!=4) return paramErr;
    EventTypeSpec type={kEventClassKeyboard,kEventHotKeyPressed};
    OSStatus status=InstallEventHandler(GetApplicationEventTarget(),wfFocusEvent,1,&type,NULL,&wfFocusHandler);
    if(status!=noErr) return status;
    wfFocusCallback=callback; wfFocusContext=context;
    for(unsigned i=0;i<count;i++) {
        EventHotKeyID key={'WFFC',i};
        status=RegisterEventHotKey(keys[i],cmdKey|optionKey|controlKey,key,GetApplicationEventTarget(),0,&wfFocusKeys[i]);
        if(status!=noErr) { *failedIndex=i; WFUnregisterFocusHotKeys(); return status; }
    }
    return noErr;
}

int32_t WFRequestWindowFocus(AXUIElementRef window,pid_t pid,int32_t *mainStatus,int32_t *raiseStatus) {
    pid_t actual=0;
    AXError identity=AXUIElementGetPid(window,&actual);
    *mainStatus=kAXErrorFailure; *raiseStatus=kAXErrorFailure;
    if(identity!=kAXErrorSuccess || actual!=pid) return paramErr;
    *mainStatus=AXUIElementSetAttributeValue(window,kAXMainAttribute,kCFBooleanTrue);
    // Raise is useful where supported, but some apps reject it. It must not
    // prevent the front-window activation used by the original Spoon.
    *raiseStatus=AXUIElementPerformAction(window,kAXRaiseAction);
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    ProcessSerialNumber psn={0,0};
    OSStatus status=GetProcessForPID(pid,&psn);
    if(status==noErr) status=SetFrontProcessWithOptions(&psn,kSetFrontProcessFrontWindowOnly);
#pragma clang diagnostic pop
    // Preserve the selected window when activation chooses an app's old main
    // window (notably Finder). Never activate all windows or another Space.
    if(status==noErr) AXUIElementSetAttributeValue(window,kAXMainAttribute,kCFBooleanTrue);
    return status;
}
