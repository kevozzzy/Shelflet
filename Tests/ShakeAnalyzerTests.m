#import <Foundation/Foundation.h>
#import "ShakeAnalyzer.h"

static void require(BOOL condition, NSString *message) {
    if (!condition) {
        NSLog(@"FAILED: %@", message);
        exit(1);
    }
}

int main(void) {
    @autoreleasepool {
        SLShakeAnalyzer *fast = [[SLShakeAnalyzer alloc] init];
        NSArray<NSNumber *> *points = @[@100, @135, @98, @138, @96];
        BOOL detected = NO;
        for (NSInteger i = 0; i < (NSInteger)points.count; i++)
            detected = [fast updateWithX:points[i].doubleValue time:i * 0.1] || detected;
        require(detected, @"fast horizontal shake should be detected");

        SLShakeAnalyzer *slow = [[SLShakeAnalyzer alloc] init];
        detected = NO;
        for (NSInteger i = 0; i < (NSInteger)points.count; i++)
            detected = [slow updateWithX:points[i].doubleValue time:i * 0.4] || detected;
        require(!detected, @"slow movement should not be detected");

        SLShakeAnalyzer *straight = [[SLShakeAnalyzer alloc] init];
        detected = NO;
        for (NSInteger i = 0; i < 8; i++)
            detected = [straight updateWithX:i * 25 time:i * 0.05] || detected;
        require(!detected, @"straight drag should not be detected");
        NSLog(@"All shake analyzer tests passed");
    }
    return 0;
}
