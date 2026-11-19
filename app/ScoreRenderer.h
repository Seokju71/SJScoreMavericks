#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>
#import "sjscore_core.h"

@interface SJScoreRenderer : NSObject

+ (void)drawInContext:(CGContextRef)context
               engine:(SJEngine *)engine
            pageIndex:(int)pageIndex
            transpose:(int)transpose
       isEditingTitle:(BOOL)isEditingTitle
showInteractiveChrome:(BOOL)showInteractiveChrome;

@end
