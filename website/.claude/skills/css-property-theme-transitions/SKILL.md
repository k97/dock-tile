---
name: css-property-theme-transitions
description: |
  Smooth CSS custom property transitions between light/dark themes using @property registration.
  Use when: (1) theme toggle feels instant despite transition rules, (2) CSS custom properties
  (--background, --foreground, etc.) won't animate, (3) need smooth color transitions on
  :root variables. Covers @property syntax registration, Tailwind dark: hydration-safe patterns,
  and macOS-accurate glassmorphism values.
author: Claude Code
version: 1.0.0
date: 2026-03-13
---

# CSS @property Theme Transitions

## Problem
CSS custom properties (variables) don't transition by default. Adding `transition: --background 0.6s`
to `:root` does nothing — the theme toggle appears instant. This is because the browser treats
custom properties as strings unless explicitly registered with a type.

## Context / Trigger Conditions
- Theme toggle feels instant despite `transition` rules on `:root`
- Using `next-themes` or similar theme switcher that toggles a class on `<html>`
- CSS custom properties defined in `:root` / `.dark` blocks
- Want smooth, linear color interpolation between light and dark themes

## Solution

### Step 1: Register each custom property with `@property`

```css
@property --background {
  syntax: "<color>";
  inherits: true;
  initial-value: oklch(0.987 0.002 197);
}
@property --foreground {
  syntax: "<color>";
  inherits: true;
  initial-value: oklch(0.141 0.005 286);
}
/* Repeat for every color custom property that should transition */
```

The `syntax: "<color>"` tells the browser this is an interpolatable color, not an opaque string.

### Step 2: Add transition rules on `:root`

```css
:root {
  transition:
    --background 0.6s linear,
    --foreground 0.6s linear,
    --primary 0.6s linear;
    /* List every registered property */
}
```

### Step 3: Use Tailwind `dark:` variants (not JS-driven class toggling) for component styles

This avoids hydration mismatches with SSR frameworks like Next.js:

```tsx
// BAD: JS-driven, causes hydration mismatch
const bg = isDark ? "bg-white/10" : "bg-black/10";

// GOOD: Tailwind dark: variant, server-safe
const bg = "bg-black/10 dark:bg-white/10";
```

Reserve `useTheme()` / `resolvedTheme` only for non-class logic (inline style values, conditional rendering).

## Verification
- Toggle theme — colors should interpolate smoothly over 0.6s
- No flash of wrong theme on page load
- No hydration mismatch warnings in console

## Gotchas
- `initial-value` in `@property` must be a valid value for the declared syntax — use the light theme value
- Each property must be registered individually (no shorthand)
- `@property` has good browser support (Chrome 85+, Safari 15.4+, Firefox 128+)
- After changing `@property` declarations, clear `.next` cache — stale CSS can persist

## macOS Glassmorphism Reference Values
When building macOS-style UI that transitions between themes:

| Element | Light Mode | Dark Mode |
|---------|-----------|-----------|
| Popover | `bg-white/75 blur(30px) saturate(250%)` | `bg-white/12 blur(30px) saturate(150%)` |
| Menubar | `bg-white/72 blur(30px) saturate(250%)` | `bg-white/15 blur(30px) saturate(150%)` |
| Dock | `bg-white/65 blur(24px) saturate(250%)` | `bg-white/15 blur(24px) saturate(150%)` |

## References
- [CSS @property spec](https://developer.mozilla.org/en-US/docs/Web/CSS/@property)
- macOS NSVisualEffectView reverse-engineering for glassmorphism values
