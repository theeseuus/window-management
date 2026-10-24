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
