#import <AppKit/AppKit.h>
#import <CoreText/CoreText.h>

@interface SJFontRegistrar : NSObject

+ (void)registerBundledFonts;
+ (CTFontRef)chordFontOfSize:(CGFloat)size bold:(BOOL)bold;
+ (CTFontRef)symbolFontOfSize:(CGFloat)size;
+ (CTFontRef)titleFontOfSize:(CGFloat)size;

@end
