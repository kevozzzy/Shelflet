#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

@interface SLShakeAnalyzer : NSObject {
@private
    CGFloat _minimumSegment;
    CGFloat _minimumTravel;
    NSInteger _requiredReversals;
    NSTimeInterval _timeWindow;
    CGFloat _lastX;
    BOOL _hasLastX;
    NSInteger _direction;
    NSMutableArray<NSNumber *> *_reversals;
    CGFloat _travel;
    NSTimeInterval _startedAt;
}

- (instancetype)init;
- (instancetype)initWithMinimumSegment:(CGFloat)minimumSegment
                         minimumTravel:(CGFloat)minimumTravel
                      requiredReversals:(NSInteger)requiredReversals
                            timeWindow:(NSTimeInterval)timeWindow;
- (void)reset;
- (BOOL)updateWithX:(CGFloat)x time:(NSTimeInterval)time;

@end
