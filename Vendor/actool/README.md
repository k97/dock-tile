# actool reimplementation

This project reimplements the behaviour of Apple's `actool`. It's a clean
reimplementation based just on the behaviour and the awesome research from
[Alexandre Colucci](https://blog.timac.org/2018/1018-reverse-engineering-the-car-file-format/)
who described the file structure.

This tool supports the lzfse compression for assets, but not the palette format. It supports deepmap2 format, but only by using the private APIs on MacOS. You can still run it on Linux and fall back to lzfse or earlier. 

It can handle both car asset archives and icon files.

There is likely some missing functionality, in the unknown unknowns category.
As more samples appear or issues get reported, better compatibility will be
achieved.

The target at this point is just macos and iOS features.

## But why? 

Apple's actool is a proprietary, closed utility. That makes it hard to both cross compile from a different system and to build in a tightly controlled environment like Nixpkgs.

Also it's fun.

## Implementation

The system has been implemented almost entirely automatically by Claude with
deciduous planning.

We're engaging only in cleanroom implementation based on known outputs of the
original tool, with abundance of caution for potential legal issues.
