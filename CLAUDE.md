# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**DockTile** is a multi-instance, AI-powered macOS utility for macOS 15.0+ (Tahoe) that serves as a minimalist "app container" in the Dock. It enables power users to pin multiple distinct dock tiles (via Helper Bundles like DockTile-Dev, DockTile-Design), each with independent app lists and custom icons/tints.

## Architecture Principles

### Multi-Instance Architecture
- Users generate unique Helper Bundles to create multiple independent dock tiles
- Each Helper instance maintains its own app list and visual customization
- Enables context-specific app organization (e.g., development vs. design workflows)

### Hybrid UI Framework Strategy
- **SwiftUI**: For declarative UI components and views
- **AppKit (NSPanel)**: For precise window management and popover control
- This hybrid approach balances modern Swift declarative patterns with low-level Dock integration requirements

### AI-Driven Sorting (Apple Intelligence)
- Uses **AppIntents framework** for dynamic app reordering
- Sorting factors: usage patterns, Focus modes, time of day
- **Privacy-first**: All processing happens on-device (no network calls)
- Contextual intelligence reduces cognitive load for users

### Interaction Model
- **Left-click**: Triggers snappy `NSPanel` popover grid (<100ms appearance target)
- **Right-click**: Displays AI-sorted `NSMenu` list (alternative interaction)
- **Ghost Mode**: Changes `ActivationPolicy` to `.accessory` to hide app from Dock/Cmd+Tab while maintaining functionality

## Technical Constraints

| Requirement | Specification |
|-------------|---------------|
| Platform | macOS 15.0+ (Tahoe Ready) |
| Language | Swift 6 (strict concurrency enabled) |
| UI | SwiftUI + AppKit NSPanel |
| Design System | Liquid Glass materials, 24pt corner radius |
| Typography | Off-black text (#1D1D1F) on Medical White backgrounds |
| Performance | <100ms popover appearance, zero flicker on mode switching |

## Design Philosophy: Medical White Minimalism

The aesthetic is inspired by Xiaomi/HOTO design principles:
- **Medical White**: Clean, clinical appearance with high contrast
- **Liquid Glass Materials**: Premium visual treatment with 24pt corner radius
- **High-Density Functionality**: Maximum utility with minimal visual clutter
- **Performance as Design**: Speed and responsiveness are UX features

## Critical Implementation Notes

### Swift 6 Concurrency
All code must be concurrency-safe to leverage Swift 6's strict checking. Use `@MainActor` for UI components and properly isolate shared state.

### Tahoe Integration
- Use system-standard `Customize Folder` UI for tinting and SF Symbol selection
- Leverage native macOS 15.0+ customization capabilities
- Follow Apple's design paradigm for seamless OS integration

### Performance Targets
- Popover appearance: <100ms from click to visible
- Mode switching: Zero visible flicker
- Helper instances: Maintain independent state without crosstalk

### Privacy Boundaries
- All Apple Intelligence features process on-device only
- No network calls for AI sorting/recommendations
- No telemetry or usage data transmission

## Project Structure (To Be Created)

When initializing the project structure, organize as follows:

```
DockTile/
├── App/                    # Main application target
│   ├── DockTileApp.swift   # App entry point
│   └── AppDelegate.swift   # NSApplicationDelegate for Dock integration
├── Core/                   # Business logic
│   ├── AppManager.swift    # App list management
│   ├── SortingEngine.swift # AI-driven sorting logic
│   └── HelperBundleGenerator.swift  # Multi-instance creation
├── UI/
│   ├── Popover/            # NSPanel popover grid
│   ├── Menu/               # NSMenu right-click interface
│   └── Components/         # Reusable SwiftUI views
├── AppIntents/             # Apple Intelligence integration
│   └── SortingIntents.swift
└── Resources/
    ├── Assets.xcassets     # Icons, tints, visual assets
    └── Info.plist
```

## Build & Development Commands

**Note**: Project not yet initialized. After Xcode project creation:

```bash
# Build the project
xcodebuild -project DockTile.xcodeproj -scheme DockTile -configuration Debug

# Run tests
xcodebuild test -project DockTile.xcodeproj -scheme DockTile

# Build Helper Bundle Generator
# (Command TBD based on implementation)
```

## Key Implementation Decisions

### Why NSPanel over pure SwiftUI?
SwiftUI alone cannot provide the precise Dock popover positioning and window-level control needed for sub-100ms appearance times. NSPanel gives us:
- Exact screen positioning relative to Dock icon
- Fine-grained control over window level and behavior
- Ability to dismiss on focus loss (critical for Dock utility UX)

### Why AppIntents for AI Sorting?
- Native Apple Intelligence integration
- On-device processing guarantees
- System-level awareness of Focus modes and usage patterns
- Future-proof for Apple's AI roadmap

### Why Helper Bundles for Multi-Instance?
macOS Dock architecture doesn't support multiple instances of the same app. Helper Bundles are separate app bundles with minimal code that delegate to the main app, allowing independent Dock tiles with unique:
- Bundle identifiers
- Icons and tints
- Saved app lists

## Reference Documents

- **Full Specification**: `DockTile_Project_Spec.md` (138k tokens - comprehensive design document)
- This file is authoritative for all architectural and design decisions

## Success Metrics

1. Popover appears in <100ms (measured from click event to window visible)
2. Zero flicker when toggling Ghost Mode
3. Helper instances maintain completely independent state
4. AI sorting provides measurable reduction in clicks-to-app-launch
