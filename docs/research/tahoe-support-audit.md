# Tahoe support audit

> Point-in-time record of Recompose's verified macOS Tahoe 26 compatibility findings as of September 10, 2026. This document preserves the evidence and conclusions of the Tahoe investigation. The current format rules belong in the two living specifications under `docs/specs/`.

## Scope

This audit covers three boundaries that must be evaluated separately:

1. whether an editable `.icon` document opens in a particular Icon Composer version;
2. how an accepted document is compiled into an `IconImageStack` by a particular Xcode version; and
3. whether the document or compiled stack renders like the source under the same renderer.

Acceptance does not establish rendering fidelity. Structural read-back does not establish visual fidelity. Differences in CAR headers or private rendition encodings do not establish either kind of failure.

This project uses **v26** for the first public Liquid Glass icon-document generation associated with macOS Tahoe 26, Icon Composer 1, and Xcode 26. It uses **v27** for the later generation associated with macOS Golden Gate 27, Icon Composer 2, and Xcode 27. The `v` labels refer to the document specification, not the product version displayed by Icon Composer or Xcode.

## Evidence consulted

This audit consolidates:

- the original 109-stack recompilation audit and its follow-up findings;
- the 43-stack Xcode 26/Xcode 27 corpus comparison;
- focused HomeKit Accessory Simulator, Logic Pro Creator Studio, and Keka tests;
- seven v26 documents generated for the Tahoe acceptance probe;
- Xcode 26.5 and Xcode 26.6 bulk compilations of those seven documents;
- normalized CoreUI read-back and decoded-artwork comparisons;
- manual acceptance and general preview checks performed in Icon Composer 1.5 and 1.6;
- the current `.icon` document and compiled icon-stack specifications;
- repository history beginning with the original Tahoe-differences investigation.

The source applications and CARs were inspected as supplied test evidence. Their product versions and compiler provenance are independent: an application updated later can still contain an icon stack compiled by an earlier Xcode generation.

## Toolchains exercised

| Environment | Version | What was tested |
|---|---|---|
| macOS Tahoe | 26.6.2 | Manual Icon Composer and Xcode work |
| Icon Composer | 1.5 | v27 rejection; all seven v26 probe documents opened and generally rendered as expected |
| Icon Composer | 1.6 | v27-aware rejection message; all seven v26 probe documents opened and generally rendered as expected |
| Xcode | 26.5 build `17F42` | Bulk compilation and CoreUI read-back of all seven v26 probe documents |
| Xcode | 26.6 build `17F113` | Focused and bulk compilation and CoreUI read-back |
| Icon Composer | 2.0 beta | Earlier v27 reconstruction acceptance |
| Xcode | 27.0 beta build `27A5252f` | Original recompilation audit and second-generation Keka round trip |

Icon Composer 1.6 recognizes the v27 `refractivity` and `specular-location` declarations as belonging to a newer document format, but it does not support opening documents that use them. Its observed change from Icon Composer 1.5 is awareness and a more informative error, not v27 editing support.

## Compiler-generation provenance

A focused inventory of CARs containing icon stacks produced this distribution:

| Reported source compiler | Catalogs | Logical icon stacks |
|---|---:|---:|
| Xcode 26 | 16 | 19 |
| Xcode 27 | 20 | 24 |

In this corpus, the CAR-wide `AssetStorageVersion` was the reliable compiler-generation signal:

- every Xcode 26 catalog reported an Xcode 26 build and CoreUI `965...975`;
- every Xcode 27 catalog reported an Xcode 27 build and CoreUI `1008` or `1010`;
- an Xcode 26 value is high-confidence evidence that the stack was compiled by the Tahoe-era toolchain;
- an Xcode 27 value proves v27 compiler provenance but does not prove that the icon uses v27-only material properties; and
- missing or unrecognized compiler metadata leaves the generation unknown.

The material values in the Default/Light stack records supported the classification without replacing it:

- all 19 v26 stacks used specular placement `0` and zero refraction depth and strength;
- 15 of 24 v27 stacks used at least one explicit inside or outside specular placement;
- 12 of 24 v27 stacks used nonzero refractivity; and
- some v27 stacks used neither newer behavior.

The absence of explicit placement or refractivity therefore cannot identify a stack as v26. The inspected `sourceObjectVersion`, rendition object version, `renderingProperties`, and group-level `hasLightingEffects` values did not distinguish the generations and must remain diagnostic rather than classificatory.

## Editable-document compatibility

Document compatibility is forward-only. A v26 document can be opened in Icon Composer 2 and receives the current material rendering. A document that contains v27-only declarations or properties cannot be opened by the tested Tahoe-era Icon Composer releases or compiled by the tested Xcode 26 releases.

The observed rejection behavior was:

- Icon Composer 1.5 reported a generic formatting error for the tested v27 document;
- Icon Composer 1.6 reported, “This document uses features from a newer version of Icon Composer”; and
- Xcode 26 rejected the document through `actool` before producing a comparable CAR.

This source-document restriction is separate from deployment compatibility. Current Xcode versions can compile icon resources for supported earlier deployment targets even though the corresponding older authoring tools cannot consume the current source document.

### Verified v26 material serialization

The v26 writer must not turn a default decoded by the current CoreUI runtime into a property that did not exist in the source generation. The accepted rule is:

```text
omit the root "features" declaration
omit group refractivity

hasSpecular == false
  -> "specular": false

hasSpecular == true and placement == 0
  -> omit specular
```

Boolean `false` is required to preserve an explicit opt-out. Omitting `specular` for a false source value allows Xcode 26 to compile that group with specular enabled. Conversely, writing v27's `"automatic"` value for an enabled legacy placement `0` invents a newer material instruction. A v26 writer cannot represent enabled placements `1` or `2` and must reject them rather than approximate them.

The v27 writer retains the current root feature declarations, refractivity, and explicit `automatic`, `inside`, or `outside` specular placement.

### HomeKit material case

The HomeKit Accessory Simulator source CAR reports Xcode 26.6 build `17F103` and CoreUI 974. Its `AppIcon` has four groups and five source assets. Across Light, Dark, and Tintable:

- Blueprint Grid reports `hasSpecular == false`;
- the other groups report `hasSpecular == true` with placement `0`; and
- every group reports zero refraction depth and strength.

An omission-only experiment visually matched the production application in Icon Composer, but Xcode 26.6 re-enabled specular on Blueprint Grid during compilation. The corrected writer preserved Blueprint Grid as `"specular": false` while omitting the enabled placement-zero values on the other groups.

Xcode 26.6 build `17F113` accepted the corrected document. Normalized read-back matched the source stack's canvas, hierarchy, order, geometry, fills, opacity, blend modes, blur, lighting, shadows, translucency, refractivity, and specular state in all three appearances. All 15 appearance-specific extracted SVG slots were byte-identical. Differences in CAR headers reflected the two Xcode 26.6 builds, not an identified icon-stack difference.

## Seven-document acceptance probe

Seven documents were generated with the explicit v26 writer to broaden the accepted-property coverage beyond HomeKit and Logic Pro:

| Fixture | Primary coverage |
|---|---|
| HomeKit | Explicit disabled specular and mixed legacy enabled states |
| Xcode | Disabled blueprint grid, mixed groups, and appearance-specific raster/vector artwork |
| Compressor | Blur, translucency, and combined versus individual lighting |
| Transmission | Mixed material groups, appearance variation, and a nonstandard stack name |
| Firefox | Broad appearance-specific material variation |
| Logic Pro | Zero-opacity plus-lighter leaf |
| Keka | Appearance-specific raster renditions |

The generated documents shared these generation rules:

- no root v27 feature declaration;
- no group refractivity;
- Boolean `false` wherever the compiled source explicitly disabled specular;
- omission for enabled legacy placement `0`; and
- no inside or outside placement requiring v27.

The user manually confirmed that all seven documents opened and generally rendered as expected in both Icon Composer 1.5 and Icon Composer 1.6. Fine rendering details were deliberately not assessed at that stage. The result verifies document acceptance across a broader combination of established properties, but it is not a cross-version visual-fidelity result.

## Xcode 26.5 and 26.6 compilation boundary

The seven probe documents were added to one Xcode project. Changing the target's app-icon selection did not limit the resulting CAR to one document: every compiled catalog bundled all seven logical icon stacks. The shortcut therefore produced a useful bulk comparison rather than seven isolated fixtures.

The Xcode 26.5 catalog reports:

```text
AssetStorageVersion: Xcode 26.5 (17F42)
CoreUIVersion: 975
SchemaVersion: 2
StorageVersion: 17
PlatformVersion: 26.5
```

The Xcode 26.6 catalogs report:

```text
AssetStorageVersion: Xcode 26.6 (17F113)
CoreUIVersion: 975
SchemaVersion: 2
StorageVersion: 17
PlatformVersion: 26.5
```

Each 26.6 CAR contains the same seven logical stacks, although the CAR files are not byte-identical because they were separate builds with different selected app-icon settings and container metadata.

Normalized comparison found no 26.5/26.6 difference in the seven logical stacks. For every fixture:

- stack, group, and surviving leaf structure matched;
- resolved material, fill, geometry, opacity, and blend properties matched;
- all three appearance-specific stack digests matched; and
- the same compiler canonicalizations occurred in both versions.

The tested boundary therefore contains no identified document, material, or compiled-stack semantic change. Icon Composer 1.6 changed its diagnosis of v27 documents, but Xcode 26.6 did not add v27 compilation support.

## Compiler canonicalization

Two structural or encoding changes were initially suspected to mark the v26/v27 boundary. The bulk comparison showed that both were already present in Xcode 26.5 and remained unchanged in Xcode 26.6.

### Logic Pro zero-opacity leaf

The original Logic Pro Creator Studio CAR reports Xcode 26.0 build `17A324` and CoreUI 969. It retains a zero-opacity, plus-lighter SVG glow leaf in Light, Dark, and Tintable. Recompose preserved that leaf and its artwork in the editable v26 document.

Both Xcode 26.5 and Xcode 26.6 omitted the leaf in all three appearances during compilation, as did the earlier Xcode 27 recompilation. Every surviving hierarchy, material, geometry, fill, and artwork comparison matched. This is compiler dead-layer elimination, not a failure by Recompose to preserve the editable source.

The exact point between Xcode 26.0 and 26.5 at which the behavior began was not tested. Because no rendered difference has been demonstrated, Recompose will not compensate for it or pursue the exact minor-version boundary as a product requirement.

### Keka raster encoding

Keka's source CAR reports Xcode 26.0.1 build `17A400` and CoreUI 969. Its Light, Dark, and Tintable raster renditions used CoreUI `zip` encoding. Recompose extracted those images to PNG and reused the exact extracted files in the reconstructed document.

Xcode 26.5, Xcode 26.6, and Xcode 27 compiled those inputs as `deepmap2`. In both tested Xcode 26 releases:

| Appearance | Differing decoded pixels from the source | Maximum channel difference | Alpha differences |
|---|---:|---:|---:|
| Light | 777,730 of 1,048,576 | 1 | 0 |
| Dark | 360,029 of 1,048,576 | 1 | 0 |
| Tintable | 0 | 0 | 0 |

Light and Dark retained their dimensions, alpha behavior, sRGB declaration, and EXIF metadata. Red was unchanged; only green and blue differed, by at most one 8-bit value. Tintable changed from equal-channel RGB to a Gray representation but expanded back to pixel-identical RGB.

The earlier Xcode 27 second-generation round trip was stable: rendition SHA-1 values matched and the extracted PNGs were byte-identical between the two Xcode 27 passes. The later Xcode 26.5/26.6 comparison establishes that the `zip` to `deepmap2` transition occurred within v26, not at the v26/v27 boundary.

This is a compiler-private encoding decision, not an identified missing `.icon` property or accumulating reconstruction loss. Recompose will not attempt to reproduce the earlier encoding in the absence of a demonstrated rendering difference.

## Cross-generation control: one-stop gradients

A literal one-stop `linear-gradient` was rejected by Icon Composer 1.5, Xcode 26.5, Icon Composer 2, and Xcode 27. Both generations accepted a two-stop gradient whose endpoint colors were identical, and both compiled it as a two-stop named gradient.

The one-stop gradient records found in shipping CARs are therefore not evidence of a public v26 feature removed in v27. Recompose reconstructs them with two identical endpoint colors as the nearest accepted public representation.

## What visual testing established

Manual evidence currently establishes:

- the original HomeKit omission-only reconstruction matched the production application's general Icon Composer appearance;
- all seven corrected v26 probe documents opened and generally rendered as expected in Icon Composer 1.5 and 1.6; and
- no obvious acceptance-stage rendering failure was reported for Default, Dark, or Mono.

It does not yet establish:

- detailed pixel or side-by-side fidelity between Icon Composer 1.5 and 1.6;
- detailed comparison of each v26 probe under Icon Composer's 26 and 27 design-generation previews;
- Finder or system-renderer fidelity for each compiled probe CAR; or
- whether the small decoded Keka differences are visible under system rendering.

The audit therefore treats document acceptance and normalized compilation as verified, while reserving fine visual-fidelity conclusions for direct human comparison.

## Recompose implications

The tested writer design is specification-specific:

- automatic selection uses the earliest specification capable of representing every resolved material value;
- v26 output omits newer feature declarations and refractivity, preserves explicit disabled specular, and omits legacy enabled placement `0`;
- nonzero specular placement cannot be represented in v26 and must fail explicitly; and
- compiler-private dead-layer and rendition-encoding choices are not reconstruction targets without evidence of a visual consequence.

A subsequent implementation selects the minimum required specification automatically and retains `--generation 26|27` as an explicit override for reconstruction and assembly. The v26 branch applies the verified compatibility rules, while the v27 branch preserves the current material behavior. Classification is based on resolved capabilities rather than `AssetStorageVersion`.

The interface reports the selected minimum specification as the document version while leaving the underlying asset name and default save filename unchanged.

## Remaining unknowns

- The `refractivity` and `specular-location` feature tokens were not isolated from their related properties, so the precise parser-gating role of each token is unknown.
- The seven accepted documents cover a broad combination of existing fields and specialization forms, but they do not constitute an exhaustive property-by-property v26 acceptance matrix.
- No nonzero refractivity or inside/outside specular placement has been observed in a v26-compiled source. Their omission from v26 is established; any contrary future evidence must fail visibly rather than be discarded.
- The exact minor Xcode 26 release that introduced Logic's dead-layer elimination and Keka's `deepmap2` encoding was not identified and is not currently considered relevant to rendering fidelity.
- Keka establishes one stable encoding transition, not the general rules by which Xcode selects `zip`, `deepmap2`, monochrome, or other rendition forms for every raster input.
- Recompose's private CoreUI discovery and extraction code was not run end to end on the Tahoe computer during this audit. The Tahoe testing covered generated document acceptance, Xcode compilation, and read-back of returned CARs, not runtime API compatibility on Tahoe itself.
- Subsequent user testing found the current application unable to complete reconstruction on Tahoe. The failing pipeline stage, exact diagnostics, and affected private CoreUI class or selector have not yet been isolated, so Tahoe runtime support remains an open product issue despite the verified v26 document writer.
- The availability of every private CoreUI and IconFoundation class, selector, and signature used by Recompose—and the application's failure behavior when one differs—remains unverified on Tahoe.
- Fine cross-version and system-renderer visual comparisons remain outstanding.

## Product decisions recorded by this audit

- Maintain one living current specification, with v26 compatibility notes beside rules that changed in v27.
- Use v26 and v27 exclusively as technical specification labels; use Icon Composer 1 and Icon Composer 2 only as product generations.
- Preserve the distinction between document acceptance, compiled representation, and rendered appearance.
- Select the earliest specification capable of representing every observed compiled capability.
- Keep compiler provenance separate from minimum-version classification.
- Do not compensate for compiler canonicalization that has no demonstrated visual effect.
- Prioritize rendering fidelity over byte-identical CAR output or reproduction of Apple's private encoding choices.

## Preserved evidence and repository history

The outer project workspace retains the generated seven-document probe, source manifests, Xcode 26.5 bulk CAR, and Xcode 26.6 CARs under `Codex/Outputs/`. It also retains focused HomeKit and Logic artifacts and the chat handoff that preceded the bulk probe. These files are evidence for this audit but are not part of the public repository.

Relevant repository milestones are:

- `da9aa03` — created the original Tahoe differences investigation;
- `886c2e5` — documented the verified HomeKit material behavior and corrected Logic result; and
- `05f2eba` — added explicit v26/v27 generation output and consolidated the Tahoe pipeline evidence.

Commit `af5ee85` repeats the Tahoe-documentation subject but contains only an unrelated Xcode asset-tag project change; it is not evidence for the writer implementation.
