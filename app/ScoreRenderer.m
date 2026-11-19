#import "ScoreRenderer.h"
#import "FontRegistrar.h"
#import <AppKit/AppKit.h>
#import <CoreText/CoreText.h>

static const CGFloat kAccidentalScaleRatio = 0.68;
static const CGFloat kAccidentalScaleX = 0.80;
static const CGFloat kAccidentalYOffsetRatio = 0.34;
static const CGFloat kAccidentalKerning = -1.5;
static const CGFloat kSlashScaleX = 0.82;
static const CGFloat kSlashToBassKerning = -1.0;

typedef struct {
    CGFloat suffixWidth;
    CGFloat maxStackWidth;
    CGFloat bassWidth;
    CGFloat unparsedWidth;
} SJMeasuredExtensions;

static inline CGFloat SJMeasuredTotal(SJMeasuredExtensions m) {
    CGFloat mainW = (m.suffixWidth > m.maxStackWidth) ? m.suffixWidth : m.maxStackWidth;
    return mainW + m.bassWidth + m.unparsedWidth;
}

static CGColorRef SJColorPaper(void) {
    static CGColorRef c = NULL;
    if (!c) c = CGColorCreateGenericRGB(0xFD / 255.0, 0xFB / 255.0, 0xF7 / 255.0, 1.0);
    return c;
}

static CGColorRef SJColorInk(void) {
    static CGColorRef c = NULL;
    if (!c) c = CGColorCreateGenericRGB(0x2A / 255.0, 0x2A / 255.0, 0x2A / 255.0, 1.0);
    return c;
}

static CGColorRef SJColorBlack(void) {
    static CGColorRef c = NULL;
    if (!c) c = CGColorCreateGenericRGB(0.0, 0.0, 0.0, 1.0);
    return c;
}

static CGColorRef SJColorPageNum(void) {
    static CGColorRef c = NULL;
    if (!c) c = CGColorCreateGenericRGB(0x55 / 255.0, 0x55 / 255.0, 0x55 / 255.0, 1.0);
    return c;
}

static CGColorRef SJColorSelection(void) {
    static CGColorRef c = NULL;
    if (!c) c = CGColorCreateGenericRGB(64.0 / 255.0, 169.0 / 255.0, 255.0 / 255.0, 0.2);
    return c;
}

static CGColorRef SJColorCursor(void) {
    static CGColorRef c = NULL;
    if (!c) c = CGColorCreateGenericRGB(0.0, 0.0, 0.0, 0.1);
    return c;
}

static CTLineRef SJMakeCTLine(NSString *text, CTFontRef font, CGColorRef color) {
    if (!text) text = @"";
    NSDictionary *attrs = @{
        (__bridge NSString *)kCTFontAttributeName: (__bridge id)font,
        (__bridge NSString *)kCTForegroundColorAttributeName: (__bridge id)color
    };
    NSAttributedString *attrStr = [[NSAttributedString alloc] initWithString:text attributes:attrs];
    return CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)attrStr);
}

static CGFloat SJLineWidth(CTLineRef line) {
    return (CGFloat)CTLineGetTypographicBounds(line, NULL, NULL, NULL);
}

static void SJDrawLine(CTLineRef line, CGContextRef ctx, CGFloat x, CGFloat baselineY, CGFloat scaleX) {
    CGContextSaveGState(ctx);
    CGContextSetTextMatrix(ctx, CGAffineTransformMakeScale(scaleX, -1.0));
    CGContextSetTextPosition(ctx, x, baselineY);
    CTLineDraw(line, ctx);
    CGContextRestoreGState(ctx);
}

static BOOL SJIsNoteLetter(unichar ch) {
    return (ch >= 'A' && ch <= 'G');
}

static void SJSplitPitchText(NSString *text, NSString **outLetter, NSString **outAcc) {
    if (text.length == 0 || !SJIsNoteLetter([text characterAtIndex:0])) {
        *outLetter = text ?: @"";
        *outAcc = @"";
        return;
    }
    NSString *first = [text substringToIndex:1];
    NSString *rest = [text substringFromIndex:1];
    if (rest.length == 0) {
        *outLetter = first;
        *outAcc = @"";
        return;
    }
    BOOL allAcc = YES;
    for (NSUInteger i = 0; i < rest.length; i++) {
        unichar c = [rest characterAtIndex:i];
        if (c != '#' && c != 'b' && c != 0x266F && c != 0x266D) {
            allAcc = NO;
            break;
        }
    }
    if (allAcc) {
        *outLetter = first;
        *outAcc = rest;
    } else {
        *outLetter = text;
        *outAcc = @"";
    }
}

static CGFloat SJMeasurePitchWidth(NSString *text, CGFloat fontSize, BOOL bold) {
    NSString *letter = nil, *acc = nil;
    SJSplitPitchText(text, &letter, &acc);
    CTLineRef letterLine = SJMakeCTLine(letter, [SJFontRegistrar chordFontOfSize:fontSize bold:bold], SJColorInk());
    CGFloat letterW = SJLineWidth(letterLine);
    CFRelease(letterLine);
    if (acc.length == 0) return letterW;

    CTLineRef accLine = SJMakeCTLine(acc, [SJFontRegistrar chordFontOfSize:fontSize * kAccidentalScaleRatio bold:bold], SJColorInk());
    CGFloat accW = SJLineWidth(accLine) * kAccidentalScaleX;
    CFRelease(accLine);
    CGFloat extra = accW + kAccidentalKerning;
    return letterW + (extra > 0 ? extra : 0);
}

static CGFloat SJDrawPitchText(NSString *text, CGContextRef ctx, CGFloat x, CGFloat baselineY, CGFloat fontSize, BOOL bold) {
    NSString *letter = nil, *acc = nil;
    SJSplitPitchText(text, &letter, &acc);
    CTLineRef letterLine = SJMakeCTLine(letter, [SJFontRegistrar chordFontOfSize:fontSize bold:bold], SJColorInk());
    SJDrawLine(letterLine, ctx, x, baselineY, 1.0);
    CGFloat letterW = SJLineWidth(letterLine);
    CFRelease(letterLine);
    if (acc.length == 0) return letterW;

    CTLineRef accLine = SJMakeCTLine(acc, [SJFontRegistrar chordFontOfSize:fontSize * kAccidentalScaleRatio bold:bold], SJColorInk());
    CGFloat accX = x + letterW + kAccidentalKerning;
    CGFloat accY = baselineY - (fontSize * kAccidentalYOffsetRatio);
    SJDrawLine(accLine, ctx, accX, accY, kAccidentalScaleX);
    CGFloat accW = SJLineWidth(accLine) * kAccidentalScaleX;
    CFRelease(accLine);
    CGFloat extra = accW + kAccidentalKerning;
    return letterW + (extra > 0 ? extra : 0);
}

static CGFloat SJMeasureSlashBassWidth(NSString *bass, CGFloat fontSize, BOOL bold) {
    BOOL hasSlash = [bass hasPrefix:@"/"];
    NSString *pitchPart = hasSlash ? [bass substringFromIndex:1] : bass;
    CGFloat width = 0.0;
    if (hasSlash) {
        CTLineRef slashLine = SJMakeCTLine(@"/", [SJFontRegistrar chordFontOfSize:fontSize * 0.95 bold:NO], SJColorInk());
        width += (SJLineWidth(slashLine) * kSlashScaleX) + kSlashToBassKerning;
        CFRelease(slashLine);
    }
    width += SJMeasurePitchWidth(pitchPart, fontSize, bold);
    return width > 0 ? width : 0;
}

static CGFloat SJDrawSlashBass(NSString *bass, CGContextRef ctx, CGFloat x, CGFloat baselineY, CGFloat fontSize, BOOL bold) {
    BOOL hasSlash = [bass hasPrefix:@"/"];
    NSString *pitchPart = hasSlash ? [bass substringFromIndex:1] : bass;
    CGFloat offsetX = 0.0;
    if (hasSlash) {
        CTLineRef slashLine = SJMakeCTLine(@"/", [SJFontRegistrar chordFontOfSize:fontSize * 0.95 bold:NO], SJColorInk());
        SJDrawLine(slashLine, ctx, x, baselineY, kSlashScaleX);
        offsetX += (SJLineWidth(slashLine) * kSlashScaleX) + kSlashToBassKerning;
        CFRelease(slashLine);
    }
    CGFloat pitchW = SJDrawPitchText(pitchPart, ctx, x + offsetX, baselineY, fontSize, bold);
    CGFloat total = offsetX + pitchW;
    return total > 0 ? total : 0;
}

static SJMeasuredExtensions SJMeasureExtensions(
    NSString *suffix,
    int styleHint,
    NSArray *tensionStack,
    NSString *bass,
    NSString *unparsed,
    CGFloat subSize,
    CGFloat stackSize,
    CGFloat bassSize,
    BOOL bold
) {
    SJMeasuredExtensions m = {0, 0, 0, 0};
    if (suffix.length > 0) {
        CGFloat size = (styleHint == SJ_SUFFIX_DIM_OR_HALFDIM) ? (subSize * 1.45) : subSize;
        CGFloat scaleX = (styleHint == SJ_SUFFIX_SUS || styleHint == SJ_SUFFIX_ADD_OR_AUG) ? 0.85 : 1.0;
        CTLineRef line = SJMakeCTLine(suffix, [SJFontRegistrar chordFontOfSize:size bold:bold], SJColorInk());
        m.suffixWidth = SJLineWidth(line) * scaleX;
        CFRelease(line);
    }
    if (tensionStack.count > 0) {
        CTFontRef font = [SJFontRegistrar chordFontOfSize:stackSize bold:bold];
        for (NSString *item in tensionStack) {
            CTLineRef line = SJMakeCTLine(item, font, SJColorInk());
            CGFloat w = SJLineWidth(line);
            CFRelease(line);
            if (w > m.maxStackWidth) m.maxStackWidth = w;
        }
    }
    if (bass.length > 0) {
        m.bassWidth = SJMeasureSlashBassWidth(bass, bassSize, YES);
    }
    if (unparsed.length > 0) {
        CTLineRef line = SJMakeCTLine(unparsed, [SJFontRegistrar chordFontOfSize:subSize bold:bold], SJColorInk());
        m.unparsedWidth = SJLineWidth(line);
        CFRelease(line);
    }
    return m;
}

@implementation SJScoreRenderer

+ (void)drawChordLayout:(const SJChordLayoutC *)chord
              inContext:(CGContextRef)ctx
                  baseX:(CGFloat)baseX
                  baseY:(CGFloat)baseY
              slotWidth:(CGFloat)slotWidth {
    NSString *rootStr = chord->root ? [NSString stringWithUTF8String:chord->root] : @"";
    NSString *suffixStr = chord->suffix ? [NSString stringWithUTF8String:chord->suffix] : @"";
    NSString *bassStr = chord->bass ? [NSString stringWithUTF8String:chord->bass] : @"";
    NSString *unparsedStr = chord->unparsed ? [NSString stringWithUTF8String:chord->unparsed] : @"";

    NSMutableArray *tensionStack = [NSMutableArray arrayWithCapacity:(NSUInteger)chord->tensionCount];
    for (int i = 0; i < chord->tensionCount && i < 8; i++) {
        if (chord->tensions[i]) {
            [tensionStack addObject:[NSString stringWithUTF8String:chord->tensions[i]]];
        }
    }

    CGFloat rootFontSize = 22.0;
    CGFloat subFontSize = 14.0;
    CGFloat stackFontSize = 10.0;
    CGFloat bassFontSize = 18.5;

    CGFloat rootWidth = SJMeasurePitchWidth(rootStr, rootFontSize, YES);
    CGFloat maxTextWidth = slotWidth - 6.0;
    CGFloat availableWidth = maxTextWidth - rootWidth;
    if (availableWidth < 0.0) availableWidth = 0.0;

    BOOL useBoldExt = YES;
    SJMeasuredExtensions measured = SJMeasureExtensions(
        suffixStr, chord->suffixStyleHint, tensionStack, bassStr, unparsedStr,
        subFontSize, stackFontSize, bassFontSize, YES
    );

    if (SJMeasuredTotal(measured) > availableWidth) {
        useBoldExt = NO;
        measured = SJMeasureExtensions(
            suffixStr, chord->suffixStyleHint, tensionStack, bassStr, unparsedStr,
            subFontSize, stackFontSize, bassFontSize, NO
        );
    }

    CGFloat totalW = SJMeasuredTotal(measured);
    if (totalW > availableWidth && totalW > 0.0) {
        CGFloat ratio = availableWidth / totalW;
        CGFloat scaleFactor = (ratio > 0.72) ? ratio : 0.72;
        subFontSize *= scaleFactor;
        stackFontSize *= scaleFactor;
        bassFontSize *= scaleFactor;
    }

    // 1. Root
    CGFloat drawnRootW = SJDrawPitchText(rootStr, ctx, baseX, baseY, rootFontSize, YES);
    CGFloat cursorX = baseX + drawnRootW;

    // 2. Suffix
    CGFloat suffixDrawnW = 0.0;
    if (suffixStr.length > 0) {
        CGFloat effSize = subFontSize;
        CGFloat yOffset = 0.0;
        CGFloat scaleX = 1.0;

        if (chord->suffixStyleHint == SJ_SUFFIX_DIM_OR_HALFDIM) {
            effSize = subFontSize * 1.45;
            yOffset = -9.0;
        } else if (chord->suffixStyleHint == SJ_SUFFIX_SUS || chord->suffixStyleHint == SJ_SUFFIX_ADD_OR_AUG) {
            scaleX = 0.85;
        }

        CTLineRef suffixLine = SJMakeCTLine(suffixStr, [SJFontRegistrar chordFontOfSize:effSize bold:useBoldExt], SJColorInk());
        SJDrawLine(suffixLine, ctx, cursorX, baseY + yOffset, scaleX);
        suffixDrawnW = SJLineWidth(suffixLine) * scaleX;
        CFRelease(suffixLine);
    }

    // 3. Stacked Tensions
    CGFloat maxStackW = 0.0;
    if (tensionStack.count > 0) {
        CTFontRef stackFont = [SJFontRegistrar chordFontOfSize:stackFontSize bold:useBoldExt];
        CGFloat currentY = baseY - 14.0;
        for (NSString *item in tensionStack) {
            CTLineRef itemLine = SJMakeCTLine(item, stackFont, SJColorInk());
            CGFloat itemW = SJLineWidth(itemLine);
            if (itemW > maxStackW) maxStackW = itemW;
            CGFloat itemX = cursorX;
            if (suffixDrawnW > 0.0 && suffixDrawnW > itemW) {
                itemX = cursorX + (suffixDrawnW - itemW);
            }
            SJDrawLine(itemLine, ctx, itemX, currentY, 1.0);
            CFRelease(itemLine);
            currentY -= 13.0;
        }
    }

    cursorX += (suffixDrawnW > maxStackW) ? suffixDrawnW : maxStackW;

    // 4. Slash Bass
    if (bassStr.length > 0) {
        CGFloat bassW = SJDrawSlashBass(bassStr, ctx, cursorX, baseY + 1.5, bassFontSize, YES);
        cursorX += bassW;
    }

    // 5. Unparsed Tail
    if (unparsedStr.length > 0) {
        CTLineRef tailLine = SJMakeCTLine(unparsedStr, [SJFontRegistrar chordFontOfSize:subFontSize bold:useBoldExt], SJColorInk());
        SJDrawLine(tailLine, ctx, cursorX, baseY, 1.0);
        CFRelease(tailLine);
    }
}

+ (void)drawInContext:(CGContextRef)context
               engine:(SJEngine *)engine
            pageIndex:(int)pageIndex
            transpose:(int)transpose
       isEditingTitle:(BOOL)isEditingTitle
showInteractiveChrome:(BOOL)showInteractiveChrome {
    [SJFontRegistrar registerBundledFonts];

    SJLayoutMetrics layout;
    sj_engine_get_layout(engine, &layout);

    CGFloat canvasWidth = (CGFloat)layout.canvasWidth;
    CGFloat canvasHeight = (CGFloat)layout.canvasHeight;
    CGFloat marginLeft = (CGFloat)layout.marginLeft;

    CGContextSaveGState(context);

    // 1. Cream paper background
    CGContextSetFillColorWithColor(context, SJColorPaper());
    CGContextFillRect(context, CGRectMake(0, 0, canvasWidth, canvasHeight));

    // 2. Title & dynamic underline
    char *rawTitle = sj_engine_get_title(engine);
    NSString *titleStr = rawTitle ? [NSString stringWithUTF8String:rawTitle] : @"";
    sj_free_string(rawTitle);

    CTLineRef titleLine = SJMakeCTLine(titleStr, [SJFontRegistrar titleFontOfSize:34.0], SJColorInk());
    CGFloat titleWidth = SJLineWidth(titleLine);
    if (!isEditingTitle) {
        SJDrawLine(titleLine, context, (canvasWidth - titleWidth) / 2.0, 135.0, 1.0);
    }
    CFRelease(titleLine);

    CGFloat lineHalfW = (titleWidth / 2.0) + 20.0;
    CGContextSetStrokeColorWithColor(context, SJColorBlack());
    CGContextSetLineWidth(context, 2.0);
    CGContextBeginPath(context);
    CGContextMoveToPoint(context, (canvasWidth / 2.0) - lineHalfW, 160.0);
    CGContextAddLineToPoint(context, (canvasWidth / 2.0) + lineHalfW, 160.0);
    CGContextStrokePath(context);

    // 3. Page number
    NSString *pageText = [NSString stringWithFormat:@"Page %d", pageIndex + 1];
    CTLineRef pageLine = SJMakeCTLine(pageText, [SJFontRegistrar chordFontOfSize:20.0 bold:NO], SJColorPageNum());
    CGFloat pageWidth = SJLineWidth(pageLine);
    SJDrawLine(pageLine, context, canvasWidth - marginLeft - pageWidth, 50.0, 1.0);
    CFRelease(pageLine);

    // 4. Staves, Treble Clefs, Barlines
    CTLineRef clefLine = SJMakeCTLine(@"\uE050", [SJFontRegistrar symbolFontOfSize:44.0], SJColorInk());
    CGFloat visualStartX = 80.0;
    CGFloat visualEndX = canvasWidth - marginLeft;
    CGFloat measureWidth = (CGFloat)layout.measureWidth;

    CGContextSetStrokeColorWithColor(context, SJColorInk());
    CGContextSetLineWidth(context, 1.0);

    for (int r = 0; r < layout.rows; r++) {
        CGFloat rowY = (CGFloat)sj_engine_row_y(engine, r);
        SJDrawLine(clefLine, context, visualStartX, rowY + 25.0, 1.0);

        for (int lineIdx = 0; lineIdx < 5; lineIdx++) {
            CGFloat y = rowY + (CGFloat)(lineIdx * 10);
            CGContextBeginPath(context);
            CGContextMoveToPoint(context, visualStartX, y);
            CGContextAddLineToPoint(context, visualEndX, y);
            CGContextStrokePath(context);
        }

        for (int m = 1; m <= layout.measuresPerRow; m++) {
            CGFloat barX = marginLeft + ((CGFloat)m * measureWidth);
            CGContextBeginPath(context);
            CGContextMoveToPoint(context, barX, rowY);
            CGContextAddLineToPoint(context, barX, rowY + 40.0);
            CGContextStrokePath(context);
        }
    }
    CFRelease(clefLine);

    // 5. Slots
    int slotsPerPage = layout.slotsPerPage;
    int totalSlots = sj_engine_get_slot_count(engine);
    CGFloat slotWidth = (CGFloat)layout.slotWidth;

    for (int i = 0; i < slotsPerPage; i++) {
        int globalIndex = (pageIndex * slotsPerPage) + i;
        if (globalIndex >= totalSlots) break;

        double dx = 0.0, dy = 0.0;
        sj_engine_slot_coords(engine, i, &dx, &dy);
        CGFloat x = (CGFloat)dx;
        CGFloat y = (CGFloat)dy;

        SJChordLayoutC chord;
        sj_engine_get_slot_render(engine, globalIndex, transpose, &chord);

        if (showInteractiveChrome && chord.isSelected) {
            CGContextSetFillColorWithColor(context, SJColorSelection());
            CGContextFillRect(context, CGRectMake(x - 5.0, y - 10.0, slotWidth, 50.0));
        }

        if (showInteractiveChrome && chord.isActiveCursor && !isEditingTitle) {
            CGContextSetFillColorWithColor(context, SJColorCursor());
            CGContextFillRect(context, CGRectMake(x, y - 10.0, 50.0, 50.0));

            CGContextSetStrokeColorWithColor(context, SJColorBlack());
            CGContextSetLineWidth(context, 2.0);
            CGContextBeginPath(context);
            CGContextMoveToPoint(context, x, y - 1.0);
            CGContextAddLineToPoint(context, x + 40.0, y - 1.0);
            CGContextStrokePath(context);
        }

        if (chord.hasChord) {
            if (chord.isSyncopated) {
                int rowIndex = i / layout.slotsPerRow;
                CGFloat staveTopY = (CGFloat)sj_engine_row_y(engine, rowIndex);
                CGFloat noteX = x - 28.0;
                CGFloat noteY = staveTopY + 30.0;
                CTFontRef syncFont = [SJFontRegistrar symbolFontOfSize:28.0];

                CTLineRef noteLine = SJMakeCTLine(@"\uE562", syncFont, SJColorBlack());
                SJDrawLine(noteLine, context, noteX + 16.0, noteY - 60.0, 1.0);
                CFRelease(noteLine);

                CTLineRef tieLine = SJMakeCTLine(@"\uE4BA", syncFont, SJColorBlack());
                SJDrawLine(tieLine, context, noteX + 24.0, noteY - 60.0, 1.0);
                CFRelease(tieLine);
            }

            [self drawChordLayout:&chord
                        inContext:context
                            baseX:x + 5.0
                            baseY:y - 8.0
                        slotWidth:slotWidth];
        }

        sj_free_chord_layout(&chord);
    }

    CGContextRestoreGState(context);
}

@end
