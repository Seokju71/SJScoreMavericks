#import "ScoreCanvasView.h"
#import "ScoreRenderer.h"

@interface SJScoreCanvasView () {
    int _dragAnchorIndex;
}
@end

@implementation SJScoreCanvasView

- (instancetype)initWithEngine:(SJEngine *)engine {
    SJLayoutMetrics layout;
    sj_engine_get_layout(engine, &layout);
    double zoom = sj_engine_get_zoom(engine);
    NSRect frame = NSMakeRect(0, 0, layout.canvasWidth * zoom, layout.canvasHeight * zoom);
    self = [super initWithFrame:frame];
    if (self) {
        _engine = engine;
        _dragAnchorIndex = -1;
    }
    return self;
}

- (void)updateCanvasSize {
    SJLayoutMetrics layout;
    sj_engine_get_layout(_engine, &layout);
    double zoom = sj_engine_get_zoom(_engine);
    [self setFrameSize:NSMakeSize(layout.canvasWidth * zoom, layout.canvasHeight * zoom)];
    [self setNeedsDisplay:YES];
}

- (BOOL)isFlipped {
    return YES;
}

- (BOOL)acceptsFirstResponder {
    return YES;
}

- (void)viewDidMoveToWindow {
    [super viewDidMoveToWindow];
    [[self window] makeFirstResponder:self];
}

- (void)drawRect:(NSRect)dirtyRect {
    (void)dirtyRect;
    NSGraphicsContext *nsCtx = [NSGraphicsContext currentContext];
    if (!nsCtx) return;
    // graphicsPort works from OS X 10.0 through modern macOS (CGContext is 10.10+)
    CGContextRef ctx = (CGContextRef)[nsCtx graphicsPort];
    if (!ctx) return;

    double zoom = sj_engine_get_zoom(_engine);
    CGContextSaveGState(ctx);
    CGContextScaleCTM(ctx, zoom, zoom);

    [SJScoreRenderer drawInContext:ctx
                            engine:_engine
                         pageIndex:sj_engine_get_view_page(_engine)
                         transpose:sj_engine_get_transpose(_engine)
                    isEditingTitle:(sj_engine_is_editing_title(_engine) != 0)
             showInteractiveChrome:YES];

    CGContextRestoreGState(ctx);
}

#pragma mark - Mouse Interaction

- (NSPoint)canvasPointFromEvent:(NSEvent *)event {
    NSPoint local = [self convertPoint:[event locationInWindow] fromView:nil];
    double zoom = sj_engine_get_zoom(_engine);
    return NSMakePoint(local.x / zoom, local.y / zoom);
}

- (void)mouseDown:(NSEvent *)event {
    [[self window] makeFirstResponder:self];
    NSPoint pt = [self canvasPointFromEvent:event];
    _dragAnchorIndex = sj_engine_mouse_down(_engine, pt.x, pt.y);
    if (sj_engine_is_editing_title(_engine)) {
        [self.delegate scoreCanvasDidRequestTitleEdit];
    }
    [self setNeedsDisplay:YES];
    [self.delegate scoreCanvasDidMutateState];
}

- (void)mouseDragged:(NSEvent *)event {
    if (_dragAnchorIndex < 0) return;
    NSPoint pt = [self canvasPointFromEvent:event];
    sj_engine_mouse_drag(_engine, _dragAnchorIndex, pt.x, pt.y);
    [self setNeedsDisplay:YES];
}

- (void)mouseUp:(NSEvent *)event {
    (void)event;
    _dragAnchorIndex = -1;
}

#pragma mark - Keyboard Interaction (Hardware KeyCode for Korean IME immunity)

- (char)chordCharacterForKeyCode:(unsigned short)keyCode shift:(BOOL)shift {
    char lower = 0;
    switch (keyCode) {
        case 0:  lower = 'a'; break;
        case 11: lower = 'b'; break;
        case 8:  lower = 'c'; break;
        case 2:  lower = 'd'; break;
        case 14: lower = 'e'; break;
        case 3:  lower = 'f'; break;
        case 5:  lower = 'g'; break;
        case 4:  lower = 'h'; break;
        case 34: lower = 'i'; break;
        case 38: lower = 'j'; break;
        case 40: lower = 'k'; break;
        case 37: lower = 'l'; break;
        case 46: lower = 'm'; break;
        case 45: lower = 'n'; break;
        case 31: lower = 'o'; break;
        case 35: lower = 'p'; break;
        case 12: lower = 'q'; break;
        case 15: lower = 'r'; break;
        case 1:  lower = 's'; break;
        case 17: lower = 't'; break;
        case 32: lower = 'u'; break;
        case 9:  lower = 'v'; break;
        case 13: lower = 'w'; break;
        case 7:  lower = 'x'; break;
        case 16: lower = 'y'; break;
        case 6:  lower = 'z'; break;
        default: break;
    }
    if (lower != 0) {
        return shift ? (char)(lower - 'a' + 'A') : lower;
    }

    switch (keyCode) {
        case 18: return shift ? 0 : '1';
        case 19: return shift ? 0 : '2';
        case 20: return shift ? '#' : '3';
        case 21: return shift ? 0 : '4';
        case 23: return shift ? 0 : '5';
        case 22: return shift ? 0 : '6';
        case 26: return shift ? 0 : '7';
        case 28: return shift ? 0 : '8';
        case 25: return shift ? '(' : '9';
        case 29: return shift ? ')' : '0';
        case 44: return shift ? 0 : '/';
        case 27: return shift ? 0 : '-';
        case 24: return shift ? '+' : 0;
        case 43: return shift ? 0 : ',';
        default: return 0;
    }
}

- (void)keyDown:(NSEvent *)event {
    NSUInteger flags = ([event modifierFlags] & NSDeviceIndependentModifierFlagsMask);
    BOOL isCmd = ((flags & NSCommandKeyMask) != 0) || ((flags & NSControlKeyMask) != 0);
    BOOL isShift = ((flags & NSShiftKeyMask) != 0);
    BOOL isOption = ((flags & NSAlternateKeyMask) != 0);
    unsigned short keyCode = [event keyCode];

    // 1. Command shortcuts
    if (isCmd) {
        switch (keyCode) {
            case 24: case 69: // '=', '+', Numpad+
                sj_engine_zoom_in(_engine);
                [self.delegate scoreCanvasDidMutateState];
                return;
            case 27: case 78: // '-', Numpad-
                sj_engine_zoom_out(_engine);
                [self.delegate scoreCanvasDidMutateState];
                return;
            case 29: case 82: // '0', Numpad0
                sj_engine_reset_zoom(_engine);
                [self.delegate scoreCanvasDidMutateState];
                return;
            case 8: // 'C'
                sj_engine_copy_selection(_engine);
                [self.delegate scoreCanvasDidMutateState];
                return;
            case 9: // 'V'
                sj_engine_paste_clipboard(_engine);
                [self.delegate scoreCanvasDidMutateState];
                return;
            default:
                break;
        }
    }

    // 2. Syncopation Toggle (Shift + S)
    if (isShift && !isCmd && !isOption && keyCode == 1) {
        sj_engine_toggle_syncopation(_engine);
        [self.delegate scoreCanvasDidMutateState];
        return;
    }

    // 3. Navigation, Content Move, Deletion, Space
    switch (keyCode) {
        case 123: // Left
            if (isOption) sj_engine_move_content(_engine, -1);
            else if (isShift) sj_engine_move_measure(_engine, -1, 0);
            else sj_engine_move_cursor(_engine, -1, 0);
            [self.delegate scoreCanvasDidMutateState];
            return;
        case 124: // Right
            if (isOption) sj_engine_move_content(_engine, 1);
            else if (isShift) sj_engine_move_measure(_engine, 1, 0);
            else sj_engine_move_cursor(_engine, 1, 0);
            [self.delegate scoreCanvasDidMutateState];
            return;
        case 126: // Up
            if (isOption) sj_engine_move_content(_engine, -16);
            else sj_engine_move_cursor(_engine, -16, isShift ? 1 : 0);
            [self.delegate scoreCanvasDidMutateState];
            return;
        case 125: // Down
            if (isOption) sj_engine_move_content(_engine, 16);
            else sj_engine_move_cursor(_engine, 16, isShift ? 1 : 0);
            [self.delegate scoreCanvasDidMutateState];
            return;
        case 51: // Backspace
            sj_engine_delete_char(_engine);
            [self.delegate scoreCanvasDidMutateState];
            return;
        case 117: // Forward Delete
            sj_engine_delete_selection(_engine);
            [self.delegate scoreCanvasDidMutateState];
            return;
        case 49: // Space
            sj_engine_move_cursor(_engine, 1, 0);
            [self.delegate scoreCanvasDidMutateState];
            return;
        default:
            break;
    }

    // 4. Chord Character Entry
    if (!isCmd && !isOption) {
        char ch = [self chordCharacterForKeyCode:keyCode shift:isShift];
        if (ch != 0) {
            sj_engine_append_char(_engine, ch);
            [self.delegate scoreCanvasDidMutateState];
            return;
        }
    }
}

@end
