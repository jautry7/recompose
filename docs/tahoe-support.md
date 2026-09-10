# Tahoe Support

> This document outlines the differences in the Liquid Glass icon system between its first version, introduced with macOS Tahoe 26 (known as "v1" of the system), and its second major revision introduced for macOS Golden Gate 27 ("v2"). These version numbers align with Icon Composer's version numbers, but they are ultimately working terms used by this project, not official Apple version numbers. This document outlines changes between these two major milestones, and may become dated if/when macOS 28 introduces further changes.

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

## Verified learnings

### Compiled-era identification

A focused audit compared the icon stacks currently present in `Codex/Inputs/car-library`:

| Source compiler | Catalogs with icon stacks | Icon stacks |
|---|---:|---:|
| Xcode 26 | 16 | 19 |
| Xcode 27 | 20 | 24 |

The CAR-wide `AssetStorageVersion` was the reliable generation discriminator in this corpus. Every Xcode 26 catalog reported an Xcode 26 build and CoreUI `965...975`; every Xcode 27 catalog reported an Xcode 27 build and CoreUI `1008` or `1010`. The Xcode major records compilation provenance rather than the containing application's version. An `IconImageStack` in a CAR reporting Xcode 26 can therefore be classified with high confidence as compiled by the Tahoe-era toolchain.

The material fields reinforce that boundary but cannot classify it independently. In the Default/Light stack records:

- all 19 Xcode 26 stacks used specular placement `0` and zero refraction depth and strength;
- 15 of 24 Xcode 27 stacks used at least one explicit inside or outside specular placement;
- 12 of 24 Xcode 27 stacks used nonzero refractivity; and
- some Xcode 27 stacks used neither newer behavior, so their absence does not prove Tahoe provenance.

Other inspected private fields did not distinguish the generations. Every audited stack returned `sourceObjectVersion == 0`, rendition object version `0`, and no `renderingProperties`; no audited group in either generation returned group-level `hasLightingEffects == true`. These values must not be used as era signals.

A practical confidence rule is therefore:

```text
AssetStorageVersion reports Xcode 26
  -> high-confidence Tahoe-era compiled icon stack, could not have been compiled from the public Golden Gate-era document schema

AssetStorageVersion reports Xcode 27
  -> Golden Gate-era compilation, but not proof that the design uses v2 materials

missing or unrecognized compiler metadata
  -> unknown generation
```

### Tahoe material serialization

The HomeKit Accessory Simulator supplied a focused Tahoe case. Its CAR reports Xcode 26.6 build `17F103` and CoreUI 974. The logical `AppIcon` contains four groups and five source assets. Its Blueprint Grid group returns `hasSpecular == false` in Light, Dark, and Tinted; the other three groups return `hasSpecular == true` with placement `0`. Every group has zero refraction depth and strength.

This case established that a Golden Gate runtime's placement value `0` is not sufficient evidence that a Tahoe document explicitly authored Golden Gate's `"automatic"` specular placement. Recompose must not promote Tahoe `hasSpecular == true`, placement `0` into `"specular": "automatic"`.

Two experimental writers separated omission from an explicit opt-out:

1. The first omitted the root `features` declaration and all group `refractivity` and `specular` properties. The user manually verified that this `.icon` looked like the production application in Icon Composer. Xcode 26.6 nevertheless recompiled the omitted Blueprint Grid specular state as `hasSpecular == true`, proving that omission does not preserve a compiled false value.
2. The corrected writer continued to omit the v2 feature declaration and refractivity. For specular, it emitted Boolean `false` only when CoreUI reported `hasSpecular == false`, while omitting Tahoe's enabled placement `0`. Xcode 26.6 accepted this document and preserved both the Blueprint Grid opt-out and the other groups' legacy enabled state.

The corrected document was compiled with Xcode 26.6 build `17F113` and compared with the supplied build `17F103` CAR. Across Light, Dark, and Tinted:

- canvas, group and leaf counts, ordering, geometry, fills, opacity, blend modes, blur, lighting, shadows, translucency, refractivity, and specular state matched;
- all 15 appearance-specific extracted SVG slots were byte-identical; and
- serialized SVG source lengths differed because the compiler reserialized the vectors, but the extracted artwork content did not differ.

The CAR headers necessarily differed because the source and comparison used different Xcode 26.6 builds: CoreUI 974 versus 975, and platform version 14.0 versus 26.0. Those container-level differences do not represent an icon-stack fidelity difference.

The verified Tahoe material rule is:

```text
omit features["refractivity", "specular-location"]
omit group refractivity

hasSpecular == false
  -> "specular": false

hasSpecular == true and placement == 0
  -> omit specular; do not write "automatic"
```

This rule is verified for Xcode 26.6 compilation and normalized read-back of the HomeKit icon stack. The corrected document still requires direct visual confirmation in Icon Composer; the earlier omission-only document, not the corrected explicit-opt-out variant, received the manual comparison.

## Outstanding items from the recompilation audit

The original recompilation audit compared normalized icon-stack structure and extracted artwork rather than complete CAR bytes. Several findings initially admitted both a Recompose explanation and a compiler-generation explanation.

Finding 5 concerned a zero-opacity Logic Pro SVG layer that disappeared during Xcode 27 compilation. Finding 6 included raster images whose decoded samples changed by at most one 8-bit channel value after recompilation.

Subsequent focused testing distinguished two different situations:

1. Logic Pro exposed both a Recompose schema defect and a separate compiler behavior: removing v2-only material output made the reconstruction valid under Xcode 26.6, while the compiler still omitted its zero-opacity glow layer.
2. Keka exposes a concrete change in CoreUI image encoding between an Xcode 26 source CAR and an Xcode 27 recompiled CAR.

### Logic Pro: Recompose schema correction and compiler leaf omission

The audit's Logic Pro Creator Studio case contains a group with two SVG leaves. One is a plus-lighter glow layer with opacity zero in Light, Dark, and Tinted. Recompose retained the asset, reference, blend mode, and zero opacity in the editable document. Xcode 27 compiled the document but omitted that leaf from all three resulting appearance stacks.

The original source CAR reports Xcode 26.0 build `17A324` and CoreUI 969. The first reconstruction was produced before Recompose distinguished Tahoe and Golden Gate material schemas. It included the v2 `refractivity` and `specular-location` feature declarations and their related output.

That reconstruction produced three observations:

- The reconstructed Logic document opens successfully in the Golden Gate-era Icon Composer.
- Icon Composer 1.5 on Tahoe rejects the same document with “The data isn't in the correct format.”
- Xcode 26.5 also refuses to compile it and produces an underlying nil-array-style failure.

The HomeKit work subsequently identified that Recompose was promoting Tahoe material defaults into v2-only document fields. A corrected experimental Tahoe writer was therefore applied to Logic. It omitted the v2 feature declaration and refractivity, preserved Boolean `specular: false`, and omitted enabled specular placement `0` rather than writing `"automatic"`.

Xcode 26.6 build `17F113` successfully compiled the corrected Logic document. This establishes that the earlier v1 rejection was caused by Recompose's v2-only output rather than an incompatibility in Logic's original Tahoe icon. The test also confirms that the v1 document accepts Logic's shadow, translucency, blur-material, lighting, appearance specializations, and zero-opacity plus-lighter source layer.

Normalized read-back produced one structural difference: Xcode 26.6 omitted the zero-opacity plus-lighter glow leaf in Light, Dark, and Tinted. Every surviving stack, group, leaf, material, geometry, and fill field matched, and all 12 surviving appearance-specific artwork slots extracted byte-identically.

The missing glow is therefore separate from the corrected Recompose schema defect. The original Xcode 26.0 CAR retains the leaf, while Xcode 26.6 and the previously tested Xcode 27 beta omit it. The current evidence is consistent with dead-layer elimination introduced during the Xcode 26 release cycle, although a different Apple-internal compilation path for the original remains possible. Testing with the original Xcode 26.0 build would be required to locate that boundary more precisely.

### Keka: `zip` to `deepmap2`

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

Recompose needs separate Tahoe and Golden Gate material writers. For a high-confidence Xcode 26 source, the Tahoe writer must preserve explicit specular opt-outs without promoting legacy enabled placement `0` into Golden Gate `"automatic"`, and it must omit the v2 feature declaration and refractivity. Golden Gate output should retain the current v2 mappings.

This schema decision remains separate from rendition encoding. The Keka portion of Finding 6 requires no compensating Recompose code change: the source pixels and available color metadata were preserved in the editable document, and the observed change was introduced deterministically by Xcode 27's `deepmap2` encoding path.

The schema-rejection portion of Finding 5 is resolved as a Recompose defect. Its remaining question is limited to why the original Xcode 26.0 compiler path retained Logic Pro's zero-opacity glow while Xcode 26.6 and Xcode 27 omitted it.

## Open items

All Tahoe-specific compatibility work is maintained here rather than split into separate backlog tickets.

### Editable document compatibility

- Verify the corrected HomeKit explicit-opt-out document visually in Icon Composer, including its 26 and 27 previews.
- Test the corrected `"specular": false` form in Icon Composer 1.5 and 1.6; Xcode 26.6 compilation and read-back are already verified.
- Test the v2 feature tokens independently and determine whether each declares behavior, gates parsing, or both.
- Extend the accepted v1 property matrix beyond the HomeKit combination and record differences among Icon Composer 1.5, Icon Composer 1.6, Xcode 26.5, and Xcode 26.6.

### Compiled catalog behavior

- Test the corrected Logic document with Xcode 26.0 build `17A324`, if that toolchain becomes available, to determine when zero-opacity leaf omission began.
- Compare how Xcode 26 and Xcode 27 choose among `zip`, `deepmap2`, monochrome, and other observed rendition encodings for the same source PNG.
- Separate differences that affect rendered output from decoded-sample, encoded-byte, and structural differences.
- Verify which differences stabilize within one compiler generation and which recur on every round trip.

### Recompose runtime compatibility

- Run discovery, extraction, assembly, document acceptance, compilation, and compiled read-back on Tahoe with a focused representative set.
- Enumerate only the private CoreUI classes, selectors, signatures, and defaults that Recompose uses, and compare their availability and behavior between Tahoe and Golden Gate.
- Define explicit failure behavior for a missing or changed private runtime surface rather than silently changing reconstruction output.

### Output policy

- Capture the CAR compiler generation during discovery or extraction and carry it into assembly.
- Implement Tahoe-compatible and Golden Gate-compatible material writers using the verified Xcode 26 rule above.
- Define conservative behavior and UI copy when compiler metadata is missing or unrecognized.
- Preserve newer fidelity features when targeting Golden Gate without emitting documents that Tahoe cannot open when Tahoe output is requested.
- Record exact Icon Composer, Xcode, macOS, CoreUI, and document generations for every compatibility conclusion.
- Keep parser acceptance, compiled representation, and Finder/system rendering as separate evidence boundaries.
