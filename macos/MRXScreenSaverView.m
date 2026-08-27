#import <ScreenSaver/ScreenSaver.h>
#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>
#import <CoreText/CoreText.h>

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
    // Retina CGImage faces 0–9 (AppKit Y-up content).
    CGImageRef _faces[10];
    CGFloat _faceW;
    CGFloat _faceH;
    CGFloat _faceFont;
    CGFloat _faceCr;
}

- (instancetype)initWithFrame:(NSRect)frame isPreview:(BOOL)isPreview {
    self = [super initWithFrame:frame isPreview:isPreview];
    if (self) {
        _isPreviewMode = isPreview;
        _flipDuration = 0.72;
        _lastTimeKey = @"";
        _ampm = @"AM";
        _dateLabel = @"";
        memset(_faces, 0, sizeof(_faces));
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
        self.animationTimeInterval = 1.0 / 60.0;
        [self syncClockImmediate:YES];
    }
    return self;
}

- (void)dealloc {
    for (int i = 0; i < 10; i++) {
        if (_faces[i]) CGImageRelease(_faces[i]);
        _faces[i] = NULL;
    }
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
    // Medium + 10%: ~22% height, max ~86% width.
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
    [self warmFacesWidth:cardW height:cardH fontSize:fontSize corner:cr];

    CGFloat x = (bounds.size.width - totalW) / 2.0;
    CGFloat y = NSMidY(bounds) - cardH / 2.0;
    CGFloat startX = x;

    [self drawText:_ampm
           atPoint:NSMakePoint(startX, y + cardH + MAX(10, cardH * 0.08))
          fontSize:MAX(12, cardH * 0.11)
             color:[NSColor colorWithCalibratedWhite:0.55 alpha:1]
             align:0];

    for (int g = 0; g < 3; g++) {
        [self drawDigitAtIndex:g * 2 x:x y:y w:cardW h:cardH cr:cr];
        x += cardW + interGap;
        [self drawDigitAtIndex:g * 2 + 1 x:x y:y w:cardW h:cardH cr:cr];
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

#pragma mark - CGImage digit faces

- (void)warmFacesWidth:(CGFloat)w height:(CGFloat)h fontSize:(CGFloat)fontSize corner:(CGFloat)cr {
    if (fabs(w - _faceW) < 0.5 && fabs(h - _faceH) < 0.5 &&
        fabs(fontSize - _faceFont) < 0.5 && fabs(cr - _faceCr) < 0.5 &&
        _faces[0] != NULL) {
        return;
    }
    for (int i = 0; i < 10; i++) {
        if (_faces[i]) CGImageRelease(_faces[i]);
        _faces[i] = NULL;
    }
    _faceW = w; _faceH = h; _faceFont = fontSize; _faceCr = cr;
    for (int d = 0; d < 10; d++) {
        _faces[d] = [self createFaceForDigit:d width:w height:h fontSize:fontSize corner:cr];
    }
}

- (CGImageRef)createFaceForDigit:(NSInteger)digit
                           width:(CGFloat)w
                          height:(CGFloat)h
                        fontSize:(CGFloat)fontSize
                          corner:(CGFloat)cr {
    CGFloat scale = 2.0;
    size_t pw = (size_t)ceil(w * scale);
    size_t ph = (size_t)ceil(h * scale);
    CGColorSpaceRef cs = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGContextRef bc = CGBitmapContextCreate(NULL, pw, ph, 8, 0, cs,
                                            kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Host);
    CGColorSpaceRelease(cs);
    if (!bc) return NULL;

    // Bitmap is Y-up (Core Graphics default), matching AppKit view coords.
    CGContextScaleCTM(bc, scale, scale);

    CGFloat half = h / 2.0;
    CGContextSetRGBFillColor(bc, 0.11, 0.11, 0.11, 1);
    CGContextFillRect(bc, CGRectMake(0, 0, w, h));
    CGContextSetRGBFillColor(bc, 0.17, 0.17, 0.17, 1);
    CGContextFillRect(bc, CGRectMake(0, half, w, half)); // top
    CGContextSetRGBFillColor(bc, 0.10, 0.10, 0.10, 1);
    CGContextFillRect(bc, CGRectMake(0, 0, w, half)); // bottom

    // Upper lip highlight
    CGContextSaveGState(bc);
    CGColorSpaceRef gcs = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGFloat locs[2] = {0, 1};
    CGFloat comps[8] = {1,1,1,0.08, 1,1,1,0};
    CGGradientRef grad = CGGradientCreateWithColorComponents(gcs, comps, locs, 2);
    CGContextClipToRect(bc, CGRectMake(0, h - 5, w, 5));
    CGContextDrawLinearGradient(bc, grad, CGPointMake(0, h), CGPointMake(0, h - 5), 0);
    CGGradientRelease(grad);
    CGColorSpaceRelease(gcs);
    CGContextRestoreGState(bc);

    // Digit via Core Text (Y-up)
    NSString *str = [NSString stringWithFormat:@"%ld", (long)digit];
    CTFontRef font = CTFontCreateUIFontForLanguage(kCTFontUIFontEmphasizedSystem, fontSize, NULL);
    if (!font) font = CTFontCreateWithName(CFSTR("Helvetica-Bold"), fontSize, NULL);
    CGColorRef digColor = CGColorCreateGenericRGB(0.92, 0.92, 0.92, 1);
    NSDictionary *attrs = @{
        (id)kCTFontAttributeName: (__bridge id)font,
        (id)kCTForegroundColorAttributeName: (__bridge id)digColor,
    };
    NSAttributedString *as = [[NSAttributedString alloc] initWithString:str attributes:attrs];
    CTLineRef line = CTLineCreateWithAttributedString((CFAttributedStringRef)as);
    CGFloat ascent, descent, leading;
    double tw = CTLineGetTypographicBounds(line, &ascent, &descent, &leading);
    CGContextSetTextMatrix(bc, CGAffineTransformIdentity);
    CGContextSetTextPosition(bc, (w - tw) / 2.0, (h - (ascent + descent)) / 2.0 + descent);
    CTLineDraw(line, bc);
    CFRelease(line);
    CFRelease(font);
    CGColorRelease(digColor);

    // Seam
    CGContextSetRGBStrokeColor(bc, 0, 0, 0, 0.55);
    CGContextSetLineWidth(bc, 1);
    CGContextMoveToPoint(bc, 0, half - 0.5);
    CGContextAddLineToPoint(bc, w, half - 0.5);
    CGContextStrokePath(bc);
    CGContextSetRGBStrokeColor(bc, 0.08, 0.08, 0.08, 1);
    CGContextSetLineWidth(bc, 1.5);
    CGContextMoveToPoint(bc, 0, half);
    CGContextAddLineToPoint(bc, w, half);
    CGContextStrokePath(bc);

    // Rounded mask
    CGImageRef raw = CGBitmapContextCreateImage(bc);
    CGContextRelease(bc);
    if (!raw) return NULL;

    CGColorSpaceRef mcs = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGContextRef mc = CGBitmapContextCreate(NULL, pw, ph, 8, 0, mcs,
                                            kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Host);
    CGColorSpaceRelease(mcs);
    if (!mc) { CGImageRelease(raw); return NULL; }
    CGContextScaleCTM(mc, scale, scale);
    CGPathRef round = CGPathCreateWithRoundedRect(CGRectMake(0, 0, w, h), cr, cr, NULL);
    CGContextAddPath(mc, round);
    CGContextClip(mc);
    CGPathRelease(round);
    CGContextDrawImage(mc, CGRectMake(0, 0, w, h), raw);
    CGImageRelease(raw);
    CGImageRef face = CGBitmapContextCreateImage(mc);
    CGContextRelease(mc);
    return face;
}

/// Draw a CGImage face into an AppKit Y-up rect (handles CG Y flip).
- (void)drawFace:(CGImageRef)face inRect:(NSRect)rect {
    if (!face) return;
    CGContextRef ctx = NSGraphicsContext.currentContext.CGContext;
    CGContextSaveGState(ctx);
    CGContextTranslateCTM(ctx, rect.origin.x, rect.origin.y);
    CGContextTranslateCTM(ctx, 0, rect.size.height);
    CGContextScaleCTM(ctx, 1, -1);
    CGContextSetInterpolationQuality(ctx, kCGInterpolationHigh);
    CGContextDrawImage(ctx, CGRectMake(0, 0, rect.size.width, rect.size.height), face);
    CGContextRestoreGState(ctx);
}

/// Draw only the top or bottom half by clipping a full-face blit.
- (void)drawFace:(CGImageRef)face halfIsTop:(BOOL)isTop intoCard:(NSRect)card {
    if (!face) return;
    CGFloat half = card.size.height / 2.0;
    NSRect clip = isTop ? NSMakeRect(card.origin.x, card.origin.y + half, card.size.width, half)
                        : NSMakeRect(card.origin.x, card.origin.y, card.size.width, half);
    [NSGraphicsContext saveGraphicsState];
    [NSBezierPath clipRect:clip];
    [self drawFace:face inRect:card];
    [NSGraphicsContext restoreGraphicsState];
}

#pragma mark - Digit card + flip

- (void)drawDigitAtIndex:(NSInteger)index
                       x:(CGFloat)x
                       y:(CGFloat)y
                       w:(CGFloat)w
                       h:(CGFloat)h
                      cr:(CGFloat)cr {
    CGFloat half = h / 2.0;
    MRXDigitState *state = _digits[index];
    BOOL animating = state.isFlipping;
    double progress = animating ? state.progress : 0;
    NSInteger oldD = animating ? state.oldDigit : state.current;
    NSInteger newD = animating ? state.newDigit : state.current;
    CGImageRef oldFace = _faces[MAX(0, MIN(9, (int)oldD))];
    CGImageRef newFace = _faces[MAX(0, MIN(9, (int)newD))];

    NSRect card = NSMakeRect(x, y, w, h);
    NSRect topClip = NSMakeRect(x, y + half, w, half);
    NSRect botClip = NSMakeRect(x, y, w, half);

    [NSGraphicsContext saveGraphicsState];
    NSBezierPath *round = [NSBezierPath bezierPathWithRoundedRect:card xRadius:cr yRadius:cr];
    [round addClip];

    if (!animating) {
        [self drawFace:newFace inRect:card];
    } else {
        [self drawFace:newFace halfIsTop:YES intoCard:card];
        [self drawFace:oldFace halfIsTop:NO intoCard:card];

        double angle = progress * M_PI;

        if (angle < M_PI * 0.5) {
            double sy = MAX(0.0, cos(angle));
            double shade = sin(angle);
            if (shade > 0.02) {
                NSGradient *cast = [[NSGradient alloc]
                    initWithStartingColor:[NSColor colorWithCalibratedWhite:0 alpha:shade * 0.22]
                              endingColor:[NSColor colorWithCalibratedWhite:0 alpha:0]];
                [cast drawInRect:botClip angle:-90];
            }
            if (sy > 0.03) {
                [self drawFlapFace:oldFace isTop:YES card:card scaleY:sy shade:shade];
            }
            if (sy < 0.22) {
                CGFloat thick = MAX(2.0, half * 0.05 * (1.0 - sy / 0.22));
                [[NSColor colorWithCalibratedWhite:0.34 alpha:0.95] setFill];
                NSRectFill(NSMakeRect(x, y + half - thick * 0.4, w, thick));
            }
        } else {
            double local = angle - M_PI * 0.5;
            double sy = MAX(0.0, sin(local));
            double shade = cos(local);
            if (shade > 0.02) {
                NSGradient *cast = [[NSGradient alloc]
                    initWithStartingColor:[NSColor colorWithCalibratedWhite:0 alpha:0]
                              endingColor:[NSColor colorWithCalibratedWhite:0 alpha:shade * 0.18]];
                [cast drawInRect:topClip angle:-90];
            }
            if (sy > 0.03) {
                [self drawFlapFace:newFace isTop:NO card:card scaleY:sy shade:shade];
            }
            if (sy < 0.22) {
                CGFloat thick = MAX(2.0, half * 0.05 * (1.0 - sy / 0.22));
                [[NSColor colorWithCalibratedWhite:0.30 alpha:0.9] setFill];
                NSRectFill(NSMakeRect(x, y + half - thick * 0.6, w, thick));
            }
        }
    }

    [NSGraphicsContext restoreGraphicsState];

    [[NSColor colorWithCalibratedWhite:0 alpha:0.65] setStroke];
    NSBezierPath *sh = [NSBezierPath bezierPath];
    sh.lineWidth = 1;
    [sh moveToPoint:NSMakePoint(x, y + half - 1)];
    [sh lineToPoint:NSMakePoint(x + w, y + half - 1)];
    [sh stroke];

    [[NSColor colorWithCalibratedWhite:0.08 alpha:1] setStroke];
    NSBezierPath *div = [NSBezierPath bezierPath];
    div.lineWidth = 2;
    [div moveToPoint:NSMakePoint(x, y + half)];
    [div lineToPoint:NSMakePoint(x + w, y + half)];
    [div stroke];
}

/**
 * Hinge-scale a full digit face inside the top or bottom half.
 * CGContextDrawImage respects CTM, so the glyph foreshortens correctly.
 */
- (void)drawFlapFace:(CGImageRef)face
               isTop:(BOOL)isTop
                card:(NSRect)card
              scaleY:(CGFloat)scaleY
               shade:(double)shade {
    if (!face || scaleY < 0.03) return;

    CGFloat x = card.origin.x, y = card.origin.y, w = card.size.width, h = card.size.height;
    CGFloat half = h / 2.0;
    CGFloat hinge = y + half;
    CGFloat cx = NSMidX(card);
    CGFloat sx = 1.0 - (1.0 - scaleY) * 0.12;
    NSRect halfClip = isTop ? NSMakeRect(x, hinge, w, half) : NSMakeRect(x, y, w, half);

    CGContextRef ctx = NSGraphicsContext.currentContext.CGContext;
    CGContextSaveGState(ctx);
    CGContextClipToRect(ctx, NSRectToCGRect(halfClip));

    CGContextTranslateCTM(ctx, cx, hinge);
    CGContextScaleCTM(ctx, sx, scaleY);
    CGContextTranslateCTM(ctx, -cx, -hinge);

    // Flap tone under the face
    if (isTop) {
        CGContextSetRGBFillColor(ctx, 0.20, 0.20, 0.20, 1);
    } else {
        CGContextSetRGBFillColor(ctx, 0.14, 0.14, 0.14, 1);
    }
    CGContextFillRect(ctx, NSRectToCGRect(halfClip));

    // Full face (clipped to half by outer clip + foreshortened by CTM)
    CGContextSaveGState(ctx);
    CGContextTranslateCTM(ctx, x, y);
    CGContextTranslateCTM(ctx, 0, h);
    CGContextScaleCTM(ctx, 1, -1);
    CGContextSetInterpolationQuality(ctx, kCGInterpolationHigh);
    CGContextDrawImage(ctx, CGRectMake(0, 0, w, h), face);
    CGContextRestoreGState(ctx);

    if (shade > 0.05) {
        CGFloat a = MIN(0.26, shade * 0.26);
        CGColorSpaceRef cs = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
        CGFloat comps[8] = {0,0,0,isTop?a:0, 0,0,0,isTop?0:a};
        CGFloat locs[2] = {0, 1};
        CGGradientRef g = CGGradientCreateWithColorComponents(cs, comps, locs, 2);
        CGContextDrawLinearGradient(ctx,
            g,
            CGPointMake(x, isTop ? hinge + half : y),
            CGPointMake(x, isTop ? hinge : hinge),
            0);
        CGGradientRelease(g);
        CGColorSpaceRelease(cs);
    }

    CGContextRestoreGState(ctx);

    // Rim in untransformed space along free edge of foreshortened flap
    CGFloat dh = half * scaleY;
    CGFloat rim = MAX(1.0, dh * 0.08);
    [[NSColor colorWithCalibratedWhite:1 alpha:0.14 * scaleY] setFill];
    if (isTop) {
        NSRectFill(NSMakeRect(x, hinge + dh - rim, w, rim));
    } else {
        NSRectFill(NSMakeRect(x, hinge - dh, w, rim));
    }
}

- (void)drawColonAtX:(CGFloat)x y:(CGFloat)y colonW:(CGFloat)colonW cardH:(CGFloat)cardH {
    CGFloat r = cardH * 0.035;
    CGFloat cx = x + colonW / 2.0;
    [[NSColor colorWithCalibratedWhite:0.23 alpha:1] setFill];
    [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(cx - r, y + cardH * 0.35 - r, r * 2, r * 2)] fill];
    [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(cx - r, y + cardH * 0.65 - r, r * 2, r * 2)] fill];
}

- (void)drawText:(NSString *)string
         atPoint:(NSPoint)point
        fontSize:(CGFloat)fontSize
           color:(NSColor *)color
           align:(int)align {
    NSDictionary *attrs = @{
        NSFontAttributeName: [NSFont systemFontOfSize:fontSize weight:NSFontWeightMedium],
        NSForegroundColorAttributeName: color,
    };
    NSSize size = [string sizeWithAttributes:attrs];
    CGFloat x = point.x;
    if (align == 1) x -= size.width / 2.0;
    if (align == 2) x -= size.width;
    [string drawAtPoint:NSMakePoint(x, point.y) withAttributes:attrs];
}

@end
