#import <QuartzCore/QuartzCore.h>
#import "game/iphone/cgview.h"
#import "game/iphone/iphone.h"
#include "base/log.h"
#include "hdscale.h"

@implementation CgView

- (id)initWithFrame:(struct CGRect)rect
{
    self = [super initWithFrame: rect];
    if (self != nil) {
        displayMode_ = [[NSUserDefaults standardUserDefaults] objectForKey:@"WIDisplayMode"] ? [[NSUserDefaults standardUserDefaults] integerForKey:@"WIDisplayMode"] : 2;
        [self initGraphics];
        self.contentScaleFactor = UIScreen.mainScreen.scale;
        self.backgroundColor = [UIColor blackColor];
        UITapGestureRecognizer *gesture = [[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(showDisplayOptions)] autorelease];
        gesture.numberOfTouchesRequired = 3;
        [self addGestureRecognizer:gesture];
        image_ = NULL;
        arcInvalid_ = NULL;
        crcInvalid_ = 0;
        crcInvalidMax_ = 0;
    }
    return self;
}

- (void)dealloc
{
	CGContextRelease(bmCtx_);
    CGContextRelease(hdCtx_);
    free(hdPixels_);
    if (image_ != NULL) {
        CGImageRelease(image_);
    }
    delete[] arcInvalid_;
    [super dealloc];
}

- (void)setFormMgrs:(wi::FormMgr *)pfrmmSimUI input:(wi::FormMgr *)pfrmmInput
{
    // Now allocate the max # of invalid rects that may result

    wi::Size sizMap0;
    pfrmmSimUI->GetUpdateMap()->GetMapSize(&sizMap0);
    wi::Size sizMap1;
    pfrmmInput->GetUpdateMap()->GetMapSize(&sizMap1);

    int crcMax = (sizMap0.cx * sizMap0.cy + sizMap1.cx * sizMap1.cy) / 2;
    delete[] arcInvalid_;
    arcInvalid_ = new CGRect[crcMax];
    crcInvalid_ = 0;
    crcInvalidMax_ = crcMax;
}

- (void)initGraphics
{
    // The OS erases invalid areas black whether clearsContext is YES or NO.

    [[self layer] setOpaque: YES];
    self.clearsContextBeforeDrawing = NO;

    int w = rect_.size.width;
    int h = rect_.size.height;

    int allocSize = 4 * w * h;

    pb_ = (unsigned char *)malloc(allocSize);
    memset(pb_, 0, allocSize);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    bmCtx_ = CGBitmapContextCreate(pb_, w, h, 8, w * 4, colorSpace,
            kCGImageAlphaNoneSkipFirst | kCGBitmapByteOrderDefault);
    hdPixels_ = (unsigned char *)calloc(w * h * 16, 1);
    hdCtx_ = CGBitmapContextCreate(hdPixels_, w*2, h*2, 8, w*8, colorSpace,
            kCGImageAlphaNoneSkipFirst | kCGBitmapByteOrderDefault);
    CGColorSpaceRelease(colorSpace);
    
    tmFlip_ = CGAffineTransformMake(1.0f, 0.0f, 0.0f, -1.0f, 0.0f, h);
}

- (void)drawRect:(CGRect)frame
{
    base::CritScope cs(pcrit_);

#ifdef SIMULATOR
    static bool loggedBlankDraw = false;
    static bool loggedGameDraw = false;
    bool &logged = image_ != NULL ? loggedGameDraw : loggedBlankDraw;
    if (!logged) {
        NSLog(@"WI draw image=%d bounds=%@ viewport=%@ window=%d", image_ != NULL,
              NSStringFromCGRect(self.bounds), NSStringFromCGRect([self gameViewport]),
              self.window != nil);
        logged = true;
    }
#endif
    if (image_ == NULL) {
        return;
    }
	CGRect rc = rect_;
	CGContextRef ctx = UIGraphicsGetCurrentContext();    
    CGContextSaveGState(ctx);
    CGRect viewport = [self gameViewport];
    CGContextTranslateCTM(ctx, viewport.origin.x, viewport.origin.y);
    CGContextScaleCTM(ctx, viewport.size.width/rect_.size.width, viewport.size.height/rect_.size.height);
    CGContextSetInterpolationQuality(ctx, displayMode_ == 0 ? kCGInterpolationNone : kCGInterpolationHigh);
    CGContextConcatCTM(ctx, tmFlip_);
	CGContextDrawImage(ctx, rc, image_);
    [self drawSprites: ctx];
    CGContextRestoreGState(ctx);
}

- (void)refreshFrameImage {
    if (image_ != NULL) { CGImageRelease(image_); image_ = NULL; }
    if (displayMode_ == 2 && hdCtx_ != NULL) {
        WIUpscale2x((const uint32_t *)pb_, (uint32_t *)hdPixels_, (int)rect_.size.width, (int)rect_.size.height);
        image_ = CGBitmapContextCreateImage(hdCtx_);
    } else {
        image_ = CGBitmapContextCreateImage(bmCtx_);
    }
}

- (void)showDisplayOptions {
    UIAlertController *menu = [UIAlertController alertControllerWithTitle:@"Display quality"
        message:@"Three-finger tap opens this menu. HD enhances the original art; gameplay is unchanged."
        preferredStyle:UIAlertControllerStyleActionSheet];
    NSArray *labels = @[@"Classic pixels", @"Smooth", @"HD edge enhancement"];
    for (NSInteger i=0; i<3; ++i) {
        [menu addAction:[UIAlertAction actionWithTitle:[labels objectAtIndex:i] style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            { base::CritScope cs(pcrit_); displayMode_ = i; [self refreshFrameImage]; }
            [[NSUserDefaults standardUserDefaults] setInteger:i forKey:@"WIDisplayMode"];
            [self setNeedsDisplay];
        }]];
    }
    [menu addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    menu.popoverPresentationController.sourceView = self;
    menu.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds), 1, 1);
    [self.window.rootViewController presentViewController:menu animated:YES completion:nil];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.contentScaleFactor = self.window.screen ? self.window.screen.scale : UIScreen.mainScreen.scale;
    [self setNeedsDisplay];
}

- (void)frameStart
{
    pcrit_->Enter();
    pbm_->ResetChanged();
}

- (void)invalidate
{
    // Runs on main thread

    base::CritScope cs(pcrit_);
    for (int i = 0; i < crcInvalid_; i++) {
        [self setNeedsDisplayInRect:arcInvalid_[i]];
    }
    crcInvalid_ = 0;
}

//#define INVALID_RECTS

- (void)frameComplete:(int)cfrmm maps:(wi::UpdateMap **)apupd
        rects:(wi::Rect *)arc scrolled:(bool)fScrolled
{
    if (!havePalette_) {
        pcrit_->Leave();
        return;
    }

    // Sprites may have changes, or front dib may have changed, or neither.
    bool fImageChanged = false;
    if (pbm_->HasChanged()) {
        [self refreshFrameImage];
        fImageChanged = true;
#ifdef SIMULATOR
        // Record the first frame that contains game art.
        static bool loggedVisibleFrame = false;
        if (!loggedVisibleFrame) {
            const size_t pixelCount = (size_t)rect_.size.width * rect_.size.height;
            for (size_t index = 0; index < pixelCount; ++index) {
                const unsigned char *pixel = pb_ + index * 4;
                if (pixel[1] || pixel[2] || pixel[3]) {
                    NSLog(@"WI game frame contains color; image=%d", image_ != NULL);
                    loggedVisibleFrame = true;
                    break;
                }
            }
        }
#endif
    }

    bool fSpriteChanged = false;
    if (fSpriteDirty_) {
        fSpriteDirty_ = false;
        fSpriteChanged = true;
    }

    if (!fSpriteChanged && !fImageChanged) {
        pcrit_->Leave();
        return;
    }

    if (fScrolled || fSpriteChanged) {
#ifdef INVALID_RECTS
        arcInvalid_[0] = rect_;
        crcInvalid_ = 1;
        [self performSelectorOnMainThread:@selector(invalidate)
                withObject:nil waitUntilDone: NO];
#else
        dispatch_async(dispatch_get_main_queue(), ^{ [self setNeedsDisplay]; });
#endif
        pcrit_->Leave();
        return;
    }

    if (fImageChanged) {
#ifdef INVALID_RECTS
        // Collect the invalid rects, and send them over to the main
        // thread

        CGRect *prc = &arcInvalid_[crcInvalid_];
        CGRect *prcMax = &arcInvalid_[crcInvalidMax_];
        int cy = (int)rect_.size.width;

        for (int i = 0; i < cfrmm; i++) {
            wi::UpdateMap *pupd = apupd[i];
            int yTop = arc[i].top;

            bool fFirst = true;
            wi::Rect rc;
            while (prc < prcMax && pupd->EnumUpdateRects(fFirst, NULL, &rc)) {
                fFirst = false;
                prc->origin.x = cy - (rc.bottom + yTop);
                prc->origin.y = rc.left;
                prc->size.width = rc.Height();
                prc->size.height = rc.Width();
                prc++;
            }
        }
        crcInvalid_ = prc - arcInvalid_;
        [self performSelectorOnMainThread:@selector(invalidate)
                withObject:nil waitUntilDone: NO];
#else
        dispatch_async(dispatch_get_main_queue(), ^{ [self setNeedsDisplay]; });
#endif
        pcrit_->Leave();
        return;
    }
}

- (wi::DibBitmap *)createFrontDibWithOrientation:(int)nDegreeOrientation width:(int)cx height:(int)cy
{
    wi::SurfaceProperties props;
    [self getSurfaceProperties:&props];
    pbm_ = wi::CreateCgDib(pb_, &props, cx, cy, nDegreeOrientation);
    return pbm_;
}

- (void)setPalette:(wi::Palette *)ppal
{
    if (pbm_ != NULL) {
        // 8->8888 mapping table. 3x faster than 555 format even though it is
        // converted to 565 for display.
        dword mp8bpp32bpp[256];
        for (int n = 0; n < BigWord(ppal->cEntries); n++) {
            byte *pb = (byte *)&mp8bpp32bpp[n];
            *pb++ = 0;
            *pb++ = ppal->argb[n][0];
            *pb++ = ppal->argb[n][1];
            *pb++ = ppal->argb[n][2];
        }  
        pbm_->SetPalette(mp8bpp32bpp, sizeof(mp8bpp32bpp));            

        havePalette_ = true;
    }
}

- (void)getSurfaceProperties:(wi::SurfaceProperties *)pprops
{
    pprops->cxWidth = (int)rect_.size.width;
    pprops->cyHeight = (int)rect_.size.height;
    pprops->cbxPitch = 4;
    pprops->cbyPitch = (int)rect_.size.width * 4;
    pprops->ffFormat = wi::kfDirect888;    
}
@end
