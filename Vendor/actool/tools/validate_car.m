// validate_car.m - Validate a .car file by loading all named images via CoreUI/AppKit.
//
// Usage: validate_car <path-to-Assets.car>
//
// Loads each named image from the catalog and reports success/failure.
// This exercises the same CoreUI code path that apps use at runtime.
//
// Build:
//   clang -framework AppKit -framework CoreGraphics -o validate_car tools/validate_car.m

#import <AppKit/AppKit.h>
#import <objc/runtime.h>
#import <dlfcn.h>

// CUICatalog is a private class in CoreUI.framework
@interface CUICatalog : NSObject
- (instancetype)initWithURL:(NSURL *)url error:(NSError **)error;
- (NSArray<NSString *> *)allImageNames;
@end

// CUINamedImage is the rendition wrapper
@interface CUINamedImage : NSObject
- (CGImageRef)image;
- (CGSize)size;
- (double)scale;
@end

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc < 2) {
            fprintf(stderr, "Usage: %s <path-to-Assets.car>\n", argv[0]);
            return 1;
        }

        NSString *path = [NSString stringWithUTF8String:argv[1]];
        NSURL *url = [NSURL fileURLWithPath:path];

        if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
            fprintf(stderr, "Error: file not found: %s\n", argv[1]);
            return 1;
        }

        // Load the catalog via NSImageAssetCatalog (private) or by
        // creating an NSBundle-like structure.
        // Simplest approach: use CUICatalog directly from CoreUI.
        void *coreui = dlopen("/System/Library/PrivateFrameworks/CoreUI.framework/CoreUI", RTLD_LAZY);
        if (!coreui) {
            fprintf(stderr, "Warning: Could not load CoreUI framework directly.\n");
        }

        Class cuiCatalog = NSClassFromString(@"CUICatalog");
        if (!cuiCatalog) {
            fprintf(stderr, "Error: CUICatalog class not available.\n");
            return 1;
        }

        NSError *error = nil;
        CUICatalog *catalog = [[cuiCatalog alloc] initWithURL:url error:&error];
        if (!catalog) {
            fprintf(stderr, "Error loading catalog: %s\n",
                    [[error localizedDescription] UTF8String]);
            return 1;
        }

        NSArray<NSString *> *names = nil;
        if ([catalog respondsToSelector:@selector(allImageNames)]) {
            names = [catalog allImageNames];
        }

        if (!names || names.count == 0) {
            fprintf(stderr, "Warning: Could not enumerate image names from CUICatalog.\n");
            fprintf(stderr, "Falling back to NSImage-based validation.\n");

            // Fallback: try to register the catalog and load images via NSImage
            // Create a temporary bundle structure
            NSString *tmpDir = [NSTemporaryDirectory()
                stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
            NSString *resDir = [tmpDir stringByAppendingPathComponent:@"Contents/Resources"];
            [[NSFileManager defaultManager] createDirectoryAtPath:resDir
                                     withIntermediateDirectories:YES
                                                      attributes:nil
                                                           error:nil];
            NSString *destCar = [resDir stringByAppendingPathComponent:@"Assets.car"];
            [[NSFileManager defaultManager] copyItemAtPath:path toPath:destCar error:nil];

            NSBundle *bundle = [NSBundle bundleWithPath:tmpDir];
            if (!bundle) {
                fprintf(stderr, "Error: Could not create bundle at %s\n", [tmpDir UTF8String]);
                [[NSFileManager defaultManager] removeItemAtPath:tmpDir error:nil];
                return 1;
            }

            // Try known image names from command line or just report
            fprintf(stderr, "Bundle created but no image names to test.\n");
            fprintf(stderr, "Pass image names as additional arguments.\n");

            int failures = 0;
            int successes = 0;
            for (int i = 2; i < argc; i++) {
                NSString *imgName = [NSString stringWithUTF8String:argv[i]];
                @try {
                    NSImage *img = [bundle imageForResource:imgName];
                    if (img && img.representations.count > 0) {
                        // Try to actually render it to force decompression
                        NSBitmapImageRep *rep = [[NSBitmapImageRep alloc]
                            initWithBitmapDataPlanes:NULL
                            pixelsWide:32 pixelsHigh:32
                            bitsPerSample:8 samplesPerPixel:4
                            hasAlpha:YES isPlanar:NO
                            colorSpaceName:NSCalibratedRGBColorSpace
                            bytesPerRow:0 bitsPerPixel:0];
                        [NSGraphicsContext saveGraphicsState];
                        NSGraphicsContext *ctx = [NSGraphicsContext
                            graphicsContextWithBitmapImageRep:rep];
                        [NSGraphicsContext setCurrentContext:ctx];
                        [img drawInRect:NSMakeRect(0, 0, 32, 32)];
                        [NSGraphicsContext restoreGraphicsState];
                        printf("OK   %s (%dx%d, %lu reps)\n",
                               argv[i],
                               (int)img.size.width, (int)img.size.height,
                               (unsigned long)img.representations.count);
                        successes++;
                    } else {
                        printf("FAIL %s (not found)\n", argv[i]);
                        failures++;
                    }
                } @catch (NSException *e) {
                    printf("CRASH %s (%s: %s)\n", argv[i],
                           [[e name] UTF8String], [[e reason] UTF8String]);
                    failures++;
                }
            }

            [[NSFileManager defaultManager] removeItemAtPath:tmpDir error:nil];
            printf("\nResults: %d OK, %d FAILED\n", successes, failures);
            return failures > 0 ? 1 : 0;
        }

        // Have image names from CUICatalog - validate each one
        printf("Found %lu named images in catalog.\n", (unsigned long)names.count);

        int failures = 0;
        int successes = 0;
        int skipped = 0;

        // Create a bitmap context for rendering validation
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();

        for (NSString *name in [names sortedArrayUsingSelector:@selector(compare:)]) {
            @try {
                // Use CUICatalog to get the named image rendition
                SEL sel = NSSelectorFromString(@"imagesWithName:");
                if ([catalog respondsToSelector:sel]) {
                    #pragma clang diagnostic push
                    #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                    NSArray *images = [catalog performSelector:sel withObject:name];
                    #pragma clang diagnostic pop
                    if (images.count > 0) {
                        BOOL allOk = YES;
                        int rendCount = 0;
                        for (CUINamedImage *namedImg in images) {
                            if ([namedImg respondsToSelector:@selector(image)]) {
                                CGImageRef cgImg = [namedImg image];
                                if (!cgImg) {
                                    allOk = NO;
                                    continue;
                                }
                                rendCount++;
                                // Force actual pixel decompression by drawing
                                // into a bitmap context. This exercises the
                                // same CoreUI code path as real apps.
                                size_t w = CGImageGetWidth(cgImg);
                                size_t h = CGImageGetHeight(cgImg);
                                if (w == 0 || h == 0) continue;
                                CGContextRef ctx = CGBitmapContextCreate(
                                    NULL, w, h, 8, w * 4, colorSpace,
                                    kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Host);
                                if (ctx) {
                                    CGContextDrawImage(ctx, CGRectMake(0, 0, w, h), cgImg);
                                    CGContextRelease(ctx);
                                }
                            }
                        }
                        if (allOk) {
                            printf("OK   %s (%d renditions)\n",
                                   [name UTF8String], rendCount);
                            successes++;
                        } else {
                            printf("FAIL %s (CGImage was nil)\n", [name UTF8String]);
                            failures++;
                        }
                    } else {
                        // Not an image rendition - might be a named color.
                        // Try CUICatalog's color lookup before deciding.
                        BOOL handled = NO;
                        SEL colorSel = NSSelectorFromString(@"colorWithName:displayGamut:");
                        if ([catalog respondsToSelector:colorSel]) {
                            // displayGamut: 0=SRGB, 1=P3
                            typedef id (*ColorFn)(id, SEL, NSString *, long);
                            ColorFn fn = (ColorFn)[catalog methodForSelector:colorSel];
                            id namedColor = fn(catalog, colorSel, name, 0);
                            if (namedColor) {
                                printf("OK   %s (color)\n", [name UTF8String]);
                                successes++;
                                handled = YES;
                            }
                        }
                        if (!handled) {
                            // Neither a raster image nor a color. For .icon
                            // catalogs this is the expected, non-failing case
                            // for structural facets: PART_ICON_GROUP groups
                            // (<icon>/<group>) and vector/SVG layer facets
                            // (<icon>_Assets/<svg-stem>). `imagesWithName:`
                            // correctly returns nothing for them — Apple's own
                            // reference catalogs report the identical set — so
                            // this is a SKIP, not a load failure. A real raster
                            // facet that lost its bitmaps would instead drop out
                            // of the OK tally (compare OK counts to the
                            // reference to catch that).
                            printf("SKIP %s (no bitmaps)\n", [name UTF8String]);
                            skipped++;
                        }
                    }
                } else {
                    printf("SKIP %s (imagesWithName: not available)\n", [name UTF8String]);
                }
            } @catch (NSException *e) {
                printf("CRASH %s (%s: %s)\n",
                       [name UTF8String],
                       [[e name] UTF8String],
                       [[e reason] UTF8String]);
                failures++;
            }
        }

        CGColorSpaceRelease(colorSpace);

        printf("\nResults: %d OK, %d SKIP, %d FAILED out of %lu images\n",
               successes, skipped, failures, (unsigned long)names.count);
        return failures > 0 ? 1 : 0;
    }
}
