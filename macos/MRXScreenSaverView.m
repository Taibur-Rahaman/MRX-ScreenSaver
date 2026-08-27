#import <ScreenSaver/ScreenSaver.h>
#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>

@interface MRXDigitState : NSObject
@property(nonatomic, assign) NSInteger current;
@property(nonatomic, assign) NSInteger oldDigit;
@property(nonatomic, assign) NSInteger newDigit;
@property(nonatomic, assign) double progress;
@property(nonatomic, assign) BOOL isFlipping;
@property(nonatomic, assign) CFTimeInterval start;
@end

@implementation MRXDigitState
@end

@interface MRXScreenSaverView : ScreenSaverView
@end

@implementation MRXScreenSaverView {
    NSMutableArray<MRXDigitState *> *_digits;
    NSString *_lastTimeKey;
    NSString *_ampm;
    NSString *_dateLabel;
    CFTimeInterval _flipDuration;
}

/// Match HTML canvas / Flipqlo: origin top-left, Y grows down.
- (BOOL)isFlipped {
    return YES;
}

- (instancetype)initWithFrame:(NSRect)frame isPreview:(BOOL)isPreview {
    self = [super initWithFrame:frame isPreview:isPreview];
    if (self) {
        _flipDuration = 0.65;
        _lastTimeKey = @"";
        _ampm = @"AM";
        _dateLabel = @"";
        _digits = [NSMutableArray arrayWithCapacity:6];
        for (int i = 0; i < 6; i++) {
            MRXDigitState *d = [MRXDigitState new];
            [_digits addObject:d];
        }
        self.wantsLayer = YES;
        self.layer.backgroundColor = NSColor.blackColor.CGColor;
        self.animationTimeInterval = 1.0 / 60.0;
        [self syncClockImmediate:YES];
    }
    return self;
}

- (void)startAnimation {
    [super startAnimation];
    [self ensureFullSize];
    [self syncClockImmediate:YES];
    self.needsDisplay = YES;
}

- (void)stopAnimation { [super stopAnimation]; }

- (void)viewDidMoveToWindow {
    [super viewDidMoveToWindow];
    [self ensureFullSize];
    self.needsDisplay = YES;
}

- (void)setFrameSize:(NSSize)newSize {
    [super setFrameSize:newSize];
    self.needsDisplay = YES;
}

- (void)animateOneFrame {
    [self ensureFullSize];
    [self syncClockImmediate:NO];
    [self advanceAnimations];
    self.needsDisplay = YES;
}

- (BOOL)hasConfigureSheet { return NO; }
- (NSWindow *)configureSheet { return nil; }

- (void)ensureFullSize {
    if (self.window != nil) {
        NSSize winSize = self.window.frame.size;
        if (winSize.width > 1 && winSize.height > 1) {
            if (fabs(self.bounds.size.width - winSize.width) > 1 ||
                fabs(self.bounds.size.height - winSize.height) > 1) {
                [self setFrameSize:winSize];
            }
            return;
        }
    }
    if (self.bounds.size.width > 1 && self.bounds.size.height > 1) return;
    NSSize target = self.window.screen.frame.size;
    if (target.width < 1 || target.height < 1) target = NSScreen.mainScreen.frame.size;
    if (target.width < 1 || target.height < 1) target = NSMakeSize(1440, 900);
    [self setFrameSize:target];
}

- (NSRect)safeDrawingBounds {
    NSRect b = self.bounds;
    NSSize screenPts = self.window.screen.frame.size;
    if (screenPts.width < 1 || screenPts.height < 1) screenPts = NSScreen.mainScreen.frame.size;
    if (screenPts.width > 1 && b.size.width > screenPts.width * 1.25) {
        b.size = screenPts;
        b.origin = NSZeroPoint;
    }
    return b;
}

#pragma mark - Clock

- (void)syncClockImmediate:(BOOL)immediate {
    NSDate *now = [NSDate date];
    NSCalendar *cal = NSCalendar.currentCalendar;
    NSInteger h24 = [cal component:NSCalendarUnitHour fromDate:now];
    NSInteger mins = [cal component:NSCalendarUnitMinute fromDate:now];
    NSInteger secs = [cal component:NSCalendarUnitSecond fromDate:now];
    _ampm = h24 >= 12 ? @"PM" : @"AM";
    NSInteger h12 = (h24 % 12 == 0) ? 12 : (h24 % 12);
    NSString *key = [NSString stringWithFormat:@"%02ld%02ld%02ld", (long)h12, (long)mins, (long)secs];

    static NSString *days[] = { @"SUN", @"MON", @"TUE", @"WED", @"THU", @"FRI", @"SAT" };
    static NSString *months[] = { @"JAN", @"FEB", @"MAR", @"APR", @"MAY", @"JUN", @"JUL", @"AUG", @"SEP", @"OCT", @"NOV", @"DEC" };
    NSInteger weekday = [cal component:NSCalendarUnitWeekday fromDate:now] - 1;
    NSInteger month = [cal component:NSCalendarUnitMonth fromDate:now] - 1;
    NSInteger day = [cal component:NSCalendarUnitDay fromDate:now];
    _dateLabel = [NSString stringWithFormat:@"%@  %@  %02ld", days[weekday], months[month], (long)day];

    if ([key isEqualToString:_lastTimeKey]) return;
    _lastTimeKey = key;

    CFTimeInterval t = CACurrentMediaTime();
    for (NSUInteger i = 0; i < 6; i++) {
        NSInteger next = [[key substringWithRange:NSMakeRange(i, 1)] integerValue];
        MRXDigitState *d = _digits[i];
        if (immediate || d.current == next) {
            d.current = d.oldDigit = d.newDigit = next;
            d.progress = 0;
            d.isFlipping = NO;
            d.start = t;
        } else {
            d.oldDigit = d.isFlipping ? d.newDigit : d.current;
            d.newDigit = next;
            d.current = next;
            d.progress = 0;
            d.isFlipping = YES;
            d.start = t;
        }
    }
}

- (void)advanceAnimations {
    CFTimeInterval now = CACurrentMediaTime();
    for (MRXDigitState *d in _digits) {
        if (!d.isFlipping) continue;
        double p = MIN(1.0, (now - d.start) / _flipDuration);
        d.progress = p;
        if (p >= 1.0) {
            d.isFlipping = NO;
            d.progress = 0;
            d.oldDigit = d.newDigit;
            d.current = d.newDigit;
        }
    }
}

#pragma mark - Draw (Y-down / flipped, same as canvas Flipqlo)

- (void)drawRect:(NSRect)dirtyRect {
    [self ensureFullSize];
    NSRect bounds = [self safeDrawingBounds];
    if (bounds.size.width <= 1 || bounds.size.height <= 1) return;
    [[NSColor colorWithCalibratedWhite:0.04 alpha:1] setFill];
    NSRectFill(self.bounds);
    [self drawClockInBounds:bounds];
}

- (void)drawClockInBounds:(NSRect)bounds {
    CGFloat cardH = bounds.size.height * 0.22;
    CGFloat cardW = cardH * 0.72;
    CGFloat interGap = cardH * 0.045;
    CGFloat groupGap = cardH * 0.08;
    CGFloat colonW = cardH * 0.18;

    CGFloat totalW = 0;
    for (int g = 0; g < 3; g++) {
        totalW += cardW + interGap + cardW;
        if (g < 2) totalW += groupGap + colonW + groupGap;
    }
    CGFloat maxW = bounds.size.width * 0.86;
    if (totalW > maxW && totalW > 1) {
        CGFloat s = maxW / totalW;
        cardH *= s; cardW *= s; interGap *= s; groupGap *= s; colonW *= s;
        totalW = maxW;
    }

    CGFloat cr = cardH * 0.05;
    CGFloat fontSize = cardH * 0.66;
    CGFloat x = (bounds.size.width - totalW) / 2.0;
    CGFloat y = NSMidY(bounds) - cardH / 2.0; // center (Y-down)
    CGFloat startX = x;

    [self drawLabel:_ampm at:NSMakePoint(startX, y - MAX(10, cardH * 0.18))
           fontSize:MAX(12, cardH * 0.11) color:[NSColor colorWithCalibratedWhite:0.55 alpha:1] align:0];

    for (int g = 0; g < 3; g++) {
        [self drawDigit:g * 2 x:x y:y w:cardW h:cardH cr:cr font:fontSize];
        x += cardW + interGap;
        [self drawDigit:g * 2 + 1 x:x y:y w:cardW h:cardH cr:cr font:fontSize];
        x += cardW;
        if (g < 2) {
            x += groupGap;
            [self drawColonX:x y:y w:colonW h:cardH];
            x += colonW + groupGap;
        }
    }

    [self drawLabel:_dateLabel at:NSMakePoint(NSMidX(bounds), y + cardH + MAX(18, cardH * 0.18))
           fontSize:MAX(14, cardH * 0.13) color:[NSColor colorWithCalibratedWhite:0.55 alpha:1] align:1];
    [self drawLabel:@"MRX" at:NSMakePoint(startX + totalW, y + cardH + MAX(36, cardH * 0.36))
           fontSize:MAX(11, cardH * 0.08) color:[NSColor colorWithCalibratedWhite:0.35 alpha:1] align:2];
}

- (NSDictionary *)digitAttrs:(CGFloat)fontSize {
    return @{
        NSFontAttributeName: [NSFont monospacedDigitSystemFontOfSize:fontSize weight:NSFontWeightBold],
        NSForegroundColorAttributeName: [NSColor colorWithCalibratedWhite:0.90 alpha:1],
    };
}

/// Y-down image matching isFlipped view (top at y=0).
- (NSImage *)cardImage:(NSInteger)digit w:(CGFloat)w h:(CGFloat)h font:(CGFloat)fontSize {
    NSImage *img = [[NSImage alloc] initWithSize:NSMakeSize(w, h)];
    [img lockFocusFlipped:YES];
    CGFloat half = h / 2.0;
    [[NSColor colorWithCalibratedRed:0.11 green:0.11 blue:0.11 alpha:1] setFill];
    NSRectFill(NSMakeRect(0, 0, w, h));
    [[NSColor colorWithCalibratedRed:0.16 green:0.16 blue:0.16 alpha:1] setFill];
    NSRectFill(NSMakeRect(0, 0, w, half));
    [[NSColor colorWithCalibratedRed:0.10 green:0.10 blue:0.10 alpha:1] setFill];
    NSRectFill(NSMakeRect(0, half, w, half));
    NSString *text = [NSString stringWithFormat:@"%ld", (long)digit];
    NSDictionary *attrs = [self digitAttrs:fontSize];
    NSSize size = [text sizeWithAttributes:attrs];
    [text drawAtPoint:NSMakePoint((w - size.width) / 2.0, (h - size.height) / 2.0) withAttributes:attrs];
    [img unlockFocus];
    return img;
}

- (void)drawDigit:(NSInteger)index x:(CGFloat)x y:(CGFloat)y w:(CGFloat)w h:(CGFloat)h cr:(CGFloat)cr font:(CGFloat)fontSize {
    CGFloat half = h / 2.0;
    MRXDigitState *st = _digits[index];
    BOOL anim = st.isFlipping;
    double progress = anim ? st.progress : 0;
    NSInteger oldD = anim ? st.oldDigit : st.current;
    NSInteger newD = anim ? st.newDigit : st.current;

    NSRect card = NSMakeRect(x, y, w, h);
    NSRect topClip = NSMakeRect(x, y, w, half);
    NSRect botClip = NSMakeRect(x, y + half, w, half);
    CGFloat hinge = y + half;

    NSImage *oldImg = [self cardImage:oldD w:w h:h font:fontSize];
    NSImage *newImg = [self cardImage:newD w:w h:h font:fontSize];

    [NSGraphicsContext saveGraphicsState];
    [[NSBezierPath bezierPathWithRoundedRect:card xRadius:cr yRadius:cr] addClip];

    if (!anim) {
        [newImg drawInRect:card fromRect:NSZeroRect operation:NSCompositingOperationCopy fraction:1
            respectFlipped:YES hints:nil];
    } else {
        // Upright halves only (no scaleY flap — AppKit image+scale caused black/180° artifacts).
        // Phase 1: reveal NEW top over OLD bottom. Phase 2: commit NEW bottom.
        [newImg drawInRect:topClip fromRect:NSMakeRect(0, half, w, half)
                 operation:NSCompositingOperationCopy fraction:1 respectFlipped:YES hints:nil];
        if (progress < 0.5) {
            [oldImg drawInRect:botClip fromRect:NSMakeRect(0, 0, w, half)
                     operation:NSCompositingOperationCopy fraction:1 respectFlipped:YES hints:nil];
            // Soft dim on top as “folding” cue (no inverted geometry)
            double t = progress / 0.5;
            [[NSColor colorWithCalibratedWhite:0 alpha:t * 0.25] setFill];
            NSRectFill(topClip);
        } else {
            [newImg drawInRect:botClip fromRect:NSMakeRect(0, 0, w, half)
                     operation:NSCompositingOperationCopy fraction:1 respectFlipped:YES hints:nil];
            double t = (progress - 0.5) / 0.5;
            [[NSColor colorWithCalibratedWhite:0 alpha:(1.0 - t) * 0.20] setFill];
            NSRectFill(botClip);
        }
    }
    [NSGraphicsContext restoreGraphicsState];

    [[NSColor colorWithCalibratedWhite:0.08 alpha:1] setStroke];
    NSBezierPath *div = [NSBezierPath bezierPath];
    div.lineWidth = 2;
    [div moveToPoint:NSMakePoint(x, hinge)];
    [div lineToPoint:NSMakePoint(x + w, hinge)];
    [div stroke];
}

- (void)drawColonX:(CGFloat)x y:(CGFloat)y w:(CGFloat)colonW h:(CGFloat)cardH {
    CGFloat r = cardH * 0.035;
    CGFloat cx = x + colonW / 2.0;
    [[NSColor colorWithCalibratedWhite:0.23 alpha:1] setFill];
    [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(cx - r, y + cardH * 0.35 - r, r * 2, r * 2)] fill];
    [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(cx - r, y + cardH * 0.65 - r, r * 2, r * 2)] fill];
}

- (void)drawLabel:(NSString *)s at:(NSPoint)p fontSize:(CGFloat)fs color:(NSColor *)c align:(int)align {
    NSDictionary *attrs = @{
        NSFontAttributeName: [NSFont systemFontOfSize:fs weight:NSFontWeightMedium],
        NSForegroundColorAttributeName: c,
    };
    NSSize size = [s sizeWithAttributes:attrs];
    CGFloat x = p.x;
    if (align == 1) x -= size.width / 2.0;
    if (align == 2) x -= size.width;
    [s drawAtPoint:NSMakePoint(x, p.y) withAttributes:attrs];
}

@end
