#import <Cocoa/Cocoa.h>
#import <ApplicationServices/ApplicationServices.h>
NS_ASSUME_NONNULL_BEGIN

BOOL WFContext(CGDirectDisplayID display, uint64_t *space, int *type);
NSArray<NSNumber *> * _Nullable WFWindowSpaces(CGWindowID window);
CGWindowID WFWindowID(AXUIElementRef _Nonnull window);
BOOL WFReadFrame(AXUIElementRef _Nonnull window, CGRect * _Nonnull frame);
AXError WFSetPosition(AXUIElementRef _Nonnull window, CGPoint position);
AXError WFSetSize(AXUIElementRef _Nonnull window, CGSize size);
NS_ASSUME_NONNULL_END
