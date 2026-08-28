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

- (BOOL)isFlipped { return YES; }
- (BOOL)isOpaque { return YES; }
- (BOOL)wantsLayer { return NO; }
- (BOOL)wantsUpdateLayer { return NO; }

- (instancetype)initWithFrame:(NSRect)frame isPreview:(BOOL)isPreview {
    self = [super initWithFrame:frame isPreview:isPreview];
    if (self) {
        _flipDuration = 0.72;
        _lastTimeKey = @"";
        _ampm = @"AM";
        _dateLabel = @"";
        _digits = [NSMutableArray arrayWithCapacity:6];
        for (int i = 0; i < 6; i++) [_digits addObject:[MRXDigitState new]];
        self.animationTimeInterval = 1.0 / 60.0;
        [self syncClockImmediate:YES];
    }
    return self;
}

- (void)startAnimation {
    [super startAnimation];
    [self syncClockImmediate:YES];
    [self setNeedsDisplay:YES];
    [self display];
}
- (void)stopAnimation { [super stopAnimation]; }
- (void)viewDidMoveToWindow {
    [super viewDidMoveToWindow];
    [self setNeedsDisplay:YES];
    [self displayIfNeeded];
}
- (void)setFrameSize:(NSSize)newSize {
    [super setFrameSize:newSize];
    [self setNeedsDisplay:YES];
}
- (void)layout {
    [super layout];
    [self setNeedsDisplay:YES];
}
- (void)animateOneFrame {
    [self syncClockImmediate:NO];
    [self advanceAnimations];
    [self setNeedsDisplay:YES];
}
- (BOOL)hasConfigureSheet { return NO; }
- (NSWindow *)configureSheet { return nil; }

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
        if (immediate) {
            d.current = d.oldDigit = d.newDigit = next;
            d.progress = 0;
            d.isFlipping = NO;
        } else if (next == d.current) {
            // Digit unchanged — never cancel an in-progress flip (current is already next while animating).
            if (!d.isFlipping) {
                d.oldDigit = d.newDigit = next;
                d.progress = 0;
            }
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

#pragma mark - Paint helpers (NSString / AppKit — reliable in ScreenSaverEngine)

- (NSDictionary *)digitAttrs:(CGFloat)fontSize {
    return @{
        NSFontAttributeName: [NSFont monospacedDigitSystemFontOfSize:fontSize weight:NSFontWeightBold],
        NSForegroundColorAttributeName: [NSColor colorWithCalibratedWhite:0.92 alpha:1],
    };
}

- (void)fillCardFace:(NSRect)card half:(CGFloat)half {
    [[NSColor colorWithCalibratedRed:0.11 green:0.11 blue:0.11 alpha:1] setFill];
    NSRectFill(card);
    [[NSColor colorWithCalibratedRed:0.17 green:0.17 blue:0.17 alpha:1] setFill];
    NSRectFill(NSMakeRect(card.origin.x, card.origin.y, card.size.width, half));
    [[NSColor colorWithCalibratedRed:0.10 green:0.10 blue:0.10 alpha:1] setFill];
    NSRectFill(NSMakeRect(card.origin.x, card.origin.y + half, card.size.width, half));
    [[NSColor colorWithCalibratedWhite:1 alpha:0.06] setFill];
    NSRectFill(NSMakeRect(card.origin.x, card.origin.y, card.size.width, 4));
}

- (void)drawDigitGlyph:(NSInteger)digit inCard:(NSRect)card font:(CGFloat)fontSize {
    NSString *text = [NSString stringWithFormat:@"%ld", (long)digit];
    NSDictionary *attrs = [self digitAttrs:fontSize];
    NSSize size = [text sizeWithAttributes:attrs];
    NSPoint pt = NSMakePoint(
        NSMidX(card) - size.width / 2.0,
        NSMidY(card) - size.height / 2.0);
    [text drawAtPoint:pt withAttributes:attrs];
}

- (void)drawClippedDigit:(NSInteger)digit card:(NSRect)card clip:(NSRect)clip font:(CGFloat)fontSize {
    [NSGraphicsContext saveGraphicsState];
    [NSBezierPath clipRect:clip];
    [self drawDigitGlyph:digit inCard:card font:fontSize];
    [NSGraphicsContext restoreGraphicsState];
}

- (void)drawFlap:(BOOL)isTop
           digit:(NSInteger)digit
            card:(NSRect)card
            half:(CGFloat)half
            font:(CGFloat)fontSize
          scaleY:(CGFloat)sy
          scaleX:(CGFloat)sx
           shade:(CGFloat)shade {
    NSRect clip = isTop
        ? NSMakeRect(card.origin.x, card.origin.y, card.size.width, half)
        : NSMakeRect(card.origin.x, card.origin.y + half, card.size.width, half);
    CGFloat hingeY = card.origin.y + half;
    CGFloat cx = NSMidX(card);

    CGContextRef ctx = NSGraphicsContext.currentContext.CGContext;
    CGContextSaveGState(ctx);
    CGContextClipToRect(ctx, NSRectToCGRect(clip));
    CGContextTranslateCTM(ctx, cx, hingeY);
    CGContextScaleCTM(ctx, sx, sy);
    CGContextTranslateCTM(ctx, -cx, -hingeY);

    if (isTop) {
        [[NSColor colorWithCalibratedRed:0.17 green:0.17 blue:0.17 alpha:1] setFill];
    } else {
        [[NSColor colorWithCalibratedRed:0.10 green:0.10 blue:0.10 alpha:1] setFill];
    }
    NSRectFill(clip);
    [self drawClippedDigit:digit card:card clip:clip font:fontSize];

    if (shade > 0.01) {
        NSGradient *g;
        if (isTop) {
            g = [[NSGradient alloc]
                initWithStartingColor:[NSColor colorWithCalibratedWhite:0 alpha:MIN(0.55, shade)]
                          endingColor:[NSColor colorWithCalibratedWhite:0 alpha:0]];
            [g drawInRect:clip angle:90];
        } else {
            g = [[NSGradient alloc]
                initWithStartingColor:[NSColor colorWithCalibratedWhite:0 alpha:0]
                          endingColor:[NSColor colorWithCalibratedWhite:0 alpha:MIN(0.55, shade)]];
            [g drawInRect:clip angle:90];
        }
    }
  CGFloat rim = MAX(1.0, half * 0.035);
  [[NSColor colorWithCalibratedWhite:1 alpha:(isTop ? 0.10 : 0.06) * sy] setFill];
  if (isTop) {
    NSRectFill(NSMakeRect(card.origin.x, card.origin.y, card.size.width, rim));
  } else {
    NSRectFill(NSMakeRect(card.origin.x, NSMaxY(card) - rim, card.size.width, rim));
  }
    CGContextRestoreGState(ctx);
}

#pragma mark - Draw

- (void)drawRect:(NSRect)dirtyRect {
    NSRect bounds = self.bounds;
    if (bounds.size.width < 2 || bounds.size.height < 2) return;

    [[NSColor colorWithCalibratedWhite:0.04 alpha:1] setFill];
    NSRectFill(bounds);
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
        totalW += cardW * 2 + interGap;
        if (g < 2) totalW += groupGap * 2 + colonW;
    }
    CGFloat maxW = bounds.size.width * 0.86;
    if (totalW > maxW && totalW > 1) {
        CGFloat s = maxW / totalW;
        cardH *= s; cardW *= s; interGap *= s; groupGap *= s; colonW *= s;
        totalW = maxW;
    }
    CGFloat cr = cardH * 0.05;
    CGFloat fontSize = cardH * 0.66;
    CGFloat x = bounds.origin.x + (bounds.size.width - totalW) / 2.0;
    CGFloat y = NSMidY(bounds) - cardH / 2.0;
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

- (void)drawDigit:(NSInteger)index x:(CGFloat)x y:(CGFloat)y w:(CGFloat)w h:(CGFloat)h
               cr:(CGFloat)cr font:(CGFloat)fontSize {
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

    [NSGraphicsContext saveGraphicsState];
    [[NSBezierPath bezierPathWithRoundedRect:card xRadius:cr yRadius:cr] addClip];
    [self fillCardFace:card half:half];

    if (!anim) {
        [self drawClippedDigit:newD card:card clip:topClip font:fontSize];
        [self drawClippedDigit:newD card:card clip:botClip font:fontSize];
    } else {
        [self drawClippedDigit:newD card:card clip:topClip font:fontSize];
        [self drawClippedDigit:oldD card:card clip:botClip font:fontSize];

        if (progress < 0.5) {
            double t = progress / 0.5;
            double angle = t * M_PI_2;
            double sy = MAX(0.0, cos(angle));
            double sx = 1.0 - (1.0 - sy) * 0.18;
            double shade = sin(angle) * 0.42;
            if (shade > 0.02) {
                NSGradient *cast = [[NSGradient alloc]
                    initWithStartingColor:[NSColor colorWithCalibratedWhite:0 alpha:shade * 0.55]
                              endingColor:[NSColor colorWithCalibratedWhite:0 alpha:0]];
                [cast drawInRect:botClip angle:90];
            }
            if (sy > 0.04) {
                [self drawFlap:YES digit:oldD card:card half:half font:fontSize scaleY:sy scaleX:sx shade:shade];
            }
            if (sy < 0.22) {
                CGFloat thick = MAX(2.5, half * 0.06 * (1.0 - sy / 0.22));
                [[NSColor colorWithCalibratedWhite:0.36 alpha:0.95] setFill];
                NSRectFill(NSMakeRect(x, hinge - thick * 0.5, w, thick));
            }
        } else {
            double t = (progress - 0.5) / 0.5;
            double angle = t * M_PI_2;
            double sy = MAX(0.0, sin(angle));
            double sx = 1.0 - (1.0 - sy) * 0.18;
            double shade = cos(angle) * 0.42;
            if (shade > 0.02) {
                NSGradient *cast = [[NSGradient alloc]
                    initWithStartingColor:[NSColor colorWithCalibratedWhite:0 alpha:0]
                              endingColor:[NSColor colorWithCalibratedWhite:0 alpha:shade * 0.45]];
                [cast drawInRect:topClip angle:90];
            }
            if (sy > 0.04) {
                [self drawFlap:NO digit:newD card:card half:half font:fontSize scaleY:sy scaleX:sx shade:shade];
            }
            if (sy < 0.22) {
                CGFloat thick = MAX(2.5, half * 0.06 * (1.0 - sy / 0.22));
                [[NSColor colorWithCalibratedWhite:0.32 alpha:0.9] setFill];
                NSRectFill(NSMakeRect(x, hinge - thick * 0.5, w, thick));
            }
        }
    }
    [NSGraphicsContext restoreGraphicsState];

    [[NSColor colorWithCalibratedWhite:0.07 alpha:1] setStroke];
    NSBezierPath *div = [NSBezierPath bezierPath];
    div.lineWidth = 2;
    [div moveToPoint:NSMakePoint(x, hinge)];
    [div lineToPoint:NSMakePoint(x + w, hinge)];
    [div stroke];
}

- (void)drawColonX:(CGFloat)x y:(CGFloat)y w:(CGFloat)colonW h:(CGFloat)cardH {
    CGFloat r = cardH * 0.035, cx = x + colonW / 2.0;
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
