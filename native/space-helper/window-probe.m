// Disposable foreign-process target. No window-control or private APIs.
#import <Cocoa/Cocoa.h>
#include <fcntl.h>
#include <unistd.h>

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc!=2 || strcmp(argv[1],"disposable-host")!=0) return 64;
        [NSApplication sharedApplication];
        [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
        NSScreen *screen=NSScreen.mainScreen;
        if (!screen) return 69;
        NSRect frame=screen.visibleFrame;
        NSWindow *window=[[NSWindow alloc] initWithContentRect:
            NSMakeRect(NSMidX(frame)-180,NSMidY(frame)-65,360,130)
            styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskClosable
            backing:NSBackingStoreBuffered defer:NO];
        window.releasedWhenClosed=NO;
        window.title=@"Window Factory — foreign-process disposable probe";
        NSTextField *label=[NSTextField wrappingLabelWithString:
            @"Separate test application\nThis empty window closes automatically.\nExisting application windows are untouched."];
        label.frame=NSMakeRect(20,20,320,90);
        [window.contentView addSubview:label];
        @try {
            [window orderFrontRegardless];
            NSDate *ready=[NSDate dateWithTimeIntervalSinceNow:0.5];
            while (ready.timeIntervalSinceNow>0)
                [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];
            printf("{\"windowID\":\"%ld\",\"pid\":%d}\n",(long)window.windowNumber,getpid());
            fflush(stdout);
            fcntl(STDIN_FILENO,F_SETFL,fcntl(STDIN_FILENO,F_GETFL)|O_NONBLOCK);
            NSDate *deadline=[NSDate dateWithTimeIntervalSinceNow:12];
            while (deadline.timeIntervalSinceNow>0) {
                char command;
                ssize_t count=read(STDIN_FILENO,&command,1);
                if (count==0 || (count>0 && command=='q')) break;
                [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];
            }
        } @finally { [window close]; }
        return 0;
    }
}
