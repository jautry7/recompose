## Platform compatibility

- Target macOS 26 Tahoe as the minimum supported operating system.
- Do not use APIs or behavior introduced in macOS 27 Golden Gate unless an availability-gated fallback preserves full functionality on Tahoe.

## Project character

- Keep Recompose a casual, lightweight, somewhat scrappy open-source project. Maintain good repository hygiene without introducing enterprise-scale process or architecture.
- Keep the public repository lean and product-facing. Put contributor and implementation guidance in this file rather than expanding the README with internal detail.

## Application architecture

- Build the native interface with AppKit and prefer native macOS controls, semantic colors, text styles, SF Symbols, and window behavior over custom reproductions.
- Do not recreate or imitate system window controls. Let AppKit provide them even when beta design resources differ from the shipping system appearance.
- `RecompositionEngine.swift` is currently an orchestration wrapper around the bundled command-line helpers; it is not the reconstruction engine itself.
- Preserve the working extraction and reconstruction implementation in Objective-C. Do not rewrite or substantially refactor that pipeline in Swift.
- The intended long-term engine is an Objective-C `RecomposeCore` integrated with the Xcode project and shipped inside the app bundle. The helper executables are internal implementation details, not peer products that must be distributed separately from the app.
- The current helper binaries are arm64-only, but the end goal is for `RecomposeCore` and the app to support a universal binary so Recompose can be built and tested on Intel Macs running macOS 26 Tahoe as well as Apple silicon Macs.
- Leave the current `cli/` organization and names in place unless an architectural change is explicitly requested. Public CLI support can be evaluated later.
- The prebuilt CLI binaries may remain committed to the public repository as release-like artifacts.

## Current scope

- The app currently supports the `AppIcon` asset only. Arbitrarily named `IconImageStack` assets are future work.
- Do not modify or pressure-test the extraction pipeline while working on the interface. Resume extraction-fidelity work only when the user explicitly requests it.
- Preserve the known-working Objective-C helpers and their behavior while the application shell is being developed.

## UI workflow

- Keep the interface small, simple, and native rather than introducing a larger navigation or view architecture without discussion.
- The user performs visual inspection of running builds. Do not request or perform visual inspection of the app unless the user explicitly asks for it.
