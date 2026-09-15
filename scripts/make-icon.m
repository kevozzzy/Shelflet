#import <Cocoa/Cocoa.h>

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc != 2) return 1;
        NSSize size = NSMakeSize(1024, 1024);
        NSImage *image = [[NSImage alloc] initWithSize:size];
        [image lockFocus];
        NSRect canvas = NSMakeRect(0, 0, 1024, 1024);
        NSBezierPath *background = [NSBezierPath bezierPathWithRoundedRect:NSInsetRect(canvas, 48, 48) xRadius:220 yRadius:220];
        NSGradient *gradient = [[NSGradient alloc] initWithColors:@[
            [NSColor colorWithRed:0.13 green:0.63 blue:0.98 alpha:1],
            [NSColor colorWithRed:0.16 green:0.35 blue:0.88 alpha:1]
        ]];
        [gradient drawInBezierPath:background angle:-70];

        [[NSColor.whiteColor colorWithAlphaComponent:0.96] setStroke];
        NSBezierPath *shelf = [NSBezierPath bezierPath];
        shelf.lineWidth = 66; shelf.lineCapStyle = NSLineCapStyleRound;
        [shelf moveToPoint:NSMakePoint(250, 280)]; [shelf lineToPoint:NSMakePoint(774, 280)]; [shelf stroke];
        NSBezierPath *arrow = [NSBezierPath bezierPath];
        arrow.lineWidth = 62; arrow.lineCapStyle = NSLineCapStyleRound; arrow.lineJoinStyle = NSLineJoinStyleRound;
        [arrow moveToPoint:NSMakePoint(512, 760)]; [arrow lineToPoint:NSMakePoint(512, 430)];
        [arrow moveToPoint:NSMakePoint(360, 565)]; [arrow lineToPoint:NSMakePoint(512, 410)]; [arrow lineToPoint:NSMakePoint(664, 565)];
        [arrow stroke];
        [image unlockFocus];

        NSBitmapImageRep *bitmap = [[NSBitmapImageRep alloc] initWithData:image.TIFFRepresentation];
        NSData *png = [bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
        return [png writeToFile:@(argv[1]) options:NSDataWritingAtomic error:nil] ? 0 : 2;
    }
}
