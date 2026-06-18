---
name: interactive-hero-mockup
description: |
  Pattern for building interactive hero image carousels with audio control overlays.
  Use when: (1) replacing static hero mockups with animated screenshot carousels,
  (2) adding interactive audio demos to landing pages, (3) implementing Alcove-style
  two-state hero interactions. Covers image cycling, floating control panels,
  Web Audio vs <audio> element tradeoffs, and macOS-style slider overlays.
author: Claude Code
version: 1.2.0
date: 2026-03-13
---

# Interactive Hero Mockup Pattern

## Problem
Static hero mockups don't showcase app functionality. Need interactive,
animated hero sections that demo the product with real audio control.

## Context / Trigger Conditions
- Landing page hero needs to show multiple product states/views
- Want Alcove-style interactive demo experience
- Need audio playback with user-controllable volume
- Screenshots of a real app need to cycle with smooth transitions

## Solution

### Image Carousel
- Stack images with `position: absolute` in a fixed-aspect container
- Use `transition-opacity duration-1000` for crossfade (not transforms)
- Auto-cycle with `setInterval`, pause on user interaction via timestamp ref
- Use Next.js `<Image>` with `priority` on first image only

### Audio Control — Use `<audio>` NOT Web Audio API
**Anti-pattern**: Web Audio API oscillators for demo music sound terrible.
```tsx
// BAD — unbearable sine/triangle tones
const osc = ctx.createOscillator();
osc.type = "sine";

// GOOD — real audio file with <audio> element
<audio ref={audioRef} src="/hero/demo-track.mp3" loop preload="none" />
audioRef.current.volume = speakerVolume * 0.5;
```

### Slider Overlay Positioning — Use Floating Panels
**Anti-pattern**: Percentage-based absolute positioning over screenshots.
Positions drift across screen sizes and are nearly impossible to maintain.

**Better approach**: Floating control panel positioned relative to the
container (e.g. `right-4 bottom-14`), styled as a macOS-style dark panel.
This works at all sizes and is clearly interactive.

### Interaction Prompt
Use an Alcove-style "Click to experience" overlay:
- Frosted glass backdrop (`bg-black/30 backdrop-blur-[2px]`)
- Pulsing play button (ping animation)
- Shimmer text effect via `background-clip: text` + animated gradient

### CC0 Music Sources
- OpenGameArt.org — CC0 ambient tracks, direct MP3 URLs
- Recommended: "Calm Ambient 1 - Synthwave 4k" (~2:38 loop)

## Verification
- Images cycle smoothly with crossfade
- Audio plays on activation, volume responds to slider
- Mute/unmute works immediately
- Cycling pauses when user interacts with controls

## Notes
- `sips` on macOS does NOT support WebP export — use `cwebp -q 85` instead
- Browser autoplay policy requires user interaction before audio plays
- Always add `preload="none"` to avoid loading audio on page load
- Use `loop` attribute for continuous playback
- Respect `useReducedMotion()` — disable cycling, use instant transitions

### Variant: Full React Replica (v1.1)
Instead of screenshot overlays, build the entire UI as React components:
- **Slider fill colors**: Use Tailwind `dark:` class-based backgrounds, NOT inline `style={{ background: rgba }}`
  — inline rgba driven by JS `isDark` defaults to dark on SSR, causing wrong colors on initial light-mode load
- **Audio volume mixing**: `effectiveVolume = systemVolume × appVolume × 0.5` — system volume is the ceiling
- **Slider snap-to-zero**: Below 6.67% fill, snap value to 0 and swap icon to muted variant
- **Master slider minimum fill**: 14.4% at value=0 (matches macOS pill slider visual)
- **Auto-unmute on drag**: When muted and user drags slider up, call `onToggleMute()` in `handlePointerDown`
- **Random track**: Use `useState(() => tracks[Math.floor(Math.random() * tracks.length)])` not `useRef(Math.random())` — lint purity rule
- See also: `css-property-theme-transitions` skill for smooth theme switching

### Variant: Multi-App Audio Demo (v1.2)
Extend the single-audio pattern to multiple simultaneous streams — demonstrates per-app audio control:
- **Multiple `<audio>` elements**: One ref per audio app (e.g. `chromeAudioRef`, `musicAudioRef`)
- **Random track assignment**: Shuffle tracks so each app gets a different one on each load
  ```tsx
  const [trackAssignment] = useState(() => {
    const shuffled = Math.random() < 0.5 ? [t1, t2] : [t2, t1];
    return { Chrome: shuffled[0], Music: shuffled[1] };
  });
  ```
- **Per-app play/pause state**: `Record<string, boolean>` — each app toggles independently
- **Per-app effective volume**: `systemVolume × appVolume × 0.5` computed per app
- **Red dot = "firing" state**: Show notification dot when app is playing AND has volume > 0. System dots only show when any child app is firing AND system is not muted
- **Bidirectional device-volume sync**: Active output device slider ↔ system master slider stay in sync via reducer. Switching active output updates system volume to match new device
- **Expandable device selector per app**: Chevron on app row expands to show output device icons; tapping switches `activeOutput` globally, moving red dots simultaneously
- **Hero section layout**: Use `min-h-dvh` (not `h-[100dvh]`) so mockup flows naturally below content without overlapping headings or features section on short viewports
