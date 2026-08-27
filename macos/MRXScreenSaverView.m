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
    NSImage *_faces[10];
    CGFloat _faceW, _faceH, _faceFont;
}

- (BOOL)isFlipped { return YES; }

- (instancetype)initWithFrame:(NSRect)frame isPreview:(BOOL)isPreview {
    self = [super initWithFrame:frame isPreview:isPreview];
    if (self) {
        _flipDuration = 0.72;
        _lastTimeKey = @"";
        _ampm = @"AM";
        _dateLabel = @"";
        memset(_faces, 0, sizeof(_faces));
        _digits = [NSMutableArray arrayWithCapacity:6];
        for (int i = 0; i < 6; i++) [_digits addObject:[MRXDigitState new]];
        // Do NOT use wantsLayer — legacyScreenSaver often shows layer.background only (black).
        self.animationTimeInterval = 1.0 / 60.0;
        [self syncClockImmediate:YES];
    }
    return self;
}

- (BOOL)isOpaque { return YES; }

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
    [self setNeedsDisplay:YES];
    [self displayIfNeeded];
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

- (NSSize)targetScreenSize {
    NSScreen *screen = self.window.screen ?: NSScreen.mainScreen;
    NSSize target = screen.frame.size;
    if (self.window != nil) {
        NSSize winSize = self.window.frame.size;
        if (winSize.width > 1 && winSize.height > 1) target = winSize;
    }
    if (target.width < 1 || target.height < 1) target = NSMakeSize(1440, 900);
    return target;
}

- (void)ensureFullSize {
    NSSize target = [self targetScreenSize];
    if (fabs(self.bounds.size.width - target.width) > 1 ||
        fabs(self.bounds.size.height - target.height) > 1) {
        [self setFrameSize:target];
    }
}

- (NSRect)effectiveDrawingBounds {
    NSRect b = self.bounds;
    if (b.size.width > 1 && b.size.height > 1) {
        NSSize screenPts = [self targetScreenSize];
        if (screenPts.width > 1 && b.size.width > screenPts.width * 1.25) {
            b.size = screenPts;
            b.origin = NSZeroPoint;
        }
        return b;
    }
    NSSize target = [self targetScreenSize];
    return NSMakeRect(0, 0, target.width, target.height);
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

#pragma mark - Faces (Y-down via lockFocusFlipped — matches isFlipped view)

- (void)warmFaces:(CGFloat)w h:(CGFloat)h font:(CGFloat)font {
    if (fabs(w - _faceW) < 0.5 && fabs(h - _faceH) < 0.5 && fabs(font - _faceFont) < 0.5 && _faces[0]) return;
    for (int i = 0; i < 10; i++) _faces[i] = nil;
    _faceW = w; _faceH = h; _faceFont = font;
    for (int d = 0; d < 10; d++) _faces[d] = [self makeFace:d w:w h:h font:font];
}

- (NSImage *)makeFace:(NSInteger)digit w:(CGFloat)w h:(CGFloat)h font:(CGFloat)fontSize {
    NSImage *img = [[NSImage alloc] initWithSize:NSMakeSize(w, h)];
    [img lockFocusFlipped:YES];
    CGFloat half = h / 2.0;
    [[NSColor colorWithCalibratedRed:0.11 green:0.11 blue:0.11 alpha:1] setFill];
    NSRectFill(NSMakeRect(0, 0, w, h));
    [[NSColor colorWithCalibratedRed:0.17 green:0.17 blue:0.17 alpha:1] setFill];
    NSRectFill(NSMakeRect(0, 0, w, half)); // top (Y-down)
    [[NSColor colorWithCalibratedRed:0.10 green:0.10 blue:0.10 alpha:1] setFill];
    NSRectFill(NSMakeRect(0, half, w, half)); // bottom
    [[NSColor colorWithCalibratedWhite:1 alpha:0.06] setFill];
    NSRectFill(NSMakeRect(0, 0, w, 4));

    NSString *text = [NSString stringWithFormat:@"%ld", (long)digit];
    NSDictionary *attrs = @{
        NSFontAttributeName: [NSFont monospacedDigitSystemFontOfSize:fontSize weight:NSFontWeightBold],
        NSForegroundColorAttributeName: [NSColor colorWithCalibratedWhite:0.92 alpha:1],
    };
    NSSize size = [text sizeWithAttributes:attrs];
    [text drawAtPoint:NSMakePoint((w - size.width) / 2.0, (h - size.height) / 2.0) withAttributes:attrs];

    [[NSColor colorWithCalibratedWhite:0 alpha:0.45] setStroke];
    NSBezierPath *seam = [NSBezierPath bezierPath];
    seam.lineWidth = 1;
    [seam moveToPoint:NSMakePoint(0, half)];
    [seam lineToPoint:NSMakePoint(w, half)];
    [seam stroke];
    [img unlockFocus];
    return img;
}

/// Blit face half into dest.
/// lockFocusFlipped faces + respectFlipped:YES use bottom-left fromRect:
///   y=half..h → visual TOP,  y=0..half → visual BOTTOM.
- (void)blit:(NSImage *)face fromTop:(BOOL)fromTop into:(NSRect)dst w:(CGFloat)w h:(CGFloat)h {
    if (!face || dst.size.height < 0.5 || dst.size.width < 0.5) return;
    CGFloat half = h / 2.0;
    NSRect src = fromTop ? NSMakeRect(0, half, w, half) : NSMakeRect(0, 0, w, half);
    [face drawInRect:dst
            fromRect:src
           operation:NSCompositingOperationSourceOver
            fraction:1.0
      respectFlipped:YES
               hints:@{ NSImageHintInterpolation: @(NSImageInterpolationHigh) }];
}

- (void)blitFull:(NSImage *)face into:(NSRect)card {
    if (!face) return;
    [face drawInRect:card
            fromRect:NSZeroRect
           operation:NSCompositingOperationSourceOver
            fraction:1.0
      respectFlipped:YES
               hints:@{ NSImageHintInterpolation: @(NSImageInterpolationHigh) }];
}

#pragma mark - Draw

- (void)drawRect:(NSRect)dirtyRect {
    [self ensureFullSize];
    NSRect bounds = [self effectiveDrawingBounds];
    NSRect fillRect = self.bounds;
    if (fillRect.size.width <= 1 || fillRect.size.height <= 1) fillRect = bounds;
    [[NSColor colorWithCalibratedWhite:0.04 alpha:1] setFill];
    NSRectFill(fillRect);
    if (bounds.size.width > 1 && bounds.size.height > 1) {
        [self drawClockInBounds:bounds];
    }
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
    [self warmFaces:cardW h:cardH font:fontSize];

    CGFloat x = (bounds.size.width - totalW) / 2.0;
    CGFloat y = NSMidY(bounds) - cardH / 2.0;
    CGFloat startX = x;

    [self drawLabel:_ampm at:NSMakePoint(startX, y - MAX(10, cardH * 0.18))
           fontSize:MAX(12, cardH * 0.11) color:[NSColor colorWithCalibratedWhite:0.55 alpha:1] align:0];

    for (int g = 0; g < 3; g++) {
        [self drawDigit:g * 2 x:x y:y w:cardW h:cardH cr:cr];
        x += cardW + interGap;
        [self drawDigit:g * 2 + 1 x:x y:y w:cardW h:cardH cr:cr];
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

- (void)drawDigit:(NSInteger)index x:(CGFloat)x y:(CGFloat)y w:(CGFloat)w h:(CGFloat)h cr:(CGFloat)cr {
    CGFloat half = h / 2.0;
    MRXDigitState *st = _digits[index];
    BOOL anim = st.isFlipping;
    double progress = anim ? st.progress : 0;
    NSInteger oldD = anim ? st.oldDigit : st.current;
    NSInteger newD = anim ? st.newDigit : st.current;
    NSImage *oldF = _faces[MAX(0, MIN(9, (int)oldD))];
    NSImage *newF = _faces[MAX(0, MIN(9, (int)newD))];

    NSRect card = NSMakeRect(x, y, w, h);
    NSRect topClip = NSMakeRect(x, y, w, half);
    NSRect botClip = NSMakeRect(x, y + half, w, half);
    CGFloat hinge = y + half;

    [NSGraphicsContext saveGraphicsState];
    [[NSBezierPath bezierPathWithRoundedRect:card xRadius:cr yRadius:cr] addClip];

    if (!anim) {
        [self blitFull:newF into:card];
    } else {
        // Static: NEW top + OLD bottom (Flipqlo)
        [self blit:newF fromTop:YES into:topClip w:w h:h];
        [self blit:oldF fromTop:NO into:botClip w:w h:h];

        if (progress < 0.5) {
            double t = progress / 0.5;
            double angle = t * M_PI_2;
            double sy = MAX(0.0, cos(angle));
            double sx = 1.0 - (1.0 - sy) * 0.18;
            double shade = sin(angle) * 0.42;

            if (shade > 0.02) {
                NSGradient *cast = [[NSGradient alloc]
                    initWithStartingColor:[NSColor colorWithCalibratedWhite:0 alpha:shade * 0.65]
                              endingColor:[NSColor colorWithCalibratedWhite:0 alpha:0]];
                [cast drawInRect:botClip angle:90];
            }
            if (sy > 0.04) {
                CGFloat dh = half * sy;
                CGFloat dw = w * sx;
                CGFloat dx = x + (w - dw) / 2.0;
                // Top flap free edge → hinge (Y-down)
                NSRect dst = NSMakeRect(dx, hinge - dh, dw, dh);
                [NSGraphicsContext saveGraphicsState];
                [NSBezierPath clipRect:topClip];
                // Slightly lifted flap face so it reads as a separate card
                [[NSColor colorWithCalibratedRed:0.19 green:0.19 blue:0.19 alpha:1] setFill];
                NSRectFill(dst);
                [self blit:oldF fromTop:YES into:dst w:w h:h];
                if (shade > 0.02) {
                    NSGradient *fg = [[NSGradient alloc]
                        initWithStartingColor:[NSColor colorWithCalibratedWhite:0 alpha:MIN(0.5, shade)]
                                  endingColor:[NSColor colorWithCalibratedWhite:0 alpha:0]];
                    [fg drawInRect:dst angle:90];
                }
                [[NSColor colorWithCalibratedWhite:1 alpha:0.14 * sy] setFill];
                NSRectFill(NSMakeRect(dx, dst.origin.y, dw, MAX(1.5, dh * 0.06)));
                [NSGraphicsContext restoreGraphicsState];
            }
            if (sy < 0.28) {
                CGFloat thick = MAX(2.5, half * 0.06 * (1.0 - sy / 0.28));
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
                              endingColor:[NSColor colorWithCalibratedWhite:0 alpha:shade * 0.55]];
                [cast drawInRect:topClip angle:90];
            }
            if (sy > 0.04) {
                CGFloat dh = half * sy;
                CGFloat dw = w * sx;
                CGFloat dx = x + (w - dw) / 2.0;
                // Bottom flap unfolds from hinge downward
                NSRect dst = NSMakeRect(dx, hinge, dw, dh);
                [NSGraphicsContext saveGraphicsState];
                [NSBezierPath clipRect:botClip];
                [[NSColor colorWithCalibratedRed:0.13 green:0.13 blue:0.13 alpha:1] setFill];
                NSRectFill(dst);
                [self blit:newF fromTop:NO into:dst w:w h:h];
                if (shade > 0.02) {
                    NSGradient *fg = [[NSGradient alloc]
                        initWithStartingColor:[NSColor colorWithCalibratedWhite:0 alpha:0]
                                  endingColor:[NSColor colorWithCalibratedWhite:0 alpha:MIN(0.48, shade)]];
                    [fg drawInRect:dst angle:90];
                }
                [[NSColor colorWithCalibratedWhite:1 alpha:0.10 * sy] setFill];
                NSRectFill(NSMakeRect(dx, NSMaxY(dst) - MAX(1.5, dh * 0.06), dw, MAX(1.5, dh * 0.06)));
                [NSGraphicsContext restoreGraphicsState];
            }
            if (sy < 0.28) {
                CGFloat thick = MAX(2.5, half * 0.06 * (1.0 - sy / 0.28));
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
