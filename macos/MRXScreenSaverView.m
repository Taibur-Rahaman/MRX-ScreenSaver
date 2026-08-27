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
    BOOL _isPreviewMode;
    CFTimeInterval _flipDuration;
}

- (instancetype)initWithFrame:(NSRect)frame isPreview:(BOOL)isPreview {
    self = [super initWithFrame:frame isPreview:isPreview];
    if (self) {
        _isPreviewMode = isPreview;
        _flipDuration = 0.6;
        _lastTimeKey = @"";
        _ampm = @"AM";
        _dateLabel = @"";
        _digits = [NSMutableArray arrayWithCapacity:6];
        for (int i = 0; i < 6; i++) {
            MRXDigitState *d = [MRXDigitState new];
            d.current = 0;
            d.oldDigit = 0;
            d.newDigit = 0;
            [_digits addObject:d];
        }
        self.wantsLayer = YES;
        self.layer.backgroundColor = NSColor.blackColor.CGColor;
        self.animationTimeInterval = 1.0 / 30.0;
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

- (void)stopAnimation {
    [super stopAnimation];
}

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

- (BOOL)hasConfigureSheet {
    return NO;
}

- (NSWindow *)configureSheet {
    return nil;
}

- (void)ensureFullSize {
    // Prefer the window's logical point size. ScreenSaver hosts sometimes report
    // backing-pixel bounds (2x), which makes the clock oversized and cropped.
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
    if (target.width < 1 || target.height < 1) {
        target = NSScreen.mainScreen.frame.size;
    }
    if (target.width < 1 || target.height < 1) {
        target = NSMakeSize(1440, 900);
    }
    [self setFrameSize:target];
}

- (NSRect)safeDrawingBounds {
    NSRect b = self.bounds;
    NSSize screenPts = self.window.screen.frame.size;
    if (screenPts.width < 1 || screenPts.height < 1) {
        screenPts = NSScreen.mainScreen.frame.size;
    }
    // If bounds look like backing pixels (~2x screen points), shrink to points.
    if (screenPts.width > 1 && b.size.width > screenPts.width * 1.25) {
        b.size.width = screenPts.width;
        b.size.height = screenPts.height;
        b.origin = NSZeroPoint;
    }
    return b;
}

#pragma mark - Clock state

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
            d.current = next;
            d.oldDigit = next;
            d.newDigit = next;
            d.progress = 0;
            d.isFlipping = NO;
            d.start = t;
        } else {
            NSInteger old = d.isFlipping ? d.newDigit : d.current;
            d.oldDigit = old;
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

#pragma mark - Drawing

- (void)drawRect:(NSRect)dirtyRect {
    [self ensureFullSize];
    NSRect bounds = [self safeDrawingBounds];
    if (bounds.size.width <= 1 || bounds.size.height <= 1) return;

    [[NSColor colorWithCalibratedWhite:0.04 alpha:1] setFill];
    NSRectFill(self.bounds);
    [self drawClockInBounds:bounds];
}

- (void)drawClockInBounds:(NSRect)bounds {
    // Medium scale: ~20% of height, never wider than ~78% of the screen.
    CGFloat cardH = bounds.size.height * 0.20;
    CGFloat cardW = cardH * 0.72;
    CGFloat interGap = cardH * 0.045;
    CGFloat groupGap = cardH * 0.08;
    CGFloat colonW = cardH * 0.18;

    CGFloat totalW = 0;
    for (int g = 0; g < 3; g++) {
        totalW += cardW + interGap + cardW;
        if (g < 2) totalW += groupGap + colonW + groupGap;
    }

    CGFloat maxW = bounds.size.width * 0.78;
    if (totalW > maxW && totalW > 1) {
        CGFloat s = maxW / totalW;
        cardH *= s;
        cardW *= s;
        interGap *= s;
        groupGap *= s;
        colonW *= s;
        totalW = maxW;
    }

    CGFloat cr = cardH * 0.05;
    CGFloat fontSize = cardH * 0.66;

    CGFloat x = (bounds.size.width - totalW) / 2.0;
    CGFloat y = NSMidY(bounds) - cardH / 2.0;
    CGFloat startX = x;

    [self drawText:_ampm
           atPoint:NSMakePoint(startX, y + cardH + MAX(10, cardH * 0.08))
          fontSize:MAX(12, cardH * 0.11)
             color:[NSColor colorWithCalibratedWhite:0.55 alpha:1]
             align:0];

    for (int g = 0; g < 3; g++) {
        [self drawDigitAtIndex:g * 2 x:x y:y w:cardW h:cardH cr:cr fontSize:fontSize];
        x += cardW + interGap;
        [self drawDigitAtIndex:g * 2 + 1 x:x y:y w:cardW h:cardH cr:cr fontSize:fontSize];
        x += cardW;
        if (g < 2) {
            x += groupGap;
            [self drawColonAtX:x y:y colonW:colonW cardH:cardH];
            x += colonW + groupGap;
        }
    }

    [self drawText:_dateLabel
           atPoint:NSMakePoint(NSMidX(bounds), y - MAX(28, cardH * 0.28))
          fontSize:MAX(14, cardH * 0.13)
             color:[NSColor colorWithCalibratedWhite:0.55 alpha:1]
             align:1];

    [self drawText:@"MRX"
           atPoint:NSMakePoint(startX + totalW, y - MAX(48, cardH * 0.48))
          fontSize:MAX(11, cardH * 0.08)
             color:[NSColor colorWithCalibratedWhite:0.35 alpha:1]
             align:2];
}

- (void)drawDigitAtIndex:(NSInteger)index
                       x:(CGFloat)x
                       y:(CGFloat)y
                       w:(CGFloat)w
                       h:(CGFloat)h
                      cr:(CGFloat)cr
                fontSize:(CGFloat)fontSize {
    CGFloat half = h / 2.0;
    MRXDigitState *state = _digits[index];
    BOOL animating = state.isFlipping;
    double progress = animating ? state.progress : 0;
    NSInteger oldD = animating ? state.oldDigit : state.current;
    NSInteger newD = animating ? state.newDigit : state.current;

    NSRect cardRect = NSMakeRect(x, y, w, h);
    NSBezierPath *round = [NSBezierPath bezierPathWithRoundedRect:cardRect xRadius:cr yRadius:cr];

    [NSGraphicsContext saveGraphicsState];
    [round addClip];
    [[NSColor colorWithCalibratedRed:0.11 green:0.11 blue:0.11 alpha:1] setFill];
    NSRectFill(cardRect);
    [[NSColor colorWithCalibratedRed:0.14 green:0.14 blue:0.14 alpha:1] setFill];
    NSRectFill(NSMakeRect(x, y + half, w, half));
    [[NSColor colorWithCalibratedRed:0.086 green:0.086 blue:0.086 alpha:1] setFill];
    NSRectFill(NSMakeRect(x, y, w, half));
    [NSGraphicsContext restoreGraphicsState];

    NSRect topClip = NSMakeRect(x, y + half, w, half);
    NSRect botClip = NSMakeRect(x, y, w, half);

    if (!animating) {
        [self drawClippedDigit:newD card:cardRect clip:topClip fontSize:fontSize];
        [self drawClippedDigit:newD card:cardRect clip:botClip fontSize:fontSize];
    } else {
        // Static NEW top / OLD bottom
        [self drawClippedDigit:newD card:cardRect clip:topClip fontSize:fontSize];
        [self drawClippedDigit:oldD card:cardRect clip:botClip fontSize:fontSize];

        if (progress < 0.5) {
            double phase = progress / 0.5;
            double eased = phase * phase;
            double scaleY = 1.0 - eased;
            if (scaleY > 0.02) {
                [NSGraphicsContext saveGraphicsState];
                [NSBezierPath clipRect:topClip];
                NSAffineTransform *t = [NSAffineTransform transform];
                [t translateXBy:x + w / 2 yBy:y + half];
                [t scaleXBy:1 yBy:scaleY];
                [t translateXBy:-(x + w / 2) yBy:-(y + half)];
                [t concat];
                [[NSColor colorWithCalibratedRed:0.14 green:0.14 blue:0.14 alpha:1] setFill];
                NSRectFill(topClip);
                [self drawClippedDigit:oldD card:cardRect clip:topClip fontSize:fontSize];
                [[NSColor colorWithCalibratedWhite:0 alpha:eased * 0.35] setFill];
                NSRectFill(topClip);
                [NSGraphicsContext restoreGraphicsState];
            }
        } else {
            double phase = (progress - 0.5) / 0.5;
            double eased = 1.0 - (1.0 - phase) * (1.0 - phase);
            double scaleY = eased;
            if (scaleY > 0.02) {
                [NSGraphicsContext saveGraphicsState];
                [NSBezierPath clipRect:botClip];
                NSAffineTransform *t = [NSAffineTransform transform];
                [t translateXBy:x + w / 2 yBy:y + half];
                [t scaleXBy:1 yBy:scaleY];
                [t translateXBy:-(x + w / 2) yBy:-(y + half)];
                [t concat];
                [[NSColor colorWithCalibratedRed:0.086 green:0.086 blue:0.086 alpha:1] setFill];
                NSRectFill(botClip);
                [self drawClippedDigit:newD card:cardRect clip:botClip fontSize:fontSize];
                [[NSColor colorWithCalibratedWhite:0 alpha:(1.0 - eased) * 0.35] setFill];
                NSRectFill(botClip);
                [NSGraphicsContext restoreGraphicsState];
            }
        }
    }

    // Divider
    [[NSColor blackColor] setStroke];
    NSBezierPath *shadow = [NSBezierPath bezierPath];
    shadow.lineWidth = 1;
    [shadow moveToPoint:NSMakePoint(x, y + half - 1)];
    [shadow lineToPoint:NSMakePoint(x + w, y + half - 1)];
    [shadow stroke];

    [[NSColor colorWithCalibratedWhite:0.06 alpha:1] setStroke];
    NSBezierPath *div = [NSBezierPath bezierPath];
    div.lineWidth = 2;
    [div moveToPoint:NSMakePoint(x, y + half)];
    [div lineToPoint:NSMakePoint(x + w, y + half)];
    [div stroke];
}

- (void)drawClippedDigit:(NSInteger)digit
                    card:(NSRect)card
                    clip:(NSRect)clip
                fontSize:(CGFloat)fontSize {
    [NSGraphicsContext saveGraphicsState];
    [NSBezierPath clipRect:clip];

    NSString *text = [NSString stringWithFormat:@"%ld", (long)digit];
    NSDictionary *attrs = @{
        NSFontAttributeName: [NSFont boldSystemFontOfSize:fontSize],
        NSForegroundColorAttributeName: [NSColor colorWithCalibratedWhite:0.847 alpha:1],
    };
    NSSize size = [text sizeWithAttributes:attrs];
    NSPoint p = NSMakePoint(NSMidX(card) - size.width / 2.0,
                            NSMidY(card) - size.height / 2.0);
    [text drawAtPoint:p withAttributes:attrs];

    [NSGraphicsContext restoreGraphicsState];
}

- (void)drawColonAtX:(CGFloat)x y:(CGFloat)y colonW:(CGFloat)colonW cardH:(CGFloat)cardH {
    CGFloat r = cardH * 0.035;
    CGFloat cx = x + colonW / 2.0;
    [[NSColor colorWithCalibratedWhite:0.23 alpha:1] setFill];
    [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(cx - r, y + cardH * 0.35 - r, r * 2, r * 2)] fill];
    [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(cx - r, y + cardH * 0.65 - r, r * 2, r * 2)] fill];
}

/// align: 0 left, 1 center, 2 right
- (void)drawText:(NSString *)string
         atPoint:(NSPoint)point
        fontSize:(CGFloat)fontSize
           color:(NSColor *)color
           align:(int)align {
    NSDictionary *attrs = @{
        NSFontAttributeName: [NSFont systemFontOfSize:fontSize],
        NSForegroundColorAttributeName: color,
    };
    NSSize size = [string sizeWithAttributes:attrs];
    CGFloat x = point.x;
    if (align == 1) x -= size.width / 2.0;
    if (align == 2) x -= size.width;
    [string drawAtPoint:NSMakePoint(x, point.y) withAttributes:attrs];
}

@end
