# Recompilation Audit Solutions

> This follow-up was conducted by Codex beginning September 7, 2026 after the icon-stack recompilation audit. It records the investigation, implementation, and validation work undertaken for each of the audit's six findings. The original audit remains a locked point-in-time record; corrected interpretations belong here.

## Purpose

The recompilation audit identified six recurring or consequential differences between source `IconImageStack` records and stacks rebuilt from Recompose output. Four findings resulted in code corrections. Two remain open because they cross the Xcode 26/Tahoe and Xcode 27/Golden Gate toolchain boundary.

## Finding 1: Tinted specialization inheritance

The audit showed that omitted Tinted specializations inherit from the Default/Light value, not the effective Dark value. Recompose had compared Tinted with Dark and omitted an explicit Tinted entry whenever those values matched. The compiler then inherited Light, changing artwork, opacity, blend modes, fills, shadows, lighting, and specular behavior.

Commit `1f7a101` changed the shared specialization writer to compare Tinted with Default/Light. An explicit Tinted specialization is now emitted whenever the source Tinted value differs from Light, even if it equals Dark. Because image names and rendering properties share this writer, the correction applies consistently across both artwork and effects.

Manual checks of representative reconstructed documents succeeded. A subsequent recompilation audit found no remaining specialization, effect, opacity, or blend-mode mismatches attributable to this inheritance rule.

## Finding 2: automatic gradients

The audit described compiled gradients containing one color and one stop. Recompose initially treated them as solids. Follow-up testing then took a wrong turn: literal one-element `linear-gradient` arrays were rejected by Icon Composer and Xcode, while two identical linear-gradient endpoints were accepted. This led to the erroneous conclusion that the compiled records were remnants of an internal or prototype pipeline and should be approximated with duplicate stops.

The missing distinction was the CoreUI gradient type. Every affected record used type `0`; ordinary linear gradients used type `1`. The public `.icon` format already represented type `0` as `automatic-gradient`, whose authored value contains one user-selected color. Compiling that form reproduces a one-color, one-stop CoreUI gradient. The failed literal-array probes tested invalid linear-gradient syntax, not the correct inverse representation.

Commit `4f48610` replaced the color-count heuristic with an explicit semantic mapping:

- CoreUI type `0` with one color becomes `.icon` `automatic-gradient`.
- CoreUI type `1` with two colors becomes `.icon` `linear-gradient` with its orientation.
- Missing, malformed, and unknown gradient types fail explicitly.

A focused round trip of the 20 affected stacks produced 19 exact structural matches. Screen Sharing retained the correct automatic-gradient type, color, stop, and start point, but two layers recompiled with the default endpoint instead of their unusual source endpoint. That narrow exception remains an open representation question; it does not invalidate the automatic-gradient mapping.

The standalone one-stop-gradient study was removed because its organizing premise and conclusion were incorrect. The valid historical lesson is retained here: successful parsing or visual similarity is not sufficient when a semantic CoreUI discriminator is available.

## Finding 3: effects and material values

Finding 3 was not a separate family of effect-mapping failures. Every effect difference reported by the audit occurred in Tinted and passed through the same specialization writer implicated by Finding 1. When the source Tinted value matched Dark, Recompose omitted it and the compiler inherited Light.

The `1f7a101` inheritance correction therefore addressed Findings 1 and 3 together. Post-fix recompilation found no remaining effect mismatches from the original set, confirming that separate property-specific patches were unnecessary.

## Finding 4: geometry quantization

Recompose reconstructs an editable Icon Composer `.icon` document from a compiled `IconImageStack`. The compiled stack exposes each layer as an integer frame, while the editable document represents geometry as a uniform scale and a two-dimensional translation. Reconstructing the editable values therefore requires an inverse transformation.

The audit found five stacks whose reconstructed documents compiled with one-point frame differences. The following study traces the investigation from that initial observation through manual Icon Composer experiments, controlled compiler probes, and the forward and inverse model implemented in commit `4091ccd`.

### Test context

The original audit was conducted against Recompose commit `defc255016e0d8f111b402784a4aaf16eabc7eb1`. The focused geometry investigation used commit `1f7a101e3e6e95e292980587e7b295faac30c0e3`; the intervening change affected appearance specialization rather than geometry.

All reconstructed and controlled probe documents were compiled with Xcode 27.0 beta build `27A5252f` on macOS 27.0 build `26A5425a`. Four of the five source application catalogs reported Xcode 27.0 build `27A200c`. Spotify's source catalog reported Xcode 26.0 build `17A5295f`, so its audit comparison also crossed a compiler-generation boundary. The controlled probe itself was authored and compiled with the Xcode 27-era tools and does not depend on Spotify's source compiler.

### Initial audit finding

The audit reconstructed each source stack, compiled the resulting `.icon` in a fresh copy of the CompilerTest app, extracted the newly compiled `AppIcon`, and compared its normalized CoreUI fields with the source. Five stacks showed geometry differences:

| App | Source frame | Recompiled frame | Difference |
|---|---:|---:|---|
| Spotify | `100,100,822×822` | `99,99,822×822` | x and y decreased by 1 |
| Image Capture | `121,219,780×585` | `121,218,780×586` | y decreased by 1; height increased by 1 |
| Activity Monitor | `-216,-496,2229×2228` | `-216,-497,2229×2229` | y decreased by 1; height increased by 1 |
| Screenshot | `99,70,827×827` | `98,69,827×827` | x and y decreased by 1 |
| System Information | `436,294,151×50` | `436,293,151×50` | y decreased by 1 |

Each difference occurred identically in Light, Dark, and Tinted, producing 18 differing appearance-layer slots in total. The repeated negative-one direction suggested a systematic asymmetry rather than random floating-point noise.

At the time of the audit, Recompose recovered geometry as follows:

```text
widthScale  = frameWidth / intrinsicWidth
heightScale = frameHeight / intrinsicHeight
scale       = whichever candidate best predicts the other dimension

translationX = frameX + frameWidth/2 − 512
translationY = frameY + frameHeight/2 − 512
```

This treats the integer CoreUI frame as though it were the exact continuous frame that existed before compilation.

### First manual observation and hypothesis

Manual human experimentation in Icon Composer initially suggested that its Layout controls retained only two decimal places. Entering a y translation of `-0.555` appeared as `-0.56` when the field was not active, and scale similarly appeared rounded in the inspector.

That observation led to an initial hypothesis: Recompose was writing more precision than Icon Composer's authoring model supported, and Icon Composer or its compiler was quantizing those values before generating the CAR. Under that hypothesis, Recompose would need to round position to hundredths of a point and scale to the apparent precision of the percentage field.

The proposed validation was to compare a reconstructed `icon.json` before and after opening and resaving it in Icon Composer, then compile both versions. This would distinguish display formatting from document serialization.

### Reserialization rejected the precision hypothesis

Manual user verification showed that Icon Composer's inactive fields only format their values for display. Selecting the position field revealed the original `-0.555`, and selecting the scale field revealed the full value represented by `0.76171875` in `icon.json`.

The document was then reserialized through Icon Composer. Both values remained unchanged:

```json
{
  "scale": 0.76171875,
  "translation-in-points": [-1, -0.555]
}
```

This ruled out an editor precision limit. Recompose should not round its geometry merely to match the inspector's inactive presentation.

It also redirected the investigation toward the loss inherent in converting continuous editable geometry into an integer compiled frame.

### Algebraic analysis of the five failures

The five source frames were compared with their intrinsic image sizes and the exact values emitted by Recompose:

| App | Source frame | Intrinsic size | Emitted scale | Emitted translation |
|---|---:|---:|---:|---:|
| Spotify | `100,100,822×822` | `674×674` | `1.2195845697329377` | `-1,-1` |
| Image Capture | `121,219,780×585` | `1024×769` | `0.76171875` | `-1,-0.5` |
| Activity Monitor | `-216,-496,2229×2228` | `1024×1024` | `2.1767578125` | `386.5,106` |
| Screenshot | `99,70,827×827` | `1088×1088` | `0.7601102941176471` | `0.5,-28.5` |
| System Information | `436,294,151×50` | `631×209` | `0.2393026941362916` | `-0.5,-193` |

Adding `0.5` to each emitted translation corrected every differing origin without introducing a new frame difference in the other appearance-layer slots from these five stacks. This produced an interim `511.5`-center hypothesis because the modified expression could be written as:

```text
translation = frameOrigin + frameSize/2 − 511.5
```

That expression worked empirically, but interpreting it as Apple's intentional canvas center was not well founded. A 1024-point canvas has a geometric center at 512. A pixel-index convention can describe 1,024 sample centers as `0…1023`, with a midpoint of `511.5`, but applying the same convention consistently to both the layer and canvas cancels the half-point:

```text
layer sample center − canvas sample center
= frameOrigin + (frameSize − 1)/2 − 511.5
= frameOrigin + frameSize/2 − 512
```

The successful half-point adjustment therefore required a different explanation.

### Controlled Icon Composer probe

A human-authored Icon Composer document was created to reveal the compiler's forward transformation directly. It contained one group with six plainly named layers:

| Layer | Source image | Position | Scale |
|---|---:|---:|---:|
| `even-zero` | `100×100` PNG | `0,0` | `1` |
| `even-plus-half` | `100×100` PNG | `0.5,0.5` | `1` |
| `even-minus-half` | `100×100` PNG | `-0.5,-0.5` | `1` |
| `odd-zero` | `101×101` PNG | `0,0` | `1` |
| `nonsquare-zero` | `100×101` PNG | `0,0` | `1` |
| `fractional-size` | `100×100` PNG | `0,0` | `1.005` |

When `100.5%` was entered for `fractional-size`, Icon Composer briefly presented a long floating-point value in the active control. Its saved `icon.json` nevertheless contained the exact value `1.005`, confirming that the UI artifact did not affect the serialized probe.

#### Test procedure

The six layers were created in Icon Composer using PNGs with the stated pixel dimensions. After the document was saved, its `icon.json` and packaged assets were inspected to confirm that the serialized inputs matched the intended test matrix.

The CompilerTest app was copied to a fresh task directory, and its `AppIcon.icon` was replaced with the probe document. The app was then compiled in a clean Xcode build using a new Derived Data directory so no previously compiled icon could be reused. The resulting `Assets.car` was validated with `assetutil -Z`, and its `AppIcon` stack was extracted with Recompose.

The resulting Light stack's group layers were read from the extraction manifest and matched to the authored probe layers. CoreUI returned the authored layer order in reverse.

The relevant build and extraction operations are equivalent to:

```sh
xcodebuild -project IconCompilerTestApp.xcodeproj \
  -scheme IconCompilerTestApp \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath /path/to/fresh-derived-data \
  clean build

assetutil -Z /path/to/compiled/Assets.car
recompose extract /path/to/compiled/Assets.car --asset AppIcon --output /path/to/extraction
```

#### Probe results

| Authored layer | Extracted CoreUI frame |
|---|---:|
| `even-zero` | `462,462,100×100` |
| `even-plus-half` | `462,462,100×100` |
| `even-minus-half` | `461,461,100×100` |
| `odd-zero` | `461,461,101×101` |
| `nonsquare-zero` | `462,461,100×101` |
| `fractional-size` | `461,461,100×100` |

The `fractional-size` result was especially informative. Its continuous scaled size is `100.5×100.5`. The compiler reported a size of `100×100`, but its origin was 461 rather than the 462 that would result if the compiler centered the rounded 100-pixel size. The origin must therefore be calculated from the continuous 100.5-pixel size before the size is rounded.

A derived copy changed only `fractional-size` from `1.005` to `1.015`, producing a continuous size of `101.5×101.5`. Xcode reported `102×102`. Together, `100.5→100` and `101.5→102` establish round-to-nearest with ties-to-even for compiled frame dimensions.

### Derived forward model

For an intrinsic dimension `I`, authored scale `s`, authored translation `t`, and a 1024-point canvas, the tested compiler behaves as follows:

```text
continuousSize = I × s

frameSize = roundToNearestEven(continuousSize)

continuousOrigin = 512 + t − continuousSize/2

frameOrigin = floor(continuousOrigin)
```

Applied independently to both axes:

```text
scaledWidth  = intrinsicWidth × scale
scaledHeight = intrinsicHeight × scale

frameWidth  = roundToNearestEven(scaledWidth)
frameHeight = roundToNearestEven(scaledHeight)

frameX = floor(512 + translationX − scaledWidth/2)
frameY = floor(512 + translationY − scaledHeight/2)
```

This model accounts for every controlled probe result. It also explains the audit's repeated negative-one bias: the integer frame does not retain the original continuous origin, but Recompose treated the lower integer boundary as exact when reconstructing a translation.

### A principled inverse

The inverse cannot recover the originally authored values uniquely. It can recover values guaranteed to compile into the observed integer frame when that frame is representable.

#### Recovering scale

For a compiled width `W` and intrinsic width `Iw`, all scales whose continuous width rounds to `W` lie approximately within:

```text
(W − 0.5) / Iw ≤ scale ≤ (W + 0.5) / Iw
```

Height supplies an equivalent interval:

```text
(H − 0.5) / Ih ≤ scale ≤ (H + 0.5) / Ih
```

Exact endpoint inclusion depends on ties-to-even and the parity of the target integer. An implementation can avoid that complication by selecting a value strictly inside the overlap rather than selecting a boundary.

When the width and height intervals overlap, the midpoint of their intersection is a stable canonical scale. It maximizes the distance from either rounding boundary and guarantees that both dimensions recompile to their source integers under the observed rule.

An interim least-squares scale was tested while deriving this model. It corrected Image Capture and preserved System Information because it happened to fall inside their valid interval intersections. The interval midpoint is the stronger final formulation because it is derived directly from the compiler's quantizer and provides an explicit recompilation guarantee.

#### Recovering translation

Given a selected scale, a compiled x origin means:

```text
x ≤ 512 + translationX − scaledWidth/2 < x + 1
```

Therefore the set of translations capable of producing `x` is:

```text
x − 512 + scaledWidth/2
    ≤ translationX <
x + 1 − 512 + scaledWidth/2
```

The midpoint is the unbiased canonical inverse:

```text
translationX = x + 0.5 + scaledWidth/2 − 512
translationY = y + 0.5 + scaledHeight/2 − 512
```

This is the sound basis for the observed half-point correction. It chooses the center of the continuous-origin interval discarded by `floor`; it does not redefine the canvas center as `511.5`.

Default or otherwise unpositioned layers require separate handling. Several authored values can compile to the same integer frame: the probe's `even-zero` and `even-plus-half` layers are one example. When an extracted frame is consistent with Icon Composer's omitted default position, Recompose should continue omitting `position` rather than inventing an explicit half-point translation.

### Validation against the audit cases

The half-point translation experiment corrected every source-frame origin in the five audited stacks and introduced no new frame differences in the remaining tested slots. Replacing the current single-axis scale choice with a scale inside the valid width/height intersection also corrected Image Capture and System Information.

The resulting interpretation is:

| App | Cause | Representable result |
|---|---|---|
| Spotify | Lost fractional-origin interval | Exact with midpoint translation |
| Image Capture | Lost origin interval plus scale inferred from only one dimension | Exact with interval-derived scale and midpoint translation |
| Activity Monitor | Width and height require incompatible uniform scales | No exact scalar solution in the tested format |
| Screenshot | Lost fractional-origin interval | Exact with midpoint translation |
| System Information | Lost fractional-origin interval; both dimensions constrain scale | Exact with interval-derived scale and midpoint translation |

Across these five stacks, the derived model reduces the original 18 differing appearance-layer slots to the three appearances of Activity Monitor's single glow layer.

### Activity Monitor's irreducible frame

Activity Monitor's glow is a square `1024×1024` PNG whose source CoreUI frame is `2229×2228`. Icon Composer exposes one uniform scalar scale, so the two axes must have the same continuous scaled size.

For the width to round to 2229, the scale must place the continuous size on the 2229 side of `2228.5`. For the height to round to 2228, it must place that same continuous size on the 2228 side. At exactly `2228.5`, ties-to-even produces 2228 for both axes.

Consequently:

```text
2228.5 → 2228×2228
slightly above 2228.5 → 2229×2229
```

No uniform scalar can produce `2229×2228` from a square intrinsic image under the observed compiler rule. The asymmetry may reflect compiled information that the editable `.icon` model does not expose, a CoreUI frame artifact, or a difference between compiler builds. It should not be treated as an ordinary rounding bug that Recompose can solve by selecting a different scalar.

### Conclusions

1. Icon Composer retains substantially more geometry precision than its inactive inspector display suggests.
2. Xcode calculates frame origins from continuous scaled dimensions and floors them.
3. Xcode rounds compiled frame dimensions to the nearest integer, using ties-to-even in the tested cases.
4. A compiled integer frame represents a range of possible authored scales and translations, not one exact source value.
5. Recompose should invert the observed quantizers by selecting interior midpoint values, while preserving omitted default positions when applicable.
6. Four of the five audited geometry differences are exactly representable under this model.
7. Activity Monitor's non-square frame around a square source image is not exactly representable with Icon Composer's observed uniform-scale field.

The Activity Monitor result is accepted as a known public-format limitation. Recompose will preserve the closest representable uniform-scale frame; no corrective work is tracked unless a current editable representation for the asymmetric frame is discovered.

## Finding 5: omitted zero-opacity layer

Logic Pro Creator Studio's source stack contains a zero-opacity, plus-lighter SVG glow layer. Recompose preserves the layer, asset reference, opacity, and blend mode in the editable document, but Xcode 27 omits it from the recompiled stack. The source CAR was produced by Xcode 26.

The reconstructed v27 document opens under the Golden Gate tools but is rejected by the tested Tahoe-era Icon Composer and Xcode versions before a comparable v26 CAR can be produced. A later generation-specific probe produced accepted v26 documents and showed that Xcode 26.5 and 26.6 both omit the same zero-opacity leaf. The optimization therefore predates v27 and is not evidence of a v26/v27 rendering-model difference. No corrective code has been applied.

## Finding 6: artwork rewriting

The audit grouped three distinct artwork differences. ChatGPT.app's changed Tinted artwork was resolved by Finding 1. Typora's SVG lost an empty `<defs/>` element during compilation, a rendering-neutral compiler canonicalization. The remaining cases are raster assets whose decoded color samples changed by at most one 8-bit channel value.

Keka first showed that an early Xcode 26 `zip` rendition became an Xcode 27 `deepmap2` rendition, after which a second Xcode 27 round trip was stable and byte-identical to the first. A later probe showed the same conversion under both Xcode 26.5 and 26.6, placing the behavior within v26 rather than at the v26/v27 boundary. That evidence supports deterministic compiler canonicalization rather than repeated loss in Recompose, but it does not establish a universal explanation for every affected raster.

No compensating code has been applied. Rendering fidelity, rather than reproducing compiler-private rendition encodings, remains the acceptance boundary for the unresolved raster cases.
