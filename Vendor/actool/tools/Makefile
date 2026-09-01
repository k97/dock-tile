BINS = extract_pixels validate_car
CFLAGS = -framework AppKit -framework CoreGraphics

all: $(BINS)

%: %.m
	clang $(CFLAGS) -o $@ $<

clean:
	rm -f $(BINS)

.PHONY: all clean
