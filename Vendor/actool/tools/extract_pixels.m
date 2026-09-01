// extract_pixels.m - Extract rendered pixel data from a .car file via CoreUI.
//
// Usage: extract_pixels <path-to-Assets.car> <image-name> <output-dir>
//
// For each scale variant of the named image, writes a file:
//   <output-dir>/<image-name>_<scale>x.rgba
//
// File format: width (uint32 LE) + height (uint32 LE) + RGBA pixel data
// Pixel data is 4 bytes per pixel (R, G, B, A) in premultiplied-alpha form,
// row-major, top-to-bottom.
//
// Build:
//   clang -framework AppKit -framework CoreGraphics \
//         -o tools/extract_pixels tools/extract_pixels.m

#import <AppKit/AppKit.h>
#import <dlfcn.h>

// CUICatalog is a private class in CoreUI.framework
@interface CUICatalog : NSObject
- (instancetype)initWithURL:(NSURL *)url error:(NSError **)error;
@end

// CUINamedImage is the rendition wrapper
@interface CUINamedImage : NSObject
- (CGImageRef)image;
- (CGSize)size;
- (double)scale;
@end

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc < 4) {
            fprintf(stderr,
                    "Usage: %s <path-to-Assets.car> <image-name> <output-dir>\n",
                    argv[0]);
            return 1;
        }

        NSString *carPath = [NSString stringWithUTF8String:argv[1]];
        NSString *imageName = [NSString stringWithUTF8String:argv[2]];
        NSString *outputDir = [NSString stringWithUTF8String:argv[3]];

        if (![[NSFileManager defaultManager] fileExistsAtPath:carPath]) {
            fprintf(stderr, "Error: file not found: %s\n", argv[1]);
            return 1;
        }

        // Ensure output directory exists
        [[NSFileManager defaultManager] createDirectoryAtPath:outputDir
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:nil];

        // Load CoreUI framework
        dlopen("/System/Library/PrivateFrameworks/CoreUI.framework/CoreUI",
               RTLD_LAZY);

        Class cuiCatalog = NSClassFromString(@"CUICatalog");
        if (!cuiCatalog) {
            fprintf(stderr, "Error: CUICatalog class not available.\n");
            return 1;
        }

        NSError *error = nil;
        NSURL *url = [NSURL fileURLWithPath:carPath];
        CUICatalog *catalog = [[cuiCatalog alloc] initWithURL:url error:&error];
        if (!catalog) {
            fprintf(stderr, "Error loading catalog: %s\n",
                    [[error localizedDescription] UTF8String]);
            return 1;
        }

        SEL sel = NSSelectorFromString(@"imagesWithName:");
        if (![catalog respondsToSelector:sel]) {
            fprintf(stderr, "Error: CUICatalog does not respond to "
                            "imagesWithName:\n");
            return 1;
        }

        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        NSArray *images = [catalog performSelector:sel withObject:imageName];
        #pragma clang diagnostic pop

        if (!images || images.count == 0) {
            // Not necessarily an error — image may not exist in this catalog
            return 0;
        }

        int written = 0;
        CGColorSpaceRef rgbSpace = CGColorSpaceCreateDeviceRGB();

        for (id item in images) {
            if (![item respondsToSelector:@selector(image)]) {
                continue;
            }

            CUINamedImage *namedImg = (CUINamedImage *)item;
            CGImageRef cgImg = [namedImg image];
            if (!cgImg) {
                continue;
            }

            size_t w = CGImageGetWidth(cgImg);
            size_t h = CGImageGetHeight(cgImg);
            int scale = (int)[namedImg scale];
            if (scale < 1) scale = 1;
            if (w == 0 || h == 0) continue;

            // Render into an RGBA bitmap context (premultiplied alpha)
            size_t bpr = w * 4;
            uint8_t *pixels = (uint8_t *)calloc(h, bpr);
            if (!pixels) continue;

            CGContextRef ctx = CGBitmapContextCreate(
                pixels, w, h, 8, bpr, rgbSpace,
                kCGImageAlphaPremultipliedLast | kCGBitmapByteOrderDefault);
            if (!ctx) {
                free(pixels);
                continue;
            }

            CGContextDrawImage(ctx, CGRectMake(0, 0, w, h), cgImg);
            CGContextRelease(ctx);

            // Write output file: width(4) + height(4) + RGBA data
            NSString *fname = [NSString stringWithFormat:@"%@_%dx.rgba",
                               imageName, scale];
            NSString *outPath = [outputDir
                stringByAppendingPathComponent:fname];

            FILE *fp = fopen([outPath UTF8String], "wb");
            if (fp) {
                uint32_t wLE = (uint32_t)w;
                uint32_t hLE = (uint32_t)h;
                fwrite(&wLE, 4, 1, fp);
                fwrite(&hLE, 4, 1, fp);
                fwrite(pixels, 1, h * bpr, fp);
                fclose(fp);
                written++;
            }

            free(pixels);
        }

        CGColorSpaceRelease(rgbSpace);

        return 0;
    }
}
