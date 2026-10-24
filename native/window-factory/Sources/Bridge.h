#import <Cocoa/Cocoa.h>
#import <ApplicationServices/ApplicationServices.h>
NS_ASSUME_NONNULL_BEGIN

BOOL WFContext(CGDirectDisplayID display, uint64_t *space, int *type);
NSArray<NSNumber *> * _Nullable WFWindowSpaces(CGWindowID window);
CGWindowID WFWindowID(AXUIElementRef _Nonnull window);
BOOL WFReadFrame(AXUIElementRef _Nonnull window, CGRect * _Nonnull frame);
AXError WFSetPosition(AXUIElementRef _Nonnull window, CGPoint position);
AXError WFSetSize(AXUIElementRef _Nonnull window, CGSize size);
AXError WFApplyDirectFrame(AXUIElementRef window, CGRect frame);
NS_ASSUME_NONNULL_END

// Exclusive Carbon hotkeys; the callback is delivered on the AppKit event loop.
typedef void (*WFHotKeyCallback)(uint32_t index, void * _Nonnull context);
int32_t WFRegisterHotKeys(const uint32_t * _Nonnull keys, const uint32_t * _Nonnull modifiers,
                         uint32_t count, WFHotKeyCallback _Nonnull callback, void * _Nonnull context,
                         uint32_t * _Nonnull failedIndex);
void WFUnregisterHotKeys(void);

// Independent directional-focus group; never releases geometry registrations.
int32_t WFRegisterFocusHotKeys(const uint32_t * _Nonnull keys,uint32_t count,
    WFHotKeyCallback _Nonnull callback,void * _Nonnull context,uint32_t * _Nonnull failedIndex);
void WFUnregisterFocusHotKeys(void);

// Hammerspoon-compatible front-window activation; exact focus is verified by caller.
int32_t WFRequestWindowFocus(AXUIElementRef _Nonnull window,pid_t pid,
    int32_t * _Nonnull mainStatus,int32_t * _Nonnull raiseStatus);

int32_t WFRegisterStashHotKey(WFHotKeyCallback _Nonnull callback,void * _Nonnull context);
void WFUnregisterStashHotKey(void);

int32_t WFSpaceKind(uint64_t space);
int32_t WFRegisterSwitcherHotKeys(WFHotKeyCallback _Nonnull callback,void * _Nonnull context,uint32_t * _Nonnull failedIndex);
int32_t WFSetSwitcherEscape(BOOL enabled);
void WFUnregisterSwitcherHotKeys(void);

// Switcher-only census and intentional desktop selection. Never move a window.
NSArray<NSDictionary *> * _Nullable WFSwitcherSpaces(CGDirectDisplayID display);
NSArray<NSNumber *> * _Nullable WFSwitcherSpaceWindows(uint64_t space,BOOL onlyUp);
BOOL WFSwitcherSelectSpace(CGDirectDisplayID display,uint64_t expectedSource,uint64_t destination);

int32_t WFRegisterAccordionHotKey(WFHotKeyCallback _Nonnull callback,void * _Nonnull context);
void WFUnregisterAccordionHotKey(void);

BOOL WFSpaceMoveAvailable(void);
BOOL WFMoveWindowToAdjacentSpace(AXUIElementRef _Nonnull window,pid_t pid,CGDirectDisplayID display,uint64_t source,uint64_t destination);
int32_t WFRegisterSpaceMoveHotKeys(WFHotKeyCallback _Nonnull callback,void * _Nonnull context,uint32_t * _Nonnull failedIndex);
void WFUnregisterSpaceMoveHotKeys(void);
