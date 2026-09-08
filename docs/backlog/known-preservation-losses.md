# Known preservation losses

- Status: open
- Priority: 1

## Problem

Recompose currently resolves one effective rendition for display gamut, locale, and layout direction, and it recreates raster artwork from the resolved `CGImage`. The audited catalogs contain alternatives that this process does not preserve. Geometry reconstruction also assumes the 1024-point macOS canvas even though Apple Watch authoring uses a different canvas size.

These are observed preservation gaps, not hypothetical format extensions.

## Known losses

- Display P3 and higher-bit-depth raster alternatives can be skipped by the default-gamut lookup.
- Font Book contains localized variants that currently collapse to one resolved vector.
- Calendar, Font Book, and Stocks contain layout-direction or flippable variants that currently collapse to one resolved value.
- Raster export through `CGImage` and PNG does not necessarily preserve the source rendition's bit depth, profile, metadata, or encoding.
- Non-1024 canvases are not represented by the current hard-coded geometry center and default-frame calculations.

The Keka audit is an important constraint: its small raster sample changes were a stable Xcode 26 `zip` to Xcode 27 `deepmap2` canonicalization. Do not treat every byte or pixel difference as reconstruction loss, and do not compensate for changes introduced deterministically by the selected compiler.

## Work

1. Inventory the actual gamut, precision, locale, and direction alternatives present in the maintained corpus.
2. Determine which conditions and source representations the current `.icon` format can express.
3. Preserve each representable alternative and its correspondence across appearances.
4. Parameterize geometry by the resolved stack canvas instead of assuming a 1024-point square.
5. Distinguish source selection, decoded artwork preservation, and compiler rendition encoding in tests and documentation.
6. Record an explicit limitation when a compiled variant has no editable representation.

## Completion criteria

- Known P3/high-bit-depth alternatives are selected and retained when the current format can represent them.
- Known locale and layout-direction variants are preserved when representable, or documented as compiled-only limitations.
- Raster handling preserves available color and precision information without copying an unrelated CSI wrapper into the document.
- Geometry reconstruction uses the actual canvas size and is validated with a non-1024 document.
- Same-generation and cross-generation compiler canonicalization are not reported as the same phenomenon.
