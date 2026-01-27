# DockTile: Modular Development Prompts

### Prompt 1: The Foundation (App Shell & Ghost Mode)
"Create a macOS app called 'DockTile' using Swift 6. 1. Remove the standard `WindowGroup`. 2. Use `NSApplicationDelegateAdaptor` for lifecycle. 3. Implement a `Ghost Mode` setting: when true, set `NSApp.setActivationPolicy(.accessory)`; when false, set it to `.regular`. 4. Set `LSUIElement` to `true` in Info.plist but ensure it remains pinnable to the Dock. 5. Handle `applicationShouldHandleReopen` to toggle the UI."

### Prompt 2: The Snappy Popover (NSPanel)
"Implement the popover logic. 1. Subclass `NSPanel` to create a borderless, floating, transparent window (`FloatingPanel`). 2. Use `NSVisualEffectView` with `ultraThinMaterial` and a corner radius of 24pt. 3. Ensure the panel appears precisely above the Dock icon when triggered and disappears when it loses focus (hides on `resignKey`)."

### Prompt 3: Visual Design & Vibe (Xiaomi/HOTO Style)
"Design the SwiftUI `LauncherView`. 1. Aesthetic: 'Medical White' with a 0.5pt white inner stroke for a beveled glass look. 2. Grid: A 2x3 or 1x6 grid with 24pt padding and generous whitespace. 3. Palette: Background #F5F5F7 at 80% opacity, Text #1D1D1F. 4. Animation: Use a spring animation `spring(response: 0.3, dampingFraction: 0.7)` for the panel entrance."

### Prompt 4: Multi-Instance Generator
"Build an Instance Manager. 1. Create a script that duplicates the app bundle. 2. Programmatically update the `CFBundleIdentifier` and `CFBundleName` in the copy's Info.plist. 3. This allows the user to have 'DockTile-Design' and 'DockTile-Dev' as separate, pinnable items in the macOS Dock."

### Prompt 5: Context Menu & Tahoe UI
"1. Implement `applicationDockMenu` to return an `NSMenu` that lists the apps inside the tile for quick launching. 2. Integrate the native macOS Tahoe 'Customize Folder' UI logic so the user can tint the DockTile and select an SF Symbol icon that updates the Dock presence dynamically."

### Prompt 6: Apple Intelligence Integration
"Integrate Apple Intelligence for sorting. 1. Use `AppIntents` to track app launches. 2. Create a predictive sorting algorithm that reorders the SwiftUI grid based on usage frequency and the current system Focus Mode. 3. Ensure all data processing stays on-device for privacy."