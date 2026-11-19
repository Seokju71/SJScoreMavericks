#import <AppKit/AppKit.h>
#import "sjscore_core.h"
#import "FontRegistrar.h"
#import "MainWindowController.h"

@interface SJAppDelegate : NSObject <NSApplicationDelegate>
@property (nonatomic, assign) SJEngine *engine;
@property (nonatomic, strong) SJMainWindowController *windowController;
@end

@implementation SJAppDelegate

- (void)setupMainMenu {
    NSMenu *mainMenu = [[NSMenu alloc] initWithTitle:@"MainMenu"];

    // App Menu
    NSMenuItem *appItem = [[NSMenuItem alloc] initWithTitle:@"SJScore" action:nil keyEquivalent:@""];
    NSMenu *appMenu = [[NSMenu alloc] initWithTitle:@"SJScore"];
    [appMenu addItemWithTitle:@"Quit SJScore" action:@selector(terminate:) keyEquivalent:@"q"];
    [appItem setSubmenu:appMenu];
    [mainMenu addItem:appItem];

    // File Menu
    NSMenuItem *fileItem = [[NSMenuItem alloc] initWithTitle:@"File" action:nil keyEquivalent:@""];
    NSMenu *fileMenu = [[NSMenu alloc] initWithTitle:@"File"];
    [fileMenu addItemWithTitle:@"Open Score (JSON)..." action:@selector(openJSONAction:) keyEquivalent:@"o"];
    [fileMenu addItemWithTitle:@"Save Score (JSON)..." action:@selector(saveJSONAction:) keyEquivalent:@"s"];
    [fileMenu addItem:[NSMenuItem separatorItem]];
    [fileMenu addItemWithTitle:@"Export Vector PDF..." action:@selector(exportPDFAction:) keyEquivalent:@"p"];
    [fileItem setSubmenu:fileMenu];
    [mainMenu addItem:fileItem];

    // Edit Menu
    NSMenuItem *editItem = [[NSMenuItem alloc] initWithTitle:@"Edit" action:nil keyEquivalent:@""];
    NSMenu *editMenu = [[NSMenu alloc] initWithTitle:@"Edit"];
    [editMenu addItemWithTitle:@"Copy" action:@selector(copyAction:) keyEquivalent:@"c"];
    [editMenu addItemWithTitle:@"Paste" action:@selector(pasteAction:) keyEquivalent:@"v"];
    [editItem setSubmenu:editMenu];
    [mainMenu addItem:editItem];

    [NSApp setMainMenu:mainMenu];
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    (void)notification;
    [SJFontRegistrar registerBundledFonts];
    self.engine = sj_engine_new();
    [self setupMainMenu];
    self.windowController = [[SJMainWindowController alloc] initWithEngine:self.engine];
    [self.windowController showWindow:self];
    [NSApp activateIgnoringOtherApps:YES];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    (void)sender;
    return YES;
}

- (void)applicationWillTerminate:(NSNotification *)notification {
    (void)notification;
    if (self.engine) {
        sj_engine_free(self.engine);
        self.engine = NULL;
    }
}

@end

int main(int argc, const char *argv[]) {
    (void)argc;
    (void)argv;
    @autoreleasepool {
        NSApplication *app = [NSApplication sharedApplication];
        [app setActivationPolicy:NSApplicationActivationPolicyRegular];
        SJAppDelegate *delegate = [[SJAppDelegate alloc] init];
        [app setDelegate:delegate];
        [app run];
    }
    return 0;
}
