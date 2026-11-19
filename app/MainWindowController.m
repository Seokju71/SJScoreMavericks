#import "MainWindowController.h"
#import "ScoreCanvasView.h"
#import "PDFExporter.h"
#import <QuartzCore/QuartzCore.h>
#import <math.h>

@interface SJColoredView : NSView
@property (nonatomic, strong) NSColor *bgColor;
@property (nonatomic, assign) CGFloat cornerRadius;
@end

@implementation SJColoredView
- (void)drawRect:(NSRect)dirtyRect {
    (void)dirtyRect;
    if (self.bgColor) {
        [self.bgColor setFill];
        if (self.cornerRadius > 0.0) {
            [[NSBezierPath bezierPathWithRoundedRect:self.bounds xRadius:self.cornerRadius yRadius:self.cornerRadius] fill];
        } else {
            NSRectFill(self.bounds);
        }
    }
}
@end

@interface SJCanvasContainerView : NSView
@property (nonatomic, strong) SJScoreCanvasView *canvasView;
@end

@implementation SJCanvasContainerView
- (BOOL)isFlipped { return YES; }

- (void)layoutCanvasForClipSize:(NSSize)clipSize {
    [self.canvasView updateCanvasSize];
    NSSize canvasSize = self.canvasView.frame.size;
    CGFloat pad = 32.0;
    CGFloat w = MAX(clipSize.width, canvasSize.width + pad * 2.0);
    CGFloat h = MAX(clipSize.height, canvasSize.height + pad * 2.0);
    [self setFrameSize:NSMakeSize(w, h)];

    CGFloat x = floor((w - canvasSize.width) / 2.0);
    CGFloat y = pad;
    [self.canvasView setFrameOrigin:NSMakePoint(x, y)];
}
@end

@interface SJMainWindowController () <SJScoreCanvasDelegate, NSTextFieldDelegate, NSWindowDelegate> {
    SJEngine *_engine;
    SJColoredView *_headerView;
    NSTextField *_titleField;
    NSButton *_transposeDownBtn;
    NSTextField *_transposeLabel;
    NSButton *_transposeUpBtn;
    NSButton *_transposeResetBtn;
    NSButton *_zoomOutBtn;
    NSTextField *_zoomLabel;
    NSButton *_zoomInBtn;
    NSButton *_openBtn;
    NSButton *_saveBtn;
    NSButton *_pdfBtn;
    NSButton *_prevPageBtn;
    NSTextField *_pageLabel;
    NSButton *_nextPageBtn;
    NSScrollView *_scrollView;
    SJCanvasContainerView *_containerView;
    SJScoreCanvasView *_canvasView;
    SJColoredView *_statusBadge;
    NSTextField *_statusLabel;
}
@end

@implementation SJMainWindowController

- (instancetype)initWithEngine:(SJEngine *)engine {
    NSUInteger styleMask = NSTitledWindowMask | NSClosableWindowMask | NSMiniaturizableWindowMask | NSResizableWindowMask;
    NSRect frame = NSMakeRect(0, 0, 1060, 780);
    NSWindow *window = [[NSWindow alloc] initWithContentRect:frame
                                                   styleMask:styleMask
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO];
    [window setTitle:@"SJScore"];
    [window setMinSize:NSMakeSize(960, 700)];
    [window center];

    self = [super initWithWindow:window];
    if (self) {
        _engine = engine;
        [window setDelegate:self];
        [self buildUI];
        [self syncUI];
    }
    return self;
}

- (NSButton *)makeToolbarButtonWithTitle:(NSString *)title width:(CGFloat)w action:(SEL)action tooltip:(NSString *)tip {
    NSButton *btn = [[NSButton alloc] initWithFrame:NSMakeRect(0, 0, w, 26)];
    [btn setTitle:title];
    [btn setBezelStyle:NSRoundedBezelStyle];
    [btn setButtonType:NSMomentaryPushInButton];
    [btn setFont:[NSFont systemFontOfSize:12.0]];
    [btn setTarget:self];
    [btn setAction:action];
    if (tip) [btn setToolTip:tip];
    return btn;
}

- (NSTextField *)makeLabelWithText:(NSString *)text font:(NSFont *)font color:(NSColor *)color align:(NSTextAlignment)align {
    NSTextField *tf = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 60, 20)];
    [tf setStringValue:text ?: @""];
    [tf setBezeled:NO];
    [tf setDrawsBackground:NO];
    [tf setEditable:NO];
    [tf setSelectable:NO];
    [tf setFont:font];
    [tf setTextColor:color];
    [tf setAlignment:align];
    return tf;
}

- (void)buildUI {
    NSView *root = [[self window] contentView];
    NSRect bounds = [root bounds];

    SJColoredView *bg = [[SJColoredView alloc] initWithFrame:bounds];
    bg.bgColor = [NSColor colorWithCalibratedRed:0.12 green:0.12 blue:0.12 alpha:1.0];
    [bg setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [root addSubview:bg];

    // Header bar (top, 54pt)
    CGFloat headerH = 54.0;
    _headerView = [[SJColoredView alloc] initWithFrame:NSMakeRect(0, bounds.size.height - headerH, bounds.size.width, headerH)];
    _headerView.bgColor = [NSColor colorWithCalibratedRed:0.15 green:0.15 blue:0.15 alpha:1.0];
    [_headerView setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
    [bg addSubview:_headerView];

    // Title field
    _titleField = [[NSTextField alloc] initWithFrame:NSMakeRect(18, 14, 220, 26)];
    [_titleField setFont:[NSFont systemFontOfSize:14.0]];
    [_titleField setDelegate:self];
    [_titleField setTarget:self];
    [_titleField setAction:@selector(titleFieldDidFinish:)];
    [_headerView addSubview:_titleField];

    // Transpose controls
    _transposeDownBtn = [self makeToolbarButtonWithTitle:@"-" width:30 action:@selector(transposeDownAction:) tooltip:@"Transpose Down"];
    _transposeLabel = [self makeLabelWithText:@"0"
                                         font:[NSFont fontWithName:@"Menlo-Bold" size:13.0] ?: [NSFont boldSystemFontOfSize:13.0]
                                        color:[NSColor lightGrayColor]
                                        align:NSCenterTextAlignment];
    _transposeUpBtn = [self makeToolbarButtonWithTitle:@"+" width:30 action:@selector(transposeUpAction:) tooltip:@"Transpose Up"];
    _transposeResetBtn = [self makeToolbarButtonWithTitle:@"Reset" width:52 action:@selector(transposeResetAction:) tooltip:@"Reset Transpose"];

    [_headerView addSubview:[self makeLabelWithText:@"Key" font:[NSFont systemFontOfSize:11.0] color:[NSColor lightGrayColor] align:NSRightTextAlignment]];
    [_headerView addSubview:_transposeDownBtn];
    [_headerView addSubview:_transposeLabel];
    [_headerView addSubview:_transposeUpBtn];
    [_headerView addSubview:_transposeResetBtn];

    // Zoom controls
    _zoomOutBtn = [self makeToolbarButtonWithTitle:@"-" width:30 action:@selector(zoomOutAction:) tooltip:@"Zoom Out"];
    _zoomLabel = [self makeLabelWithText:@"65%" font:[NSFont systemFontOfSize:12.0] color:[NSColor lightGrayColor] align:NSCenterTextAlignment];
    _zoomInBtn = [self makeToolbarButtonWithTitle:@"+" width:30 action:@selector(zoomInAction:) tooltip:@"Zoom In"];
    [_headerView addSubview:_zoomOutBtn];
    [_headerView addSubview:_zoomLabel];
    [_headerView addSubview:_zoomInBtn];

    // File & Export controls
    _openBtn = [self makeToolbarButtonWithTitle:@"Open" width:54 action:@selector(openJSONAction:) tooltip:@"Open Score (JSON)"];
    _saveBtn = [self makeToolbarButtonWithTitle:@"Save" width:54 action:@selector(saveJSONAction:) tooltip:@"Save Score (JSON)"];
    _pdfBtn = [self makeToolbarButtonWithTitle:@"PDF" width:48 action:@selector(exportPDFAction:) tooltip:@"Export Vector PDF"];
    [_headerView addSubview:_openBtn];
    [_headerView addSubview:_saveBtn];
    [_headerView addSubview:_pdfBtn];

    // Page controls
    _prevPageBtn = [self makeToolbarButtonWithTitle:@"<" width:30 action:@selector(prevPageAction:) tooltip:@"Previous Page"];
    _pageLabel = [self makeLabelWithText:@"Page 1 / 1" font:[NSFont systemFontOfSize:12.0] color:[NSColor lightGrayColor] align:NSCenterTextAlignment];
    _nextPageBtn = [self makeToolbarButtonWithTitle:@">" width:30 action:@selector(nextPageAction:) tooltip:@"Next Page"];
    [_headerView addSubview:_prevPageBtn];
    [_headerView addSubview:_pageLabel];
    [_headerView addSubview:_nextPageBtn];

    [self layoutHeaderControls];

    // ScrollView + Canvas
    NSRect scrollFrame = NSMakeRect(0, 0, bounds.size.width, bounds.size.height - headerH);
    _scrollView = [[NSScrollView alloc] initWithFrame:scrollFrame];
    [_scrollView setHasVerticalScroller:YES];
    [_scrollView setHasHorizontalScroller:YES];
    [_scrollView setDrawsBackground:YES];
    [_scrollView setBackgroundColor:[NSColor colorWithCalibratedRed:0.12 green:0.12 blue:0.12 alpha:1.0]];
    [_scrollView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [bg addSubview:_scrollView];

    _canvasView = [[SJScoreCanvasView alloc] initWithEngine:_engine];
    _canvasView.delegate = self;
    [_canvasView setWantsLayer:YES];
    NSShadow *shadow = [[NSShadow alloc] init];
    [shadow setShadowColor:[NSColor colorWithCalibratedWhite:0.0 alpha:0.5]];
    [shadow setShadowOffset:NSMakeSize(0, -6)];
    [shadow setShadowBlurRadius:14.0];
    [_canvasView setShadow:shadow];

    _containerView = [[SJCanvasContainerView alloc] initWithFrame:scrollFrame];
    _containerView.canvasView = _canvasView;
    [_containerView addSubview:_canvasView];
    [_scrollView setDocumentView:_containerView];

    // Status overlay badge (bottom-left)
    _statusBadge = [[SJColoredView alloc] initWithFrame:NSMakeRect(14, 14, 340, 28)];
    _statusBadge.bgColor = [NSColor colorWithCalibratedWhite:0.0 alpha:0.72];
    _statusBadge.cornerRadius = 6.0;
    [_statusBadge setAutoresizingMask:(NSViewMaxXMargin | NSViewMaxYMargin)];
    [_statusBadge setHidden:YES];

    _statusLabel = [self makeLabelWithText:@"" font:[NSFont systemFontOfSize:11.5] color:[NSColor whiteColor] align:NSLeftTextAlignment];
    [_statusLabel setFrame:NSMakeRect(10, 5, 320, 18)];
    [_statusBadge addSubview:_statusLabel];
    [bg addSubview:_statusBadge];
}

- (void)layoutHeaderControls {
    CGFloat w = _headerView.bounds.size.width;
    CGFloat yBtn = 14.0;
    CGFloat yLbl = 17.0;

    // Right-to-left layout for right groups
    CGFloat rx = w - 16.0;

    rx -= 30.0; [_nextPageBtn setFrame:NSMakeRect(rx, yBtn, 30, 26)];
    rx -= 76.0; [_pageLabel setFrame:NSMakeRect(rx, yLbl, 74, 20)];
    rx -= 32.0; [_prevPageBtn setFrame:NSMakeRect(rx, yBtn, 30, 26)];

    rx -= 16.0;
    rx -= 48.0; [_pdfBtn setFrame:NSMakeRect(rx, yBtn, 48, 26)];
    rx -= 58.0; [_saveBtn setFrame:NSMakeRect(rx, yBtn, 54, 26)];
    rx -= 58.0; [_openBtn setFrame:NSMakeRect(rx, yBtn, 54, 26)];

    rx -= 16.0;
    rx -= 30.0; [_zoomInBtn setFrame:NSMakeRect(rx, yBtn, 30, 26)];
    rx -= 46.0; [_zoomLabel setFrame:NSMakeRect(rx, yLbl, 44, 20)];
    rx -= 32.0; [_zoomOutBtn setFrame:NSMakeRect(rx, yBtn, 30, 26)];

    // Center-left: Transpose group
    CGFloat tx = 260.0;
    if (tx + 200.0 > rx - 16.0) {
        tx = MAX(246.0, rx - 210.0);
    }
    NSView *keyLbl = _headerView.subviews[1]; // "Key" label
    [keyLbl setFrame:NSMakeRect(tx, yLbl, 28, 20)];
    [_transposeDownBtn setFrame:NSMakeRect(tx + 32, yBtn, 30, 26)];
    [_transposeLabel setFrame:NSMakeRect(tx + 64, yLbl, 36, 20)];
    [_transposeUpBtn setFrame:NSMakeRect(tx + 102, yBtn, 30, 26)];
    [_transposeResetBtn setFrame:NSMakeRect(tx + 136, yBtn, 52, 26)];
}

- (void)syncUI {
    char *rawTitle = sj_engine_get_title(_engine);
    NSString *title = rawTitle ? [NSString stringWithUTF8String:rawTitle] : @"";
    sj_free_string(rawTitle);
    if (![[_titleField stringValue] isEqualToString:title]) {
        [_titleField setStringValue:title];
    }

    int tr = sj_engine_get_transpose(_engine);
    [_transposeLabel setStringValue:(tr > 0 ? [NSString stringWithFormat:@"+%d", tr] : [NSString stringWithFormat:@"%d", tr])];
    [_transposeLabel setTextColor:(tr == 0 ? [NSColor lightGrayColor] : [NSColor colorWithCalibratedRed:0.3 green:0.9 blue:0.4 alpha:1.0])];
    [_transposeDownBtn setEnabled:(tr > -11)];
    [_transposeUpBtn setEnabled:(tr < 11)];
    [_transposeResetBtn setEnabled:(tr != 0)];

    int zoomPct = (int)llround(sj_engine_get_zoom(_engine) * 100.0);
    [_zoomLabel setStringValue:[NSString stringWithFormat:@"%d%%", zoomPct]];

    int viewPage = sj_engine_get_view_page(_engine);
    int totalPages = sj_engine_get_total_pages(_engine);
    int maxPages = sj_engine_get_max_pages();
    [_pageLabel setStringValue:[NSString stringWithFormat:@"Page %d / %d", viewPage + 1, totalPages]];
    [_prevPageBtn setEnabled:(viewPage > 0)];
    [_nextPageBtn setEnabled:(viewPage < maxPages - 1)];

    [_containerView layoutCanvasForClipSize:_scrollView.contentView.bounds.size];
    [_canvasView setNeedsDisplay:YES];

    BOOL readOnly = (sj_engine_is_read_only(_engine) != 0);
    char *rawStatus = sj_engine_get_status(_engine);
    NSString *status = rawStatus ? [NSString stringWithUTF8String:rawStatus] : @"";
    sj_free_string(rawStatus);

    if (readOnly || status.length > 0) {
        NSString *combined = @"";
        if (readOnly && status.length > 0) {
            combined = [NSString stringWithFormat:@"[Read-Only Transpose Preview]  %@", status];
        } else if (readOnly) {
            combined = @"[Read-Only Transpose Preview]";
        } else {
            combined = status;
        }
        [_statusLabel setStringValue:combined];
        [_statusLabel setTextColor:(readOnly ? [NSColor orangeColor] : [NSColor whiteColor])];
        [_statusLabel sizeToFit];
        CGFloat badgeW = _statusLabel.frame.size.width + 20.0;
        [_statusBadge setFrame:NSMakeRect(14, 14, MAX(140.0, badgeW), 28)];
        [_statusLabel setFrame:NSMakeRect(10, 5, badgeW - 20.0, 18)];
        [_statusBadge setHidden:NO];
    } else {
        [_statusBadge setHidden:YES];
    }
}

#pragma mark - Delegates

- (void)windowDidResize:(NSNotification *)notification {
    (void)notification;
    [self layoutHeaderControls];
    [_containerView layoutCanvasForClipSize:_scrollView.contentView.bounds.size];
}

- (void)controlTextDidChange:(NSNotification *)obj {
    if ([obj object] == _titleField) {
        sj_engine_set_title(_engine, [[_titleField stringValue] UTF8String]);
        [_canvasView setNeedsDisplay:YES];
    }
}

- (void)titleFieldDidFinish:(id)sender {
    (void)sender;
    sj_engine_set_editing_title(_engine, 0);
    [[self window] makeFirstResponder:_canvasView];
    [_canvasView setNeedsDisplay:YES];
}

- (void)scoreCanvasDidMutateState {
    [self syncUI];
}

- (void)scoreCanvasDidRequestTitleEdit {
    [[self window] makeFirstResponder:_titleField];
}

#pragma mark - Actions

- (void)transposeDownAction:(id)sender {
    (void)sender;
    sj_engine_set_transpose(_engine, sj_engine_get_transpose(_engine) - 1);
    [[self window] makeFirstResponder:_canvasView];
    [self syncUI];
}

- (void)transposeUpAction:(id)sender {
    (void)sender;
    sj_engine_set_transpose(_engine, sj_engine_get_transpose(_engine) + 1);
    [[self window] makeFirstResponder:_canvasView];
    [self syncUI];
}

- (void)transposeResetAction:(id)sender {
    (void)sender;
    sj_engine_set_transpose(_engine, 0);
    [[self window] makeFirstResponder:_canvasView];
    [self syncUI];
}

- (void)zoomOutAction:(id)sender {
    (void)sender;
    sj_engine_zoom_out(_engine);
    [[self window] makeFirstResponder:_canvasView];
    [self syncUI];
}

- (void)zoomInAction:(id)sender {
    (void)sender;
    sj_engine_zoom_in(_engine);
    [[self window] makeFirstResponder:_canvasView];
    [self syncUI];
}

- (void)prevPageAction:(id)sender {
    (void)sender;
    sj_engine_prev_page(_engine);
    [[self window] makeFirstResponder:_canvasView];
    [self syncUI];
}

- (void)nextPageAction:(id)sender {
    (void)sender;
    sj_engine_next_page(_engine);
    [[self window] makeFirstResponder:_canvasView];
    [self syncUI];
}

- (void)copyAction:(id)sender {
    (void)sender;
    sj_engine_copy_selection(_engine);
    [self syncUI];
}

- (void)pasteAction:(id)sender {
    (void)sender;
    sj_engine_paste_clipboard(_engine);
    [self syncUI];
}

- (void)openJSONAction:(id)sender {
    (void)sender;
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    [panel setAllowedFileTypes:@[@"json"]];
    [panel setAllowsMultipleSelection:NO];
    [panel setCanChooseDirectories:NO];
    if ([panel runModal] != NSFileHandlingPanelOKButton) return;
    NSURL *url = [panel URL];
    if (!url) return;

    NSError *err = nil;
    NSString *jsonStr = [NSString stringWithContentsOfURL:url encoding:NSUTF8StringEncoding error:&err];
    if (!jsonStr) {
        NSString *msg = [NSString stringWithFormat:@"Failed to read file: %@", err.localizedDescription];
        sj_engine_set_status(_engine, [msg UTF8String]);
    } else {
        sj_engine_load_json(_engine, [jsonStr UTF8String], [[url lastPathComponent] UTF8String]);
    }
    [[self window] makeFirstResponder:_canvasView];
    [self syncUI];
}

- (void)saveJSONAction:(id)sender {
    (void)sender;
    NSSavePanel *panel = [NSSavePanel savePanel];
    [panel setAllowedFileTypes:@[@"json"]];

    char *rawTitle = sj_engine_get_title(_engine);
    NSString *title = (rawTitle && rawTitle[0] != '\0') ? [NSString stringWithUTF8String:rawTitle] : @"score";
    sj_free_string(rawTitle);
    [panel setNameFieldStringValue:[NSString stringWithFormat:@"%@.json", title]];

    if ([panel runModal] != NSFileHandlingPanelOKButton) return;
    NSURL *url = [panel URL];
    if (!url) return;

    char *jsonC = sj_engine_save_json(_engine, [[url lastPathComponent] UTF8String]);
    NSString *jsonStr = jsonC ? [NSString stringWithUTF8String:jsonC] : @"{}";
    sj_free_string(jsonC);

    NSError *err = nil;
    if (![jsonStr writeToURL:url atomically:YES encoding:NSUTF8StringEncoding error:&err]) {
        NSString *msg = [NSString stringWithFormat:@"Failed to save JSON: %@", err.localizedDescription];
        sj_engine_set_status(_engine, [msg UTF8String]);
    }
    [[self window] makeFirstResponder:_canvasView];
    [self syncUI];
}

- (void)exportPDFAction:(id)sender {
    (void)sender;
    NSSavePanel *panel = [NSSavePanel savePanel];
    [panel setAllowedFileTypes:@[@"pdf"]];

    char *rawTitle = sj_engine_get_title(_engine);
    NSString *title = (rawTitle && rawTitle[0] != '\0') ? [NSString stringWithUTF8String:rawTitle] : @"score";
    sj_free_string(rawTitle);
    [panel setNameFieldStringValue:[NSString stringWithFormat:@"%@.pdf", title]];

    if ([panel runModal] != NSFileHandlingPanelOKButton) return;
    NSURL *url = [panel URL];
    if (!url) return;

    NSError *err = nil;
    if ([SJPDFExporter exportEngine:_engine transpose:sj_engine_get_transpose(_engine) toURL:url error:&err]) {
        NSString *msg = [NSString stringWithFormat:@"Exported vector PDF: %@", [url lastPathComponent]];
        sj_engine_set_status(_engine, [msg UTF8String]);
    } else {
        NSString *msg = [NSString stringWithFormat:@"Failed to export PDF: %@", err.localizedDescription];
        sj_engine_set_status(_engine, [msg UTF8String]);
    }
    [[self window] makeFirstResponder:_canvasView];
    [self syncUI];
}

@end
