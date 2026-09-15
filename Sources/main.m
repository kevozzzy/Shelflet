#import <Cocoa/Cocoa.h>
#import <CoreGraphics/CoreGraphics.h>
#import <ServiceManagement/ServiceManagement.h>
#import "ShakeAnalyzer.h"

static NSString *SL(NSString *key) {
    return [NSBundle.mainBundle localizedStringForKey:key value:key table:nil];
}

@interface SLShelfModel : NSObject
@property(nonatomic, readonly) NSMutableArray<NSURL *> *files;
@property(nonatomic, copy) void (^onChange)(void);
@property(nonatomic, strong) NSTimer *autoClearTimer;
- (NSInteger)addURLs:(NSArray<NSURL *> *)urls;
- (NSInteger)addFromPasteboard:(NSPasteboard *)pasteboard;
- (void)removeAtIndex:(NSInteger)index;
- (void)removeURL:(NSURL *)url;
- (void)markUsed;
- (void)clear;
@end

@implementation SLShelfModel
- (instancetype)init {
    self = [super init];
    if (self) _files = [NSMutableArray array];
    return self;
}
- (NSInteger)addURLs:(NSArray<NSURL *> *)urls {
    NSMutableSet<NSString *> *paths = [NSMutableSet set];
    for (NSURL *url in _files) [paths addObject:url.standardizedURL.path];
    NSInteger added = 0;
    for (NSURL *url in urls) {
        if (![url isKindOfClass:NSURL.class] || !url.fileURL) continue;
        NSURL *normalized = url.standardizedURL;
        if ([paths containsObject:normalized.path]) continue;
        [_files addObject:normalized];
        [paths addObject:normalized.path];
        added++;
    }
    if (added) {
        [self markUsed];
        if (self.onChange) self.onChange();
    }
    return added;
}
- (NSInteger)addFromPasteboard:(NSPasteboard *)pasteboard {
    NSArray *urls = [pasteboard readObjectsForClasses:@[NSURL.class]
                                              options:@{NSPasteboardURLReadingFileURLsOnlyKey: @YES}] ?: @[];
    return [self addURLs:urls];
}
- (void)removeAtIndex:(NSInteger)index {
    if (index < 0 || index >= (NSInteger)_files.count) return;
    [_files removeObjectAtIndex:index];
    [self markUsed];
    if (self.onChange) self.onChange();
}
- (void)removeURL:(NSURL *)url {
    NSString *path = url.standardizedURL.path;
    NSUInteger index = [_files indexOfObjectPassingTest:^BOOL(NSURL *candidate, NSUInteger idx, BOOL *stop) {
        (void)idx;
        (void)stop;
        return [candidate.standardizedURL.path isEqualToString:path];
    }];
    if (index != NSNotFound) [self removeAtIndex:(NSInteger)index];
}
- (void)markUsed {
    [self.autoClearTimer invalidate];
    self.autoClearTimer = nil;
    if (!_files.count) return;
    self.autoClearTimer = [NSTimer timerWithTimeInterval:300
                                                 target:self
                                               selector:@selector(autoClearTimerFired:)
                                               userInfo:nil
                                                repeats:NO];
    [NSRunLoop.mainRunLoop addTimer:self.autoClearTimer forMode:NSRunLoopCommonModes];
}
- (void)autoClearTimerFired:(NSTimer *)timer {
    (void)timer;
    self.autoClearTimer = nil;
    if (!_files.count) return;
    [_files removeAllObjects];
    if (self.onChange) self.onChange();
}
- (void)clear {
    [self.autoClearTimer invalidate];
    self.autoClearTimer = nil;
    if (!_files.count) return;
    [_files removeAllObjects];
    if (self.onChange) self.onChange();
}
@end

@interface SLFileGridView : NSView <NSDraggingSource>
@property(nonatomic, strong) SLShelfModel *model;
@property(nonatomic) NSInteger pressedIndex;
@property(nonatomic) BOOL dropTarget;
@property(nonatomic, strong) NSURL *draggedURL;
@end

@implementation SLFileGridView
static const CGFloat SLCellWidth = 104;
static const CGFloat SLCellHeight = 104;

- (instancetype)initWithModel:(SLShelfModel *)model {
    self = [super initWithFrame:NSZeroRect];
    if (self) {
        _model = model;
        _pressedIndex = -1;
        self.wantsLayer = YES;
        self.layer.cornerRadius = 12;
        [self registerForDraggedTypes:@[NSPasteboardTypeFileURL]];
    }
    return self;
}
- (BOOL)isFlipped { return YES; }
- (BOOL)mouseDownCanMoveWindow { return NO; }
- (NSInteger)columnCount { return MAX(1, (NSInteger)(self.bounds.size.width / SLCellWidth)); }
- (NSRect)cellRectAtIndex:(NSInteger)index {
    NSInteger columns = self.columnCount;
    return NSMakeRect((index % columns) * SLCellWidth, (index / columns) * SLCellHeight, SLCellWidth, SLCellHeight);
}
- (NSInteger)fileIndexAtPoint:(NSPoint)point {
    if (point.x < 0 || point.y < 0) return -1;
    NSInteger index = (NSInteger)(point.y / SLCellHeight) * self.columnCount + (NSInteger)(point.x / SLCellWidth);
    return index < (NSInteger)self.model.files.count ? index : -1;
}
- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    NSColor *background = self.dropTarget
        ? [NSColor.controlAccentColor colorWithAlphaComponent:0.17]
        : [NSColor.blackColor colorWithAlphaComponent:0.13];
    [background setFill];
    [[NSBezierPath bezierPathWithRoundedRect:self.bounds xRadius:12 yRadius:12] fill];

    if (!self.model.files.count) {
        NSImage *symbol = [NSImage imageWithSystemSymbolName:@"tray.and.arrow.down" accessibilityDescription:nil];
        symbol = [symbol imageWithSymbolConfiguration:[NSImageSymbolConfiguration configurationWithHierarchicalColor:[NSColor.whiteColor colorWithAlphaComponent:0.76]]];
        [symbol drawInRect:NSMakeRect(NSMidX(self.bounds) - 17, NSMidY(self.bounds) - 45, 34, 34)];
        NSMutableParagraphStyle *paragraph = [[NSMutableParagraphStyle alloc] init];
        paragraph.alignment = NSTextAlignmentCenter;
        NSDictionary *attributes = @{NSFontAttributeName: [NSFont systemFontOfSize:13 weight:NSFontWeightMedium],
                                     NSForegroundColorAttributeName: [NSColor.whiteColor colorWithAlphaComponent:0.72],
                                     NSParagraphStyleAttributeName: paragraph};
        [SL(@"shelf.drop_hint") drawInRect:NSMakeRect(20, NSMidY(self.bounds) + 2, NSWidth(self.bounds) - 40, 36)
                                                    withAttributes:attributes];
        return;
    }

    [self.model.files enumerateObjectsUsingBlock:^(NSURL *url, NSUInteger index, BOOL *stop) {
        (void)stop;
        NSRect rect = [self cellRectAtIndex:index];
        NSImage *icon = [NSWorkspace.sharedWorkspace iconForFile:url.path];
        [icon drawInRect:NSMakeRect(NSMidX(rect) - 26, NSMinY(rect) + 11, 52, 52)];
        NSMutableParagraphStyle *paragraph = [[NSMutableParagraphStyle alloc] init];
        paragraph.alignment = NSTextAlignmentCenter;
        paragraph.lineBreakMode = NSLineBreakByTruncatingMiddle;
        NSDictionary *attributes = @{NSFontAttributeName: [NSFont systemFontOfSize:11 weight:NSFontWeightMedium],
                                     NSForegroundColorAttributeName: [NSColor.whiteColor colorWithAlphaComponent:0.94],
                                     NSParagraphStyleAttributeName: paragraph};
        [url.lastPathComponent drawInRect:NSMakeRect(NSMinX(rect) + 5, NSMinY(rect) + 69, NSWidth(rect) - 10, 30)
                             withAttributes:attributes];
    }];
}
- (void)mouseDown:(NSEvent *)event {
    self.pressedIndex = [self fileIndexAtPoint:[self convertPoint:event.locationInWindow fromView:nil]];
    if (self.pressedIndex >= 0) [self.model markUsed];
    if (event.clickCount == 2 && self.pressedIndex >= 0) {
        [NSWorkspace.sharedWorkspace activateFileViewerSelectingURLs:@[self.model.files[self.pressedIndex]]];
    }
}
- (void)mouseDragged:(NSEvent *)event {
    if (self.pressedIndex < 0 || self.pressedIndex >= (NSInteger)self.model.files.count) return;
    NSURL *url = self.model.files[self.pressedIndex];
    self.draggedURL = url;
    [self.model markUsed];
    NSDraggingItem *item = [[NSDraggingItem alloc] initWithPasteboardWriter:url];
    NSRect rect = [self cellRectAtIndex:self.pressedIndex];
    [item setDraggingFrame:NSMakeRect(NSMidX(rect) - 32, NSMinY(rect) + 5, 64, 64)
                  contents:[NSWorkspace.sharedWorkspace iconForFile:url.path]];
    [self beginDraggingSessionWithItems:@[item] event:event source:self];
    self.pressedIndex = -1;
}
- (void)rightMouseDown:(NSEvent *)event {
    self.pressedIndex = [self fileIndexAtPoint:[self convertPoint:event.locationInWindow fromView:nil]];
    if (self.pressedIndex < 0) return;
    [self.model markUsed];
    NSMenu *menu = [[NSMenu alloc] init];
    NSMenuItem *reveal = [menu addItemWithTitle:SL(@"action.reveal") action:@selector(revealPressedFile:) keyEquivalent:@""];
    reveal.target = self;
    [menu addItem:NSMenuItem.separatorItem];
    NSMenuItem *remove = [menu addItemWithTitle:SL(@"action.remove") action:@selector(removePressedFile:) keyEquivalent:@""];
    remove.target = self;
    [NSMenu popUpContextMenu:menu withEvent:event forView:self];
}
- (void)revealPressedFile:(id)sender {
    if (self.pressedIndex >= 0 && self.pressedIndex < (NSInteger)self.model.files.count) {
        [self.model markUsed];
        [NSWorkspace.sharedWorkspace activateFileViewerSelectingURLs:@[self.model.files[self.pressedIndex]]];
    }
}
- (void)removePressedFile:(id)sender {
    [self.model removeAtIndex:self.pressedIndex];
    self.pressedIndex = -1;
}
- (NSDragOperation)draggingSession:(NSDraggingSession *)session sourceOperationMaskForDraggingContext:(NSDraggingContext)context {
    return NSDragOperationCopy;
}
- (void)draggingSession:(NSDraggingSession *)session endedAtPoint:(NSPoint)screenPoint operation:(NSDragOperation)operation {
    (void)session;
    NSURL *url = self.draggedURL;
    self.draggedURL = nil;
    if (!url || operation == NSDragOperationNone) return;
    if (self.window && NSPointInRect(screenPoint, self.window.frame)) return;
    [self.model removeURL:url];
    if (!self.model.files.count) [self.window orderOut:nil];
}
- (NSDragOperation)draggingEntered:(id<NSDraggingInfo>)sender {
    if (![sender.draggingPasteboard availableTypeFromArray:@[NSPasteboardTypeFileURL]]) return NSDragOperationNone;
    self.dropTarget = YES;
    self.needsDisplay = YES;
    return NSDragOperationCopy;
}
- (void)draggingExited:(id<NSDraggingInfo>)sender {
    self.dropTarget = NO;
    self.needsDisplay = YES;
}
- (BOOL)prepareForDragOperation:(id<NSDraggingInfo>)sender { return YES; }
- (BOOL)performDragOperation:(id<NSDraggingInfo>)sender {
    self.dropTarget = NO;
    NSArray *urls = [sender.draggingPasteboard readObjectsForClasses:@[NSURL.class]
                                                             options:@{NSPasteboardURLReadingFileURLsOnlyKey: @YES}] ?: @[];
    self.needsDisplay = YES;
    return [self.model addURLs:urls] > 0;
}
@end

@interface SLShelfRootView : NSVisualEffectView
@property(nonatomic, strong) SLShelfModel *model;
@property(nonatomic, strong) NSTextField *countLabel;
@property(nonatomic, strong) SLFileGridView *gridView;
@property(nonatomic, copy) void (^onClose)(void);
- (instancetype)initWithModel:(SLShelfModel *)model;
- (void)refresh;
@end

@implementation SLShelfRootView
- (instancetype)initWithModel:(SLShelfModel *)model {
    self = [super initWithFrame:NSZeroRect];
    if (!self) return nil;
    _model = model;
    self.material = NSVisualEffectMaterialHUDWindow;
    self.blendingMode = NSVisualEffectBlendingModeBehindWindow;
    self.state = NSVisualEffectStateActive;
    self.wantsLayer = YES;
    self.layer.cornerRadius = 18;
    self.layer.masksToBounds = YES;

    NSTextField *title = [NSTextField labelWithString:SL(@"shelf.title")];
    title.font = [NSFont systemFontOfSize:17 weight:NSFontWeightSemibold];
    _countLabel = [NSTextField labelWithString:SL(@"shelf.empty")];
    _countLabel.font = [NSFont systemFontOfSize:11 weight:NSFontWeightMedium];
    _countLabel.textColor = [NSColor.whiteColor colorWithAlphaComponent:0.66];
    _gridView = [[SLFileGridView alloc] initWithModel:model];

    NSButton *clear = [self buttonWithSymbol:@"trash" help:SL(@"action.clear") action:@selector(clearShelf:)];
    NSButton *close = [self buttonWithSymbol:@"xmark" help:SL(@"action.hide") action:@selector(closeShelf:)];
    NSArray<NSView *> *views = @[title, _countLabel, _gridView, clear, close];
    for (NSView *view in views) {
        view.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:view];
    }
    [NSLayoutConstraint activateConstraints:@[
        [title.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:18],
        [title.topAnchor constraintEqualToAnchor:self.topAnchor constant:15],
        [_countLabel.leadingAnchor constraintEqualToAnchor:title.trailingAnchor constant:9],
        [_countLabel.firstBaselineAnchor constraintEqualToAnchor:title.firstBaselineAnchor],
        [close.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-13],
        [close.centerYAnchor constraintEqualToAnchor:title.centerYAnchor],
        [close.widthAnchor constraintEqualToConstant:28], [close.heightAnchor constraintEqualToConstant:28],
        [clear.trailingAnchor constraintEqualToAnchor:close.leadingAnchor constant:-4],
        [clear.centerYAnchor constraintEqualToAnchor:close.centerYAnchor],
        [clear.widthAnchor constraintEqualToConstant:28], [clear.heightAnchor constraintEqualToConstant:28],
        [_gridView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:12],
        [_gridView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-12],
        [_gridView.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:12],
        [_gridView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-12]
    ]];
    [self refresh];
    return self;
}
- (NSButton *)buttonWithSymbol:(NSString *)symbol help:(NSString *)help action:(SEL)action {
    NSImage *image = [NSImage imageWithSystemSymbolName:symbol accessibilityDescription:help] ?: [[NSImage alloc] init];
    NSButton *button = [NSButton buttonWithImage:image target:self action:action];
    button.bordered = NO;
    button.contentTintColor = [NSColor.whiteColor colorWithAlphaComponent:0.72];
    button.toolTip = help;
    return button;
}
- (void)refresh {
    self.countLabel.stringValue = self.model.files.count ? [NSString stringWithFormat:@"%lu", self.model.files.count] : SL(@"shelf.empty");
    self.gridView.needsDisplay = YES;
}
- (void)clearShelf:(id)sender { [self.model clear]; }
- (void)closeShelf:(id)sender { if (self.onClose) self.onClose(); }
@end

@interface SLShelfPanel : NSPanel @end
@implementation SLShelfPanel
- (BOOL)canBecomeKeyWindow { return YES; }
- (BOOL)canBecomeMainWindow { return NO; }
@end

@interface SLShelfPanelController : NSWindowController
@property(nonatomic, strong) SLShelfRootView *rootView;
- (instancetype)initWithModel:(SLShelfModel *)model;
- (void)showNearPointer;
- (void)toggle;
@end

@implementation SLShelfPanelController
- (instancetype)initWithModel:(SLShelfModel *)model {
    _rootView = [[SLShelfRootView alloc] initWithModel:model];
    SLShelfPanel *panel = [[SLShelfPanel alloc] initWithContentRect:NSMakeRect(0, 0, 500, 270)
                                                          styleMask:NSWindowStyleMaskNonactivatingPanel | NSWindowStyleMaskFullSizeContentView | NSWindowStyleMaskResizable
                                                            backing:NSBackingStoreBuffered defer:NO];
    panel.contentView = _rootView;
    panel.minSize = NSMakeSize(360, 210);
    panel.maxSize = NSMakeSize(760, 520);
    panel.titleVisibility = NSWindowTitleHidden;
    panel.titlebarAppearsTransparent = YES;
    // The panel moves by its background, while SLFileGridView opts out so
    // dragging a file never turns into moving the window.
    panel.movableByWindowBackground = YES;
    panel.floatingPanel = YES;
    panel.becomesKeyOnlyIfNeeded = YES;
    panel.hidesOnDeactivate = NO;
    panel.releasedWhenClosed = NO;
    panel.backgroundColor = NSColor.clearColor;
    panel.opaque = NO;
    panel.hasShadow = YES;
    panel.level = NSFloatingWindowLevel;
    panel.collectionBehavior = NSWindowCollectionBehaviorCanJoinAllSpaces | NSWindowCollectionBehaviorFullScreenAuxiliary | NSWindowCollectionBehaviorStationary;
    self = [super initWithWindow:panel];
    if (self) {
        __weak typeof(self) weakSelf = self;
        _rootView.onClose = ^{ [weakSelf.window orderOut:nil]; };
    }
    return self;
}
- (void)showNearPointer {
    [self.rootView.model markUsed];
    NSPoint pointer = NSEvent.mouseLocation;
    NSScreen *screen = NSScreen.mainScreen;
    for (NSScreen *candidate in NSScreen.screens) {
        if (NSPointInRect(pointer, candidate.frame)) { screen = candidate; break; }
    }
    NSRect visible = screen.visibleFrame;
    NSSize size = self.window.frame.size;
    CGFloat x = pointer.x - size.width / 2;
    CGFloat y = pointer.y - size.height - 24;
    if (y < NSMinY(visible)) y = pointer.y + 24;
    x = MIN(MAX(x, NSMinX(visible) + 12), NSMaxX(visible) - size.width - 12);
    y = MIN(MAX(y, NSMinY(visible) + 12), NSMaxY(visible) - size.height - 12);
    [self.window setFrameOrigin:NSMakePoint(x, y)];
    [self.window orderFrontRegardless];
}
- (void)toggle { self.window.visible ? [self.window orderOut:nil] : [self showNearPointer]; }
@end

@interface SLShakeDetector : NSObject
@property(nonatomic) BOOL enabled;
@property(nonatomic, copy) void (^onShake)(void);
@property(nonatomic, strong) NSTimer *timer;
@property(nonatomic, strong) SLShakeAnalyzer *analyzer;
@property(nonatomic) BOOL wasPressed;
@property(nonatomic) NSTimeInterval lastTrigger;
@property(nonatomic) NSInteger idleDragPasteboardChangeCount;
@property(nonatomic) BOOL activeFileDrag;
- (void)start;
- (void)stop;
@end

@implementation SLShakeDetector
- (instancetype)init {
    self = [super init];
    if (self) {
        _enabled = YES;
        _analyzer = [[SLShakeAnalyzer alloc] init];
        _idleDragPasteboardChangeCount = [NSPasteboard pasteboardWithName:NSPasteboardNameDrag].changeCount;
    }
    return self;
}
- (void)start {
    if (self.timer) return;
    self.timer = [NSTimer timerWithTimeInterval:1.0 / 60.0 target:self selector:@selector(samplePointer:) userInfo:nil repeats:YES];
    [NSRunLoop.mainRunLoop addTimer:self.timer forMode:NSRunLoopCommonModes];
}
- (void)stop { [self.timer invalidate]; self.timer = nil; [self.analyzer reset]; }
- (void)samplePointer:(NSTimer *)timer {
    if (!self.enabled) { [self.analyzer reset]; return; }
    NSPasteboard *dragPasteboard = [NSPasteboard pasteboardWithName:NSPasteboardNameDrag];
    BOOL pressed = CGEventSourceButtonState(kCGEventSourceStateCombinedSessionState, kCGMouseButtonLeft);
    if (!pressed) {
        if (self.wasPressed) [self.analyzer reset];
        self.wasPressed = NO;
        self.activeFileDrag = NO;
        self.idleDragPasteboardChangeCount = dragPasteboard.changeCount;
        return;
    }
    if (!self.wasPressed) {
        [self.analyzer reset];
        self.wasPressed = YES;
        self.activeFileDrag = NO;
    }

    // NSPasteboardNameDrag keeps its old contents after a drag finishes.
    // Requiring a new changeCount during this exact mouse press prevents a
    // stale file URL from turning an ordinary mouse shake into a trigger.
    if (dragPasteboard.changeCount != self.idleDragPasteboardChangeCount) {
        self.activeFileDrag = [dragPasteboard availableTypeFromArray:@[NSPasteboardTypeFileURL]] != nil;
    }

    NSTimeInterval now = NSProcessInfo.processInfo.systemUptime;
    if (![self.analyzer updateWithX:NSEvent.mouseLocation.x time:now] || now - self.lastTrigger <= 1.2) return;
    if (!self.activeFileDrag) return;
    self.lastTrigger = now;
    if (self.onShake) self.onShake();
}
@end

@interface SLAppDelegate : NSObject <NSApplicationDelegate, NSMenuDelegate>
@property(nonatomic, strong) SLShelfModel *model;
@property(nonatomic, strong) SLShakeDetector *shakeDetector;
@property(nonatomic, strong) SLShelfPanelController *panelController;
@property(nonatomic, strong) NSStatusItem *statusItem;
@property(nonatomic, strong) NSMenuItem *countMenuItem;
@property(nonatomic, strong) NSMenuItem *shakeMenuItem;
@property(nonatomic, strong) NSMenuItem *launchAtLoginMenuItem;
@end

@implementation SLAppDelegate
- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    self.model = [[SLShelfModel alloc] init];
    self.shakeDetector = [[SLShakeDetector alloc] init];
    self.panelController = [[SLShelfPanelController alloc] initWithModel:self.model];
    [self configureStatusItem];

    id saved = [NSUserDefaults.standardUserDefaults objectForKey:@"shakeEnabled"];
    self.shakeDetector.enabled = saved ? [saved boolValue] : YES;
    __weak typeof(self) weakSelf = self;
    self.shakeDetector.onShake = ^{ [weakSelf.panelController showNearPointer]; };
    self.model.onChange = ^{
        [weakSelf.panelController.rootView refresh];
        [weakSelf refreshMenu];
    };
    [self.shakeDetector start];
    [self.panelController showNearPointer];
}
- (void)applicationWillTerminate:(NSNotification *)notification { [self.shakeDetector stop]; }
- (NSMenuItem *)addItemToMenu:(NSMenu *)menu title:(NSString *)title action:(SEL)action key:(NSString *)key modifiers:(NSEventModifierFlags)modifiers {
    NSMenuItem *item = [menu addItemWithTitle:title action:action keyEquivalent:key];
    item.target = self;
    item.keyEquivalentModifierMask = modifiers;
    return item;
}
- (void)configureStatusItem {
    self.statusItem = [NSStatusBar.systemStatusBar statusItemWithLength:NSSquareStatusItemLength];
    self.statusItem.button.image = [NSImage imageWithSystemSymbolName:@"tray.full" accessibilityDescription:@"Shelflet"];
    self.statusItem.button.toolTip = SL(@"menu.tooltip");
    NSMenu *menu = [[NSMenu alloc] init];
    menu.delegate = self;
    self.countMenuItem = [menu addItemWithTitle:SL(@"menu.empty") action:nil keyEquivalent:@""];
    self.countMenuItem.enabled = NO;
    [menu addItem:NSMenuItem.separatorItem];
    [self addItemToMenu:menu title:SL(@"menu.show") action:@selector(toggleShelf:) key:@"s" modifiers:NSEventModifierFlagCommand | NSEventModifierFlagOption];
    [self addItemToMenu:menu title:SL(@"menu.add_clipboard") action:@selector(addFromClipboard:) key:@"v" modifiers:NSEventModifierFlagCommand | NSEventModifierFlagOption];
    [self addItemToMenu:menu title:SL(@"menu.clear") action:@selector(clearShelf:) key:@"" modifiers:0];
    [menu addItem:NSMenuItem.separatorItem];
    self.shakeMenuItem = [self addItemToMenu:menu title:SL(@"menu.shake") action:@selector(toggleShake:) key:@"" modifiers:0];
    self.launchAtLoginMenuItem = [self addItemToMenu:menu title:SL(@"menu.launch") action:@selector(toggleLaunchAtLogin:) key:@"" modifiers:0];
    [menu addItem:NSMenuItem.separatorItem];
    [self addItemToMenu:menu title:SL(@"menu.about") action:@selector(showAbout:) key:@"" modifiers:0];
    [self addItemToMenu:menu title:SL(@"menu.quit") action:@selector(quit:) key:@"q" modifiers:NSEventModifierFlagCommand];
    self.statusItem.menu = menu;
    [self refreshMenu];
}
- (void)menuWillOpen:(NSMenu *)menu { [self refreshMenu]; }
- (void)refreshMenu {
    self.countMenuItem.title = self.model.files.count ? [NSString stringWithFormat:SL(@"menu.count"), self.model.files.count] : SL(@"menu.empty");
    self.shakeMenuItem.state = self.shakeDetector.enabled ? NSControlStateValueOn : NSControlStateValueOff;
    SMAppServiceStatus loginStatus = SMAppService.mainAppService.status;
    self.launchAtLoginMenuItem.title = loginStatus == SMAppServiceStatusRequiresApproval
        ? SL(@"menu.launch_approval")
        : SL(@"menu.launch");
    self.launchAtLoginMenuItem.state = loginStatus == SMAppServiceStatusEnabled
        ? NSControlStateValueOn
        : (loginStatus == SMAppServiceStatusRequiresApproval ? NSControlStateValueMixed : NSControlStateValueOff);
}
- (void)toggleShelf:(id)sender { [self.panelController toggle]; }
- (void)addFromClipboard:(id)sender {
    if ([self.model addFromPasteboard:NSPasteboard.generalPasteboard] > 0) [self.panelController showNearPointer];
    else NSBeep();
}
- (void)clearShelf:(id)sender { [self.model clear]; }
- (void)toggleShake:(id)sender {
    self.shakeDetector.enabled = !self.shakeDetector.enabled;
    [NSUserDefaults.standardUserDefaults setBool:self.shakeDetector.enabled forKey:@"shakeEnabled"];
    [self refreshMenu];
}
- (void)toggleLaunchAtLogin:(id)sender {
    (void)sender;
    SMAppService *service = SMAppService.mainAppService;
    NSError *error = nil;
    BOOL registered = NO;
    if (service.status == SMAppServiceStatusEnabled || service.status == SMAppServiceStatusRequiresApproval) {
        registered = [service unregisterAndReturnError:&error];
    } else {
        registered = [service registerAndReturnError:&error];
    }
    [self refreshMenu];
    if (!registered && error) {
        [NSApp activateIgnoringOtherApps:YES];
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = SL(@"alert.launch_failed");
        alert.informativeText = error.localizedDescription;
        alert.alertStyle = NSAlertStyleWarning;
        [alert addButtonWithTitle:SL(@"common.ok")];
        [alert runModal];
    } else if (service.status == SMAppServiceStatusRequiresApproval) {
        [NSApp activateIgnoringOtherApps:YES];
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = SL(@"alert.launch_approval_title");
        alert.informativeText = SL(@"alert.launch_approval_message");
        alert.alertStyle = NSAlertStyleInformational;
        [alert addButtonWithTitle:SL(@"common.got_it")];
        [alert runModal];
    }
}
- (void)showAbout:(id)sender {
    [NSApp orderFrontStandardAboutPanelWithOptions:@{
        NSAboutPanelOptionApplicationName: @"Shelflet",
        NSAboutPanelOptionApplicationVersion: NSBundle.mainBundle.infoDictionary[@"CFBundleShortVersionString"] ?: @"",
        NSAboutPanelOptionCredits: [[NSAttributedString alloc] initWithString:SL(@"about.credits")]
    }];
    [NSApp activateIgnoringOtherApps:YES];
}
- (void)quit:(id)sender { [NSApp terminate:nil]; }
@end

int main(int argc, const char *argv[]) {
    (void)argc;
    (void)argv;
    @autoreleasepool {
        NSApplication *application = NSApplication.sharedApplication;
        SLAppDelegate *delegate = [[SLAppDelegate alloc] init];
        application.delegate = delegate;
        [application setActivationPolicy:NSApplicationActivationPolicyAccessory];
        [application run];
    }
    return 0;
}
