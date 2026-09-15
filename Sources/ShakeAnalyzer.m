#import "ShakeAnalyzer.h"

@implementation SLShakeAnalyzer

- (instancetype)init {
    return [self initWithMinimumSegment:6 minimumTravel:90 requiredReversals:3 timeWindow:0.72];
}

- (instancetype)initWithMinimumSegment:(CGFloat)minimumSegment
                         minimumTravel:(CGFloat)minimumTravel
                      requiredReversals:(NSInteger)requiredReversals
                            timeWindow:(NSTimeInterval)timeWindow {
    self = [super init];
    if (self) {
        _minimumSegment = minimumSegment;
        _minimumTravel = minimumTravel;
        _requiredReversals = requiredReversals;
        _timeWindow = timeWindow;
        _reversals = [NSMutableArray array];
        [self reset];
    }
    return self;
}

- (void)reset {
    _hasLastX = NO;
    _direction = 0;
    [_reversals removeAllObjects];
    _travel = 0;
    _startedAt = 0;
}

- (BOOL)updateWithX:(CGFloat)x time:(NSTimeInterval)time {
    if (!_hasLastX) {
        _lastX = x;
        _startedAt = time;
        _hasLastX = YES;
        return NO;
    }

    if (time - _startedAt > _timeWindow) {
        [self reset];
        _lastX = x;
        _startedAt = time;
        _hasLastX = YES;
        return NO;
    }

    CGFloat delta = x - _lastX;
    if (fabs(delta) < _minimumSegment) return NO;

    NSInteger newDirection = delta > 0 ? 1 : -1;
    _travel += fabs(delta);
    _lastX = x;
    if (_direction != 0 && newDirection != _direction) {
        [_reversals addObject:@(time)];
    }
    _direction = newDirection;

    NSIndexSet *expired = [_reversals indexesOfObjectsPassingTest:^BOOL(NSNumber *value, NSUInteger idx, BOOL *stop) {
        (void)idx;
        (void)stop;
        return time - value.doubleValue > self->_timeWindow;
    }];
    [_reversals removeObjectsAtIndexes:expired];

    if ((NSInteger)_reversals.count >= _requiredReversals && _travel >= _minimumTravel) {
        [self reset];
        return YES;
    }
    return NO;
}

@end
