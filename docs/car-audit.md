# `Assets.car` Icon Stack Audit

> This audit is intended to uncover implementation details of compiled macOS asset catalog files by studying a sample of `Assets.car` files, to better inform Recompose's reconstruction pipeline. It was performed by Codex on September 5, 2026 against the pipeline present in `Recompose v0.1.0 alpha`, with a corpus of human-selected CAR files intended to cover a broad range of use cases and icon types, including:
> 
> - Apple and third-party apps
> - For Apple apps, both bundled macOS system apps and downloadable apps
> - App Store and non-App Store apps
> - Old/unmaintained apps, such as Adobe XD, and new apps/apps known to be up to date with latest technologies, such as Sketch
> - Longstanding Mac utilities like Grapher and Image Capture which have historically received only minimal updates to support the latest macOS platform standards, as well as newer, more public-facing tools like Maps, Stocks, and Photos
> - Large cross-platform apps like Chrome and Firefox that may be less concerned about adhering to standard macOS implementation patterns
> - Edge case icons with unique properties, such as Calendar and Clock
> - Localizable icons such as Font Book, Calendar, and Stocks
> - Visual variety of icons
>   - The new Golden Gate Siri icon, which the v0.1.0 pipeline processes successfully, but whose recomposed icon does not render correctly in Icon Composer due to some properties getting lost
>   - Icons with illustrative graphics that do not obviously resemble Liquid Glass, like Transmission or Keka
> - Both Tahoe-era Xcode 26, and Golden Gate-era Xcode 27 beta, for comparison's sake
> 
> The findings come from empirical inspection of the supplied corpus and, where noted, runtime inspection of Apple’s private CoreUI behavior. They should not be read as official Apple documentation or as proof that no other structures exist in other catalogs.

## Apps audited

The corpus contained 36 `Assets.car` files from:

- 1Password v8.12.34
- Activity Monitor v10.14
- Adobe XD v61.0.12.1
- Amphetamine v5.3.2
- App Store v3.0
- Automator v2.10
- Calendar v27.0
- Clock v1.1
- Compressor v5.3
- DaisyDisk v4.34.2
- Day One v2026.17
- Dropbox v269.4.4231
- Firefox v152.0.6
- Font Book v11.0
- Google Chrome v152.0.7977.77
- Grapher v2.8
- Image Capture v8.0
- Image Playground v1.0
- Keka v1.6.7
- Mactracker v8.2.3
- Maps v3.0
- Microsoft Excel v16.112.3
- Paprika Recipe Manager v3.8.4
- Photo Booth v13.1
- Photos v12.0
- Preview v11.0
- Shortcuts v10.0
- Siri AI v1.0
- Sketch v2026.2.1
- Stocks v8.0
- Time Machine v1.3
- Transmission v4.1.3
- Typora v1.14.8
- WhatsApp v26.30.77
- Xcode v26.6
- Xcode Beta v27.0

The audit was conducted on a system running macOS Golden Gate 27.0 beta; audited system apps correspond to that macOS release.

## Headline results

The corpus confirms that Recompose should discover icon stacks by logical asset name, not assume `AppIcon`.

All 36 supplied `Assets.car` files were audited read-only. No pipeline or repository files were changed.

- 36 catalogs inspected.
- 31 of 36 catalogs contained at least one icon stack.
- 38 logical icon stacks were found across those 31 catalogs.
- 20 of 38 icon stacks were named `AppIcon`.
- 4 of 36 catalogs contained multiple icon stacks.
- 5 of 36 catalogs contained no icon stack.
- Every CAR was readable; none exercised the generic “cannot process CAR” state.

As a deliberately broad corpus, not a random sample, the 4/36 catalogs containing multiple icon stacks should not be treated as a general population estimate. It nevertheless demonstrates that multiple-stack catalogs are a real case the UI must accommodate.

## Asset names and multiplicity

The catalogs containing multiple icon stacks were:

| Catalog | Icon stacks |
|---|---|
| Automator | `AppIcon`, `AutomatorService`, `Speech` |
| Microsoft Excel | `Excel_macOS`, `PrideThemedAppIcon` |
| Xcode 26 | `Xcode`, `XcodeCloud`, `XcodeIntelligence` |
| Xcode 27 beta | `XcodeBeta`, `XcodeCloud`, `XcodeIntelligence` |

Single icon stacks with nonstandard names included:

| Catalog | Name |
|---|---|
| 1Password | `Icon` |
| DaisyDisk | `DaisyDisk` |
| Font Book | `fontbook` |
| Grapher | `Grapher` |
| Keka | `Keka` |
| Mactracker | `MactrackerIcon` |
| Sketch | `app` |
| Transmission | `Transmission_Tahoe` |

The remaining catalogs with a single icon stack used `AppIcon`: Activity Monitor, App Store, Calendar, Clock, Compressor, Firefox, Google Chrome, Image Capture, Image Playground, Maps, Photo Booth, Photos, Preview, Shortcuts, Siri AI, Stocks, Time Machine, Typora, and WhatsApp.

The five valid catalogs with no icon stack were:

- Adobe XD
- Amphetamine
- Day One
- Dropbox
- Paprika Recipe Manager

Adobe XD, Amphetamine, Day One, and Paprika still contain conventional flattened icon renditions. Dropbox contains other named icon-like resources—badges, overlays, and folder icons—but no application icon stack.

Notably, Day One and Paprika were compiled using recent Xcode 26-era tools. Therefore, **compiler recency does not imply that an app adopted Icon Composer’s icon-stack format**; that is an authoring choice.

## The logical-asset model was correct

The useful public-facing object is:

```text
logical named asset
  └── IconImageStack
      ├── light representation
      ├── dark representation
      └── tinted representation
```

Individual renditions are implementation details beneath that logical asset, so they don't need to be used to identify icon stacks.

During runtime inspection of the private CoreUI implementation available in the audit environment, named-lookup enumeration did not surface every icon stack as an icon-stack object. It surfaced most icon stacks, but missed Calendar, Font Book, and Stocks. Those catalogs carry layout-direction/flippable conditions, and enumeration surfaced their underlying data and multisize records instead.

A robust discovery method tested successfully across all 36 catalogs:

1. Enumerate named logical lookups.
2. Collect names represented by multisize image sets and directly visible icon-stack objects.
3. Ask the catalog whether each candidate name resolves as an icon stack under the recognized appearance aliases.
4. Keep only successful resolutions.

That produced the exact same set of 38 icon stacks as the independent catalog metadata, with no false positives—including Xcode’s 80-plus unrelated multisize candidates and Dropbox’s 13 candidates that were not icon stacks.

So Recompose can still think in terms of logical assets; it does not need to show or reason about raw renditions.

One additional detail observed in the audited CoreUI runtime: direct lookup names sometimes carried an `.iconstack` suffix, while icon-stack retrieval used the suffixless logical name. The UI should report the suffixless logical name. These lookup behaviors are runtime observations, not documented or stable CoreUI contracts.

## What an `IconImageStack` looks like in practice

All 38 icon stacks shared these structural traits:

- 1024×1024 canvas
- scale 1
- three appearance representations: light, dark, and tinted
- storage version 17
- no precomposited image stored in the icon stack itself
- a matching flattened icon resource and multisized image set elsewhere in the CAR

The light/dark appearance identifiers are not perfectly uniform:

- 34 icon stacks use macOS-style `Aqua`/`Dark Aqua` identifiers.
- Clock, Maps, Stocks, and WhatsApp use UI-style `Light`/`Dark` identifiers.
- All 38 icon stacks use the same tintable appearance identifier.

An icon stack’s reported `LayerCount` is not its total number of graphic assets. It represents the background plus logical groups. Across this corpus:

- 4 icon stacks have 1 group
- 5 icon stacks have 2 groups
- 10 icon stacks have 3 groups
- 19 icon stacks have 4 groups

A leaf slot is one resolved position within a logical group that contains a raster or vector layer; corresponding slots can resolve to different source artwork in the light, dark, and tinted appearances. The 120 logical groups contain 204 leaf slots in each appearance. Leaf content consisted entirely of:

- vector SVG layers
- raster image layers

No third, previously unknown leaf class appeared.

Of the 38 icon stacks, 16 were vector-only, 6 were raster-only, and 16 contained mixed raster and vector content in the light appearance.

The flattened icon renditions compiled alongside each icon stack could become useful comparison references for future fidelity testing, though they may include system rendering treatment beyond the authoring document.

## Reconstruction pressure test

An audit-only probe discovered 38 logical icon-stack names in the corpus; each name was then passed to the unchanged v0.1.0 extractor, which successfully extracted all 38 icon stacks.

Running those extracted manifests through the v0.1.0 reconstruction stage produced:

- 12 completed `.icon` documents
- 26 aborts

The first reported v0.1.0 failure categories were:

| Baseline failure reason | Icon stacks |
|---|---:|
| Shadow style `0` was not mapped | 10 |
| Appearance-specific source structure was not represented | 8 |
| One-color fills were not mapped | 5 |
| Vector intrinsic dimensions were unavailable | 2 |
| Leaf blend mode was not mapped | 1 |

These are only first failures; the reconstruction stage stopped at the first failure for each icon stack, and several affected icon stacks contain additional properties not handled by v0.1.0.

More importantly, successful reconstruction does not guarantee a faithful recomposed icon. Several completed documents silently lost rendering information.

## Most consequential rendering discoveries

### 1. Group blend modes are not preserved in v0.1.0

This is the strongest candidate for the Siri mismatch.

The extractor records blend modes on groups, but the reconstructor does not write a group `blend-mode` property. 18 of 38 icon stacks use at least one non-normal group blend mode.

Observed group modes:

- multiply
- screen
- lighten
- soft light
- hard light
- plus lighter

13 of 38 icon stacks also change group blend mode between appearances.

Siri specifically contains:

- a `glass` group using lighten
- a caustic-light group using plus lighter
- a special-effects group using multiply in light mode but plus lighter in dark and tinted modes

All of that is omitted even though the v0.1.0 reconstruction stage completes and produces a recomposed Siri icon.

### 2. The v0.1.0 reconstructor does not map every observed leaf blend mode

Leaf layers additionally use:

- screen
- overlay

The v0.1.0 reconstructor recognizes normal, multiply, and plus lighter. It stops when it encounters Image Playground’s screen blend mode; Transmission contains both screen and overlay.

### 3. One-color fill records occur legitimately

The corpus contains 17 single-color fill records among the appearance-specific values resolved during the audit, while the v0.1.0 reconstructor requires exactly two gradient colors. These records may represent solid fills encoded through the same material channel.

They appear in icon stacks including 1Password, Firefox, Mactracker, Transmission, WhatsApp, Xcode Intelligence, Automator Speech, and Time Machine.

Their exact semantics and corresponding editable `.icon` representation have not yet been validated.

### 4. Shadow style zero likely means “none”

During runtime inspection, the audited CoreUI accessor returned raw shadow style `0` where serialized catalog metadata omitted a shadow style. The v0.1.0 reconstructor does not map it.

Existing `.icon` examples use `shadow.kind = "none"`, which supports interpreting zero as none/default.

The exact mapping has not been independently validated, and opacity values alone are insufficient evidence because CoreUI can return apparent default opacity values even when no shadow is enabled.

### 5. Appearances can use different source artwork

9 of 38 icon stacks swap the actual underlying asset between light, dark, or tinted appearances:

- Keka
- Mactracker
- Sketch
- all six Xcode/Xcode Beta icon-stack variants

Examples:

- Keka uses separate default, dark, and monochrome raster artwork.
- Sketch uses three distinct images.
- Xcode swaps hammer artwork for default, dark, and monochrome forms.
- Xcode Intelligence sometimes changes a slot from vector artwork to raster artwork in dark mode.

The v0.1.0 manifest format and reconstructor assume corresponding layers always have the same source name and media type, explaining the layer-order mismatches.

### 6. Wide-gamut and high-bit-depth alternatives are not preserved in v0.1.0

6 of 36 apps contain P3 raster alternatives across 11 logical assets:

- 1Password
- Chrome
- Grapher
- Preview
- Siri
- Sketch

The v0.1.0 extractor requests the default gamut, so it selects the 8-bit alternative even when a 16-bit/P3 rendition exists.

Siri’s `dark-speculars-16bit-v4` is a concrete example: the CAR contains a higher-precision alternative, but the extracted PNG is the default 8-bit gray-plus-alpha version. Thus the recomposed icon produced by v0.1.0 loses both group compositing behavior and source precision/gamut.

### 7. Localization and layout direction exist inside icon stacks

Font Book contains 17 localized versions of one vector layer, covering multiple Arabic, Indic, East Asian, and other locales.

Calendar, Font Book, and Stocks include flippable/right-pointing layout-direction metadata. The v0.1.0 extraction resolves one variant and does not preserve those conditions.

It remains unknown whether Icon Composer’s editable `.icon` format can represent these compiled conditions directly or whether they are introduced during compilation.

### 8. The apparent vector-scaling failures are based on incorrect intrinsic sizes

The v0.1.0 extractor falls back to 1024×1024 when it cannot obtain a vector’s intrinsic dimensions. This causes the v0.1.0 reconstructor to treat legitimate non-square SVG placement as nonuniform scaling.

For example:

- Typora’s 98×112 SVG is placed at 490×560: exactly 5×.
- Its 146×112 SVG is placed at 730×560: also exactly 5×.
- Transmission shows similar uniform transforms when compared with the SVG view boxes.

So these are not actually malformed frames. The SVG view box—or another authoritative vector bounds source—needs to provide the intrinsic size.

## Special cases

Calendar’s icon stack is static: background plus `blackdots`, `reddot`, and `sash` vector groups. No current-date semantic was found in the icon-stack metadata.

Clock is likewise a static icon stack: `Dial`, `Hour`, `Minutes`, and `Seconds` groups. There is no timekeeping, rotation, or animation annotation in the CAR icon stack. Any live behavior must be added elsewhere by the application or system.

Keka and Sketch each use one flattened-looking raster layer but swap artwork by appearance. “No obvious Liquid Glass” does not mean “simple single source.”

Transmission has ten vector leaf layers and several lighting-effect flags despite its intentionally illustrative appearance. The CoreUI flag should therefore be described as a rendering/material annotation, not as proof that the icon visually uses Liquid Glass.

Xcode 26 and Xcode 27 beta use the same broad container model—same storage generation, three appearances, and familiar layer classes. The compared icon stacks differ in artwork and material combinations without introducing an entirely new CAR structure.

## Additional annotation ranges

The corpus also revealed values outside the narrowest initial assumptions:

- group blur strengths from 0.1 to 1
- refraction strengths including negative values
- shadow opacity values above 1, reaching 2.2
- group opacity reaching zero
- translucency from 0 through 0.9
- inside and outside specular placement
- frequent per-appearance changes to opacity, fill, lighting, blend, shadow, translucency, and specular properties

Separately from the CAR inspection, Icon Composer has been observed to accept shadow opacity values above 100% and update its rendering accordingly, so values above 1 should not be assumed invalid.

No group-level fills were observed. Refraction parameters never varied between appearances in this sample.

## What this means for the UI

The data supports exactly the UI model we discussed:

1. **No icon stack found**  
   A valid CAR was processed, but it has no `IconImageStack`.

2. **One icon identified**  
   Show the discovered logical name—even if it is `Icon`, `app`, `fontbook`, or something else—and offer reconstruction.

3. **Multiple icons identified**  
   Present all logical names. The CAR metadata did not provide a reliable universal “primary app icon” marker, so choosing is appropriate.

4. **Cannot process CAR file**  
   Reserve for unreadable or corrupt files, unrecognized input formats, catalog variants the pipeline cannot interpret, or processing/tooling failures—not for a valid catalog containing no icon stack.

The most important overall conclusion is that icon stack discovery is quite solvable. The larger engineering work is fidelity: trial-and-error refinement of the pipeline to ensure the recomposed icon properly resembles the original rendering. The audit has revealed that appearance-specific source artwork, group blend modes, gamut selection, fill/shadow semantics, localization/layout variants, and correct vector bounds are all independently significant properties the pipeline must account for.
