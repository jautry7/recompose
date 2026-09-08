# Tahoe Support

> This study was started by Codex on September 7, 2026 following the icon-stack recompilation audit. It is specifically framed around macOS Tahoe as the conceptual first version of the Liquid Glass icon system and macOS Golden Gate as its conceptual second version. “v1” and “v2” are working terms used by this project, not official Apple version numbers. The two macOS releases nevertheless represent public milestones in the system's evolution. For posterity, this document compares Golden Gate's v2 behavior with Tahoe's v1 behavior and may become dated when macOS 28 introduces another generation.

## Purpose and status

This is Recompose's living Tahoe-support record and primary compatibility workstream. It separates differences caused by reconstruction from differences caused by the public Icon Composer and Xcode toolchains associated with the two Liquid Glass generations.

The study is not yet a complete compatibility matrix. It begins with cross-generation evidence uncovered while resolving the recompilation audit and keeps the related schema, compiler, runtime, and rendition work together.

## Toolchain context

The original recompilation audit reconstructed 109 icon stacks and compiled every reconstructed document with Xcode 27.0 beta build `27A5252f`, running on macOS 27.0 build `26A5425a`. Source CARs reported multiple compiler generations. Comparisons involving a source CAR produced by Xcode 26 or earlier therefore crossed the v1-to-v2 compiler boundary.

Manual Tahoe testing used:

- macOS Tahoe 26.6.2
- Xcode 26.5
- Icon Composer 1.5

Icon Composer 1.5 was selected as the latest tested release from before WWDC 2026, avoiding possible Golden Gate support introduced afterward.

Follow-up testing on the same Tahoe installation added Xcode 26.6 build `17F113` and Icon Composer 1.6. Icon Composer 1.6 recognizes newer `refractivity` and `specular-location` feature declarations and explains that they require a newer Icon Composer version, but it does not open documents that use them. The version therefore adds awareness of the v2 schema without providing direct editing support for those features.

The current evidence therefore distinguishes two related but separate boundaries:

| Boundary | v1 side | v2 side |
|---|---|---|
| Editable document | Icon Composer 1.5 and 1.6 | Icon Composer 2.0 beta |
| Compiled catalog | Xcode 26.5, Xcode 26.6 `17F113`, and other Xcode 26 builds | Xcode 27.0 beta `27A5252f` |

## Origin in the recompilation audit

The audit compared normalized icon-stack structure and extracted artwork rather than complete CAR bytes. Several findings initially admitted both a Recompose explanation and a compiler-generation explanation.

Finding 5 concerned a zero-opacity Logic Pro SVG layer that disappeared during Xcode 27 compilation. Finding 6 included raster images whose decoded samples changed by at most one 8-bit channel value after recompilation.

Subsequent focused testing distinguished two different situations:

1. The Logic Pro reconstruction is accepted by the v2 tools but rejected by the v1 tools, making it a genuine Tahoe compatibility question.
2. Keka exposes a concrete change in CoreUI image encoding between an Xcode 26 source CAR and an Xcode 27 recompiled CAR.

## Logic Pro: v2 acceptance and v1 rejection

The audit's Logic Pro Creator Studio case contains a group with two SVG leaves. One is a plus-lighter glow layer with opacity zero in Light, Dark, and Tinted. Recompose retained the asset, reference, blend mode, and zero opacity in the editable document. Xcode 27 compiled the document but omitted that leaf from all three resulting appearance stacks.

The initial interpretation was that Xcode 27 might perform dead-layer optimization. The source Logic CAR reported Xcode 26.0, making a compiler-generation change plausible.

Manual user testing added a more fundamental compatibility result:

- The reconstructed Logic document opens successfully in the Golden Gate-era Icon Composer.
- Icon Composer 1.5 on Tahoe rejects the same document with “The data isn't in the correct format.”
- Xcode 26.5 also refuses to compile it and produces an underlying nil-array-style failure.

The failure indicates that the public v1 parser encountered data it could not represent. It occurs before a compiled layer can be inspected, so the audit no longer supports attributing Finding 5 solely to dead-layer optimization.

Potential compatibility boundaries visible in the Logic document include the `specular-location` feature token and its related specular fields, refractivity, translucency, blur material, and the zero-opacity plus-lighter layer. These are hypotheses rather than identified causes. They are deliberately reserved for the unified Tahoe investigation so that individual v1 incompatibilities are not patched without a coherent versioning model.

## Keka: `zip` to `deepmap2`

Keka supplied a focused example of the small raster differences grouped under Finding 6. Its source stack reported Xcode 26.0.1 build `17A400`, CoreUI 969. The source Light, Dark, and Tinted layer renditions used CoreUI `zip` compression and were reported as 8-bit sRGB RGB images.

Recompose extracted those renditions into PNG files and placed those exact files in the reconstructed `.icon` document. The Light and Dark PNGs contained an sRGB chunk and identical EXIF metadata. Xcode 27 beta compiled the reconstruction into CoreUI 1010 renditions using `deepmap2` rather than `zip`.

The resulting Light and Dark images retained their dimensions, alpha behavior, sRGB declaration, and EXIF data. Their decoded RGB samples nevertheless changed slightly:

| Appearance | Differing pixels | Maximum channel difference | Alpha differences |
|---|---:|---:|---:|
| Light | 777,730 of 1,048,576 | 1 | 0 |
| Dark | 360,029 of 1,048,576 | 1 | 0 |
| Tinted | 0 | 0 | 0 |

Red was unchanged at every pixel in Light and Dark. Changed green and blue samples moved only by `-1` or `+1`. The same source green or blue value could produce different results depending on the other channel values, ruling out a simple independent lookup-table adjustment. The pattern is consistent with a coupled internal encoding or color transform associated with the new rendition representation.

Tinted exposed a different but lossless canonicalization. Its source extraction was an RGB PNG whose three channels were equal. Xcode 27 stored the recompiled rendition as monochrome, using Gray encoding and a Generic Gray Gamma 2.2 profile. Expanding that rendition back to RGB produced pixels identical to the source extraction.

### Second-generation round trip

The first Xcode 27 CAR was reconstructed again and compiled a second time with the same Xcode 27 beta build:

```text
Xcode 26 zip rendition
  → reconstructed PNG
  → Xcode 27 deepmap2 rendition
  → reconstructed PNG
  → Xcode 27 deepmap2 rendition
```

The second Xcode 27 compilation produced the same CoreUI rendition SHA-1 values as the first. The extracted Light, Dark, and Tinted PNGs were also byte-identical between the two Xcode 27 passes.

For Keka, the pixel transition is therefore a stable, one-time compiler canonicalization from the Xcode 26 `zip` representation to Xcode 27 `deepmap2`. It is not accumulating reconstruction loss, and no missing `.icon` color-space field has been identified. If the source Keka stack had already been compiled into the same `deepmap2` canonical form by the same Xcode 27 build, the tested evidence indicates that its Recompose round trip would preserve those rendition payloads exactly.

This conclusion is specific to the tested Keka stack and compiler builds. Other Xcode 27 revisions may use different CoreUI encoder revisions or settings.

## Current implications for Recompose

The v1 and v2 toolchains do not merely serialize the same public icon model into different catalog containers. They can differ at both boundaries relevant to Recompose:

- A `.icon` document accepted by the v2 editor and compiler may be rejected by the v1 tools.
- A decoded image accepted by both generations may be stored through a different CoreUI compression path, producing stable one-level sample changes.

Tahoe support consequently requires more than selecting a design-generation label. Recompose must eventually distinguish editable schema compatibility, compiler behavior, and rendition encoding, then decide which differences require version-specific output and which are unavoidable canonicalization by the selected compiler.

For now, Finding 5 of the recompilation audit – regarding the Logic Pro Creator Studio dead-layer – remains earmarked for this study. The Keka portion of Finding 6 requires no compensating Recompose code change: the source pixels and available color metadata were preserved in the editable document, and the observed change was introduced deterministically by Xcode 27's `deepmap2` encoding path.

## Open items

All Tahoe-specific compatibility work is maintained here rather than split into separate backlog tickets.

### Editable document compatibility

- Determine the minimum and canonical root keys accepted by Icon Composer 1.5 and 1.6 and Xcode 26.5 and 26.6.
- Test current feature tokens independently, including `refractivity` and `specular-location`, and determine whether they declare behavior, gate parsing, or both.
- Record which current group properties and specialization forms are accepted by each v1 tool.
- Test historical/current specialization placement and specular spellings only where they affect v1 acceptance or migration.
- Identify the exact property or combination that makes the reconstructed Logic document invalid under the v1 tools.

### Compiled catalog behavior

- Once a v1-compatible Logic document is available, determine whether Xcode 26 preserves or omits its zero-opacity plus-lighter glow layer.
- Compare how Xcode 26 and Xcode 27 choose among `zip`, `deepmap2`, monochrome, and other observed rendition encodings for the same source PNG.
- Separate differences that affect rendered output from decoded-sample, encoded-byte, and structural differences.
- Verify which differences stabilize within one compiler generation and which recur on every round trip.

### Recompose runtime compatibility

- Run discovery, extraction, assembly, document acceptance, compilation, and compiled read-back on Tahoe with a focused representative set.
- Enumerate only the private CoreUI classes, selectors, signatures, and defaults that Recompose uses, and compare their availability and behavior between Tahoe and Golden Gate.
- Define explicit failure behavior for a missing or changed private runtime surface rather than silently changing reconstruction output.

### Output policy

- Decide how Recompose selects a Tahoe-compatible or Golden Gate-compatible document schema.
- Preserve newer fidelity features when targeting Golden Gate without emitting documents that Tahoe cannot open when Tahoe output is requested.
- Record exact Icon Composer, Xcode, macOS, CoreUI, and document generations for every compatibility conclusion.
- Keep parser acceptance, compiled representation, and Finder/system rendering as separate evidence boundaries.
