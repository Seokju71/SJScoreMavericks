#import <Foundation/Foundation.h>
#import "sjscore_core.h"

@interface SJPDFExporter : NSObject

+ (BOOL)exportEngine:(SJEngine *)engine
           transpose:(int)transpose
               toURL:(NSURL *)url
               error:(NSError **)outError;

@end
