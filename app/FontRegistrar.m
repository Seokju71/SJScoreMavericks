#import "FontRegistrar.h"

static BOOL sDidRegister = NO;
static NSString *sChordFontName = @"PetalumaScript";
static NSString *sSymbolFontName = @"Petaluma";

@implementation SJFontRegistrar

+ (NSURL *)findFontURLWithName:(NSString *)name ext:(NSString *)ext {
    NSBundle *mainBundle = [NSBundle mainBundle];
    NSURL *url = [mainBundle URLForResource:name withExtension:ext];
    if (url) return url;
    url = [mainBundle URLForResource:name withExtension:ext subdirectory:@"Fonts"];
    if (url) return url;
    return nil;
}

+ (void)registerBundledFonts {
    if (sDidRegister) return;
    sDidRegister = YES;

    NSArray *fontNames = @[@"PetalumaScript", @"Petaluma"];
    for (NSString *name in fontNames) {
        NSURL *url = [self findFontURLWithName:name ext:@"otf"];
        if (!url) continue;

        CFErrorRef error = NULL;
        CTFontManagerRegisterFontsForURL((__bridge CFURLRef)url, kCTFontManagerScopeProcess, &error);
        if (error) {
            CFRelease(error);
        }

        CFArrayRef descriptors = CTFontManagerCreateFontDescriptorsFromURL((__bridge CFURLRef)url);
        if (descriptors) {
            if (CFArrayGetCount(descriptors) > 0) {
                CTFontDescriptorRef first = (CTFontDescriptorRef)CFArrayGetValueAtIndex(descriptors, 0);
                CFStringRef psName = (CFStringRef)CTFontDescriptorCopyAttribute(first, kCTFontNameAttribute);
                if (psName) {
                    NSString *ps = (__bridge_transfer NSString *)psName;
                    if ([name isEqualToString:@"PetalumaScript"]) {
                        sChordFontName = ps;
                    } else if ([name isEqualToString:@"Petaluma"]) {
                        sSymbolFontName = ps;
                    }
                }
            }
            CFRelease(descriptors);
        }
    }
}

+ (CTFontRef)chordFontOfSize:(CGFloat)size bold:(BOOL)bold {
    NSFont *base = [NSFont fontWithName:sChordFontName size:size];
    if (!base) {
        base = bold ? [NSFont boldSystemFontOfSize:size] : [NSFont systemFontOfSize:size];
    } else if (bold) {
        NSFont *converted = [[NSFontManager sharedFontManager] convertFont:base toHaveTrait:NSBoldFontMask];
        if (converted) base = converted;
    }
    return (__bridge CTFontRef)base;
}

+ (CTFontRef)symbolFontOfSize:(CGFloat)size {
    NSFont *base = [NSFont fontWithName:sSymbolFontName size:size];
    if (!base) {
        base = [NSFont systemFontOfSize:size];
    }
    return (__bridge CTFontRef)base;
}

+ (CTFontRef)titleFontOfSize:(CGFloat)size {
    NSFont *base = [NSFont fontWithName:sChordFontName size:size];
    if (!base) {
        base = [NSFont systemFontOfSize:size];
    }
    return (__bridge CTFontRef)base;
}

@end
