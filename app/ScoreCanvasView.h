#import <AppKit/AppKit.h>
#import "sjscore_core.h"

@protocol SJScoreCanvasDelegate <NSObject>
- (void)scoreCanvasDidMutateState;
- (void)scoreCanvasDidRequestTitleEdit;
@end

@interface SJScoreCanvasView : NSView

@property (nonatomic, assign) SJEngine *engine;
@property (nonatomic, weak) id<SJScoreCanvasDelegate> delegate;

- (instancetype)initWithEngine:(SJEngine *)engine;
- (void)updateCanvasSize;

@end
