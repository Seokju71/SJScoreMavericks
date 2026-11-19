#import <AppKit/AppKit.h>
#import "sjscore_core.h"

@interface SJMainWindowController : NSWindowController

- (instancetype)initWithEngine:(SJEngine *)engine;

- (void)openJSONAction:(id)sender;
- (void)saveJSONAction:(id)sender;
- (void)exportPDFAction:(id)sender;
- (void)copyAction:(id)sender;
- (void)pasteAction:(id)sender;

@end
