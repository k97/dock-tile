# Testing

## Framework

| Purpose | Framework |
|---------|-----------|
| Unit Tests | Swift Testing (`@Test`, `#expect`, parallel by default) |
| UI Tests | XCUITest (locally only — requires Dock interaction) |

Module import name: `Dock_Tile`

## Commands

```bash
# All unit tests
xcodebuild test -project DockTile.xcodeproj -scheme DockTile \
  -configuration Debug -destination 'platform=macOS' \
  -only-testing:DockTileTests CODE_SIGNING_ALLOWED=NO

# Specific test class
xcodebuild test -project DockTile.xcodeproj -scheme DockTile \
  -destination 'platform=macOS' \
  -only-testing:DockTileTests/ConfigurationModelsTests

# With coverage
xcodebuild test -project DockTile.xcodeproj -scheme DockTile \
  -destination 'platform=macOS' -enableCodeCoverage YES
```

## Coverage Targets

| Component | Target |
|-----------|--------|
| Managers | 85-90% |
| Models | 80-90% |
| Utilities | 90%+ |
| UI Views | 50-60% |
| **Overall** | **75-80%** |

## Test Structure

```
DockTileTests/
├── Unit/
│   ├── Constants/AppStringsTests.swift
│   ├── Models/ConfigurationModelsTests.swift, TintColorTests.swift
│   └── Utilities/IconGeneratorTests.swift
├── Integration/DockRestartConsentTests.swift
└── Mocks/
```

## CI

Unit tests run in GitHub Actions (`ci.yml`). UI/integration tests run locally only.
