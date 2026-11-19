#import "PDFExporter.h"
#import "ScoreRenderer.h"
#import <CoreGraphics/CoreGraphics.h>

@implementation SJPDFExporter

+ (BOOL)exportEngine:(SJEngine *)engine
           transpose:(int)transpose
               toURL:(NSURL *)url
               error:(NSError **)outError {
    CGRect a4Rect = CGRectMake(0.0, 0.0, 595.28, 841.89);
    CGContextRef pdfContext = CGPDFContextCreateWithURL((__bridge CFURLRef)url, &a4Rect, NULL);
    if (!pdfContext) {
        if (outError) {
            *outError = [NSError errorWithDomain:@"com.sjscore.pdf"
                                            code:1
                                        userInfo:@{NSLocalizedDescriptionKey: @"Could not create PDF graphics context."}];
        }
        return NO;
    }

    SJLayoutMetrics metrics;
    sj_engine_get_layout(engine, &metrics);

    int totalPages = sj_engine_get_effective_pdf_pages(engine);
    CGFloat scaleX = a4Rect.size.width / (CGFloat)metrics.canvasWidth;
    CGFloat scaleY = a4Rect.size.height / (CGFloat)metrics.canvasHeight;

    for (int page = 0; page < totalPages; page++) {
        CGPDFContextBeginPage(pdfContext, NULL);
        CGContextSaveGState(pdfContext);

        // Convert PDF bottom-left origin into SJScore top-left flipped coordinate space
        CGContextTranslateCTM(pdfContext, 0.0, a4Rect.size.height);
        CGContextScaleCTM(pdfContext, scaleX, -scaleY);

        [SJScoreRenderer drawInContext:pdfContext
                                engine:engine
                             pageIndex:page
                             transpose:transpose
                        isEditingTitle:NO
                 showInteractiveChrome:NO];

        CGContextRestoreGState(pdfContext);
        CGPDFContextEndPage(pdfContext);
    }

    CGPDFContextClose(pdfContext);
    CGContextRelease(pdfContext);
    return YES;
}

@end
