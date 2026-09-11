# Icon stack specs and extraction procedure

>  This document outlines observed specifications of the Liquid Glass icon stack system bundled into macOS asset catalogs (`Assets.car`) and documents processes for its reconstruction as an Icon Composer document. It describes behavior of the current v27 toolchain; where applicable, differences observed between the v26 Tahoe toolchain and v27 Golden Gate toolchain are denoted with compatibility notes.

## Background

To support the new Liquid Glass rendering system, macOS Tahoe 26 introduced a new format for packaging app icons into an application bundle referred to here as an **icon stack**. The term "icon stack" refers to a double-ended system where a layered `.icon` file is created by a developer or designer using Icon Composer, and then compiled into an `IconImageStack` by Xcode and placed within the app's asset catalog (`Assets.car`). `IconImageStack` is the logical compiled asset type name of the icon stack observed in catalog metadata; the corresponding private runtime class has been observed as `CUINamedIconLayerStack`.

The "stack" or "layered" structure of the asset is key, because it enables the system to render the icon in a multitude of **appearances**. An appearance is a visual rendering mode with potentially different artwork or material property values. There are three appearance modes: Icon Composer refers to them as `Default`, `Dark`, and `Mono`, and CoreUI resolves them to corresponding `Light`, `Dark`, and `Tintable` representations, respectively.

By combining appearance with other inputs, such as scale and localization details, macOS can resolve several technical records, or **renditions**, from a single icon stack asset. For example, to display an app in the `/Applications` folder, Finder may send a request to CoreUI for a rendition of an icon stack named `AppIcon` that looks like this:

```
Give me AppIcon
for the Dark appearance,
at scale 1,
for this gamut,
locale,
and layout direction.
```

Apple currently does not officially support decompiling an `IconImageStack` out of a compiled asset catalog, meaning a human-readable format of the icon stack cannot be officially derived from an app's bundled asset catalog.

This is the purpose of the Recompose project; to identify the manifest and assets of a compiled `IconImageStack` and map that information back to the Icon Composer `.icon` document specification so that the icon stack may become human-readable again.

The scope of this document includes:

- logical icon stack discovery;
- CoreUI lookup conditions, meaning the selectors used to resolve a rendition;
- resolved background, group, and leaf records;
- mapping resolved records to `.icon` fields;
- extraction and reconstruction invariants;
- current preservation limits;
- regression procedure.

This document does not cover:

- the general CAR container;
- unrelated asset types;
- raw BOMStore/CoreTheme Structured Image (CSI) layout

The observed format of the `.icon` document can be found in `icon-composer-document-specs.md`

## Pipeline definitions

In this document, the below terminology is used:

- **Reconstruction pipeline** — the end-to-end conversion process from the compiled catalog to an editable `.icon` document: discover the logical asset, extract its resolved artwork and properties, align its appearance variants, and assemble the authored hierarchy
- **Reconstruct** — the verb for running the complete pipeline
- **Extractor** — extracts layers and annotations from the CAR and produces a manifest plus source assets
- **Assembler** — assembles the extracted data into an editable `.icon`
- **Assembly stage** — preferable to “assembler” when discussing the process rather than the component
- **Recomposed icon** — the final output, a finished `.icon` presented by Recompose once the pipeline has been run

High-level system architecture:

```

                  ┌       CAR file               ← Recompose's input, compiled by Xcode
                  │        ↓
                  │       discovery
 reconstruction   │        ↓
 pipeline         │       extraction             ← using Recompose's extractor
                  │        ↓
                  │       assembly               ← using Recompose's assembler
                  │        ↓
                  └       recomposed icon        ← Recompose's output

```

## Model

Each **group** is an ordered collection that receives shared composition and rendering properties. A **leaf** or **leaf slot** is one artwork position inside a group; the corresponding slot can resolve to different source files, properties, or media types in different appearances.

```text
logical named asset
└── IconImageStack
    ├── Default/Light representation
    │   ├── background
    │   └── groups[]
    │       └── leaves[]
    ├── Dark representation
    └── Tintable/Mono representation
```

The logical asset is the selection unit. Renditions are implementation records beneath it.

## Discovery

`AppIcon` is the default name provided by Xcode; it is conventional, not required. An asset catalog can contain zero, one, or several arbitrarily named icon stacks.

A named lookup is a CoreUI object exposed while catalog resources are enumerated. It supplies useful candidates, but enumeration alone does not reliably classify every icon stack.

Validated discovery sequence:

1. Recompose opens the CAR with `CUICatalog`.
2. It enumerates named lookups.
3. Names are collected from multisize-image and directly visible icon-layer-stack lookups.
4. Both `name` and `renditionName` are collected when present.
5. A terminal `.iconstack` suffix is removed from candidate names.
6. `iconLayerStack` resolution is attempted for every candidate under the recognized appearance aliases.
7. Only names that resolve as an icon stack are retained.
8. All suffixless logical names are presented without inferring a primary stack.

Direct class filtering is incomplete. Calendar, Font Book, and Stocks did not enumerate as direct icon-stack objects in the audit. Treating every multisize lookup as an icon stack creates false positives. Type-specific resolution is the decisive test.

### Discovery outcomes

| State | Meaning |
|---|---|
| Cannot open CAR | Input, catalog, runtime, or environment failure. |
| No icon stack | Valid CAR with no logical `IconImageStack`. |
| One icon stack | The discovered logical name can be reconstructed directly. |
| Multiple icon stacks | A selection is required. |

“No icon stack present” is not equivalent to “cannot process CAR,” therefore they require different UI presentations in Recompose.

## Lookup tuple

The lookup tuple selects by appearance, scale, device idiom, subtype, display gamut, locale, and layout direction. The resulting resolved representation contains the effective stack values for that particular set of conditions.

The observed stack lookup accepts:

```text
(name, scale, idiom, subtype, gamut, appearance, locale)
```

Current extraction requests:

| Condition | Value |
|---|---|
| scale | `1.0` |
| idiom | `0` |
| subtype | `0` |
| gamut | `0` |
| locale | `nil` |
| appearance | one alias at a time |

Display gamut is the color range requested during lookup. Selecting gamut `0` can choose an ordinary rendition even when a Display P3 or higher-bit-depth alternative is available.

The three authored appearances resolve under the following catalog aliases:

| Manifest role | Catalog aliases |
|---|---|
| `UIAppearanceLight` | `UIAppearanceLight`, `NSAppearanceNameAqua` |
| `UIAppearanceDark` | `UIAppearanceDark`, `NSAppearanceNameDarkAqua` |
| `ISAppearanceTintable` | `ISAppearanceTintable` |

The manifest records the alias that resolved. Alias differences are not exposed as different authored appearances.

## Runtime preview rendering

Recompose's interface previews the original compiled icon stack rather than the reconstructed `.icon` document. On the tested macOS 27 runtime, it resolves the named stack from the source CAR and invokes IconFoundation's private stack renderer at 256 points and scale 2. The returned 512-pixel image retains transparency and is displayed at 256 points.

The renderer inputs observed for the three controls are:

| Interface appearance | Resolved stack representation | Renderer appearance | Renderer variant |
|---|---|---:|---:|
| Default | Light | `0` | `0` |
| Dark | Dark, falling back to Light | `1` | `0` |
| Tinted | Tintable, falling back to Light | `0` | `2` |

These numeric values and the `_IF_ImageWithSize:scale:platform:appearance:appearanceVariant:tintColor:encapsulationShape:` selector are private runtime observations, not public API contracts. Preview failure does not change the reconstruction result; the interface can present the successful `.icon` without an image for an appearance that could not be rendered.

This path is distinct from Quick Look, Finder thumbnails, and flattened companion renditions. Those presentation artifacts can be delayed, absent, or rendered under a different design generation, so Recompose does not use them as evidence of reconstruction fidelity.

## Extraction manifest

Recompose separates CoreUI extraction from `.icon` assembly. The intermediate manifest is a project-owned JSON representation, not an Apple format. It preserves resolved CoreUI observations for the later assembly stage.

```text
manifest
├── formatVersion: 1
├── source
│   ├── catalog
│   ├── assetName
│   └── extractor
└── appearances
    ├── UIAppearanceLight
    ├── UIAppearanceDark
    └── ISAppearanceTintable
```

Each appearance contains the resolved stack record and its background/group/leaf tree. Extracted SVG and PNG files live in the adjacent `Assets/` directory. The manifest retains private runtime identity, selection conditions, rendition metadata, and otherwise unmapped values.

## Stack record

Observed runtime class: `CUINamedIconLayerStack`.

| Value | Use |
|---|---|
| `name` | logical asset identity |
| `renditionName` | diagnostic rendition identity; may end in `.iconstack` |
| `appearance` | resolved catalog appearance |
| `appearanceIdentifier` | diagnostic numeric appearance |
| `scale` | lookup result |
| `idiom` | lookup result |
| `displayGamut` | lookup result |
| `size` | canvas size |
| `sourceObjectVersion` | diagnostic stack object version; not a format-generation discriminator |
| `renderingProperties` | diagnostic metadata |
| `layers` | background followed by groups, in CoreUI's back-to-front compiled order |
| `dataRepresentation` | opaque diagnostic representation |

An audit was conducted on a corpus of compiled `Assets.car` files to understand how `IconImageStack` assets can appear within them. The audit identified 38 icon stacks across 36 human-selected CARs.

| Observation | Result |
|---|---:|
| CARs containing a stack | 31 of 36 |
| Logical stacks | 38 |
| Stacks named `AppIcon` | 20 |
| CARs with multiple stacks | 4 |
| CARs with no stack | 5 |
| Canvas | 1024 × 1024 for all 38 |
| Scale | 1 for all 38 |
| Storage version | 17 for all 38 |
| Appearance representations | 3 for all 38 |

The detailed corpus can be found in the CAR audit document.

### Compiler-generation provenance

The CAR-level `AssetStorageVersion` identifies the compiler generation observed in the audited catalogs: values naming Xcode 26 indicate v26 compiler provenance, while values naming Xcode 27 indicate v27 compiler provenance. This is evidence of which toolchain wrote the catalog, not proof that an individual stack uses properties unique to that generation. A missing or unrecognized value leaves the generation unknown.

`sourceObjectVersion` does not distinguish v26 from v27 in the current corpus. Recompose records it diagnostically without using it to select the document writer.

### Minimum required specification

Reconstruction targets the earliest document specification capable of representing every observed compiled behavior. Recompose treats each behavior as a capability with a minimum specification version, evaluates all capabilities present in the resolved stack, and selects the highest minimum version among them.

| Observed compiled capability | Minimum specification |
|---|---:|
| Properties and values representable by the baseline material model | v26 |
| Nonzero `refractionHeight` or `refractionStrength` | v27 |
| Enabled `specularPlacement` value `1` (`inside`) or `2` (`outside`) | v27 |

These are two distinct specular states. When CoreUI reports `hasSpecular` as true with `specularPlacement` set to `0`, the v26 writer omits `specular`, and the v26 toolchain interprets that omission as its enabled default. When CoreUI reports `hasSpecular` as false, the v26 writer emits Boolean `false`.

Xcode resolves omitted v26 properties and their default-valued v27 equivalents into the same CoreUI state, making otherwise equivalent v26 and v27 documents indistinguishable after compilation. Compiler provenance therefore remains separate from capability classification and does not raise the selected output version. If the resolved stack uses only baseline capabilities, Recompose reconstructs it as v26 even when its containing CAR was compiled by Xcode 27.

The capability table will be extended when a later specification introduces new behavior. The selected version is always the maximum of the minimum versions required by the observed capabilities, rather than the result of a chain of compiler-version assumptions. An unknown property or value that may require a newer specification causes reconstruction to fail visibly instead of being discarded or written into an older document.

## Compiled order

Compiled order is the back-to-front order in which CoreUI returns resolved groups and leaves. It is the inverse of authored `icon.json` order at both hierarchy levels.

```text
CoreUI stack: [background, back group, ..., front group]
icon.json:    [front group, ..., back group]

CoreUI group: [back leaf, ..., front leaf]
icon.json:    [front leaf, ..., back leaf]
```

Reconstruction removes child zero and reverses the remaining groups. It also reverses every group's leaves.

## Background record

The background record is child zero of the compiled stack. It carries the root fill rather than leaf artwork, is not an authored group, and can retain a semantic preset name.

Known preset names:

- `system-light`
- `system-dark`

The name is rendering data. Recompose preserves these presets rather than reducing them to their resolved color components.

Validated `system-dark` result:

- Image Capture resolved the same named `system-dark` record for Default, Dark, and Tintable.
- Reconstructing its gamma-2.2 gray stops as a literal gray gradient rendered too light.
- Reconstructing `automatic-gradient` from black rendered too dark.
- Reconstructing equal-channel Display P3/sRGB stops matched an Icon Composer preview and flattened companion closely but remained too light after compilation. A flattened companion is a pre-rendered icon resource stored elsewhere in the same CAR rather than part of the editable layer hierarchy.
- The RGB reconstruction compiled as a generated `Gradient-1`; the source retained the named `system-dark` record.
- Emitting the string value `"system-dark"` preserved the semantic record.
- The rebuilt icon matched Image Capture in a Finder-to-Finder comparison.

Finder performs presentation rendering: final rendering by a system consumer rather than the authoring preview. This is the comparison boundary for claims about the icon's system appearance.

Root appearance handling is not ordinary value deduplication:

```text
fill-specializations = [
    { value: Default },
    { appearance: dark, value: Dark },
    Tinted != Dark ? { appearance: tinted, value: Tinted } : omitted
]
```

Recompose always retains the explicit Dark root specialization, even when its resolved value equals Default. Omitting Dark asks Icon Composer to supply its automatic system Dark background. Tintable can inherit Dark when equal.

## Group record

Observed runtime class: `CUINamedIconLayerGroup`.

Material annotations control system rendering rather than source pixels. The group properties below cover glass participation, refraction, specular placement, blur, translucency, lighting, and shadow.

| CoreUI property | Type | `.icon` mapping |
|---|---|---|
| `layers` | array | reverse into group `layers` |
| `blendMode` | integer | `blend-mode` |
| `blurStrength` | number | `blur-material`; omit zero |
| `gathersSpecularByElement` | Boolean | `lighting`: `individual` if true, `combined` if false |
| `hasSpecular` | Boolean | `specular`: `false` if false |
| `opacity` | number | `opacity` |
| `refractionHeight` | number | `refractivity.depth` |
| `refractionStrength` | number | `refractivity.strength` |
| `shadowOpacity` | number | `shadow.opacity` |
| `shadowStyle` | integer | `shadow.kind` |
| `specularPlacement` | integer | enabled `specular` placement |
| `translucency` | number | `translucency.value` |
| color / gradient / fill name | fill diagnostics | no group fill observed in the corpus |
| `hasLightingEffects` | Boolean | retained in the manifest |

Observed values include:

- one through four groups;
- non-normal group blend modes on 18 of 38 stacks;
- appearance-specific group blend modes on 13 of 38 stacks;
- blur strength `0.1...1` when nonzero;
- negative refraction strength;
- shadow opacity through `2.2`;
- group opacity `0`;
- translucency `0...0.9`;
- inside and outside specular placement.

Recompose preserves material numbers without clamping them to UI-looking ranges.

### Specular mapping

```text
hasSpecular == false -> false
hasSpecular == true, placement 0 -> "automatic"
hasSpecular == true, placement 1 -> "inside"
hasSpecular == true, placement 2 -> "outside"
```

Boolean `false` is required for the disabled state. The string `"none"` was accepted structurally but produced unwanted highlights and dark outlines. Manual comparison confirmed that `false` removed the defect.

> **v26 compatibility:** A disabled specular effect is represented explicitly as Boolean `false`. A different state, enabled specular with placement `0`, is represented by omitting `specular` so the v26 toolchain supplies its enabled default behavior. The `automatic`, `inside`, and `outside` values require v27; enabled nonzero placements therefore cannot be represented by a v26 reconstruction.

### Refractivity mapping

The `refractionHeight` and `refractionStrength` mappings above require v27 and the document's root `refractivity` feature declaration.

> **v26 compatibility:** v26 documents omit refractivity. All groups in the audited v26 probe inputs resolved with zero refraction values, so omission preserves the observed source semantics. A nonzero v26 refraction value would be unsupported evidence and would cause reconstruction to fail rather than being silently discarded.

## Leaf records

Observed leaf classes:

- `CUINamedLayerImage`
- `CUINamedLayerVectorSVGImage`

The audit contained 204 logical leaf slots per appearance and no third leaf class.

| CoreUI property | `.icon` mapping |
|---|---|
| name | layer `name`, using the final `/` component |
| exported file | `image-name` |
| `opacity` | `opacity` |
| `blendMode` | `blend-mode` |
| `hasLightingEffects` | `glass` |
| color / gradient | `fill` |
| frame + intrinsic size | `position` |
| `blurStrength` | retained in the manifest |
| raster `fixedFrame` | retained in the manifest |

Corresponding appearance slots may resolve to different filenames or media types. Recompose compares source bytes and emits `image-name-specializations` when the resolved assets differ.

Nine audited stacks swapped artwork between appearances. One Xcode Intelligence slot changed from vector to raster in Dark.

## Rendition diagnostics

The manifest retains the following values for each lookup when available:

- runtime class;
- `data` and `srcData` lengths;
- UTI;
- type and subtype;
- object version;
- vector, opaque, and tintable flags;
- rendition opacity and blend mode;
- rendition property dictionary;
- selection conditions.

These values are manifest diagnostics, not authored fields.

### Compiler canonicalization

Compilation may change representational details without establishing a visual-fidelity defect:

- Xcode 26.5 and 26.6 converted an early-v26 `zip` raster rendition to `deepmap2`; equal-channel RGB source data could also be represented as Gray. The decoded comparison was pixel-identical or differed by at most one 8-bit color-channel value in the tested appearances.
- Xcode 26.5 and 26.6 both omitted the same fully transparent, zero-opacity leaf from a compiled stack.

These transformations predate v27 and were identical at the tested Xcode 26.5/26.6 boundary. Recompose preserves the representable authored source and does not attempt to reproduce compiler-private encoding choices or restore a leaf the compiler deliberately removes unless a rendered difference is demonstrated.

## Appearance alignment

Current assembly requires:

- equal stack-child counts across Default, Dark, and Tintable;
- equal leaf counts in corresponding groups;
- matching group names at corresponding compiled indexes.

Leaf class, filename, and bytes are allowed to differ.

For ordinary properties, Recompose synthesizes specializations from the three effective values:

```text
if Default == Dark and Dark == Tinted:
    emit scalar Default
else:
    emit base Default
    emit Dark only when Dark != Default
    emit Tinted only when Tinted != Dark
```

The root background uses the separate rule above.

## Blend modes

| Core Graphics raw value | `.icon` value |
|---:|---|
| 0 | `normal` |
| 4 | `darken` |
| 1 | `multiply` |
| 26 | `plus-darker` |
| 5 | `lighten` |
| 2 | `screen` |
| 27 | `plus-lighter` |
| 3 | `overlay` |
| 8 | `soft-light` |
| 9 | `hard-light` |

Recompose applies the mapping to groups and leaves, including appearance specializations. Other Core Graphics modes cause assembly to fail instead of producing an invalid `.icon` token.

## Colors and fills

Color-space mapping:

| Core Graphics name | `.icon` token |
|---|---|
| `kCGColorSpaceDisplayP3` | `display-p3` |
| `kCGColorSpaceExtendedSRGB` | `extended-srgb` |
| `kCGColorSpaceSRGB` | `srgb` |
| `kCGColorSpaceExtendedGray` | `extended-gray` |
| `kCGColorSpaceGenericGrayGamma2_2` | `gray` |

Serialization includes all components, including alpha:

```text
token:component,component,...
```

Current fill mappings:

| CoreUI record | `.icon` value |
|---|---|
| named `system-light` | `"system-light"` |
| named `system-dark` | `"system-dark"` |
| color | `{ "solid": color }` |
| no color or gradient | `"none"` |
| type `0`, one-color gradient | `automatic-gradient` |
| type `1`, two-color gradient | `linear-gradient` plus start/stop orientation |

Recompose branches on the numeric CoreUI gradient type rather than color count. Missing, malformed, and unknown types cause an explicit failure instead of being approximated as another fill. The manifest preserves gradient colors, stops, points, numeric type, and name even when the public authored form uses only part of that data.

The public `automatic-gradient` form has no known orientation field. Two Screen Sharing layers therefore recompile with the default end point instead of their unusual source end point. This is tracked in Automatic-gradient orientation.

## Vector extraction

For `CUINamedLayerVectorSVGImage`:

1. Extraction reads the Core Graphics SVG document from `svgDocument`.
2. It resolves `CGSVGDocumentWriteToData`.
3. The document is serialized into mutable data.
4. A missing document, symbol, or empty result causes extraction to fail.
5. The serialized SVG `viewBox` supplies the intrinsic width and height.

Raw rendition `data`/`srcData` is not copied as SVG. Compiled vectors are CSI/`ISTC` data; the Core Graphics document is the serialization source.

The serialized SVG is equivalent source artwork, not the original byte stream.

## Raster extraction

For `CUINamedLayerImage`:

1. Extraction reads the resolved `CGImage`.
2. ImageIO encodes it as PNG.
3. The manifest records intrinsic size and `fixedFrame`.
4. A null image or failed or empty destination causes extraction to fail.

This does not preserve original compression, ancillary metadata, encoded bytes, or unselected rendition alternatives.

## Geometry

CoreUI supplies frame `(x, y, w, h)`. Source intrinsic dimensions are `(iw, ih)`.

For an authored uniform scale `s` and translation `(tx, ty)`, the tested Xcode compiler calculates each frame from continuous scaled dimensions:

```text
scaledWidth  = iw * s
scaledHeight = ih * s

w = roundToNearestEven(scaledWidth)
h = roundToNearestEven(scaledHeight)

x = floor(512 + tx - scaledWidth / 2)
y = floor(512 + ty - scaledHeight / 2)
```

Reconstruction intersects the scale intervals that can round to the observed width and height. When they overlap, it selects the midpoint of that intersection. Translation uses the midpoint of the continuous-origin interval discarded by `floor`:

```text
tx = x + 0.5 + scaledWidth / 2 - 512
ty = y + 0.5 + scaledHeight / 2 - 512
```

When no uniform-scale interval exists, Recompose uses the axis candidate with the lower opposite-axis residual and rejects residuals above `1.1` points. It omits `position` when the extracted frame is consistent with Icon Composer's centered unit-scale default rather than inventing an explicit transform.

The resulting document form is:

```json
{
  "scale": 1.25,
  "translation-in-points": [24, -12]
}
```

Geometry uses the raster intrinsic size or SVG `viewBox`. Non-square vectors do not default to 1024 × 1024.

One Activity Monitor glow uses a square `1024×1024` source with a compiled `2229×2228` frame. Icon Composer exposes only one uniform scale, and no value can reproduce those unequal dimensions from a square source under the observed rounding rule. Recompose preserves the closest representable frame. This is an accepted public-format limitation, not an open geometry defect.

## Current preservation limits

The current lookup selects one effective value for gamut, locale, and layout direction.

- Six audited apps contained P3 raster alternatives across 11 logical assets.
- Font Book contained 17 localized forms of one vector leaf.
- Calendar, Font Book, and Stocks contained flippable/right-pointing conditions.
- PNG export from `CGImage` does not preserve the original encoded raster.
- SVG export through Core Graphics does not preserve the original source bytes or author metadata.
- Calendar and Clock stacks contained static artwork only; no date, time, animation, or rotation semantics were present in the inspected stack records.

Investigations needed to close or extend these limits are in the backlog.

## Assembly failure conditions

Assembly stops instead of silently changing the document when:

- an appearance cannot be resolved;
- appearance trees cannot be aligned;
- a group or leaf type is unsupported;
- an enum or color space has no mapping;
- a fill cannot be represented;
- SVG bounds are missing or invalid;
- a frame does not fit the supported uniform transform;
- an asset reference escapes `Assets/`;
- the output package already exists.

The extraction manifest remains available when assembly stops.

## Regression procedure

Discovery and extraction regressions cover:

1. A read-only run over the 36-CAR audit set.
2. Confirmation of the same 38 logical names, including zero-stack and multi-stack catalogs.
3. Resolution of all three appearances for every stack.
4. Comparison of stack, group, and leaf counts, classes, names, conditions, and rendition diagnostics.
5. Comparison of appearance-specific asset bytes and media types.
6. Separate coverage of P3, locale, and direction-bearing cases.

Mapping and assembly regressions cover:

1. Extraction into a fresh directory.
2. Assembly into a new `.icon` path.
3. Validation of package references and JSON.
4. Opening or export with the exact Icon Composer executable under test.
5. Compilation through the intended Xcode generation.
6. CoreUI read-back of the compiled CAR.
7. Comparison of Default, Dark, and Tintable structures.
8. Comparison of the compiled icon under the same system renderer as the source.

Pipeline commands:

```sh
coreui-icon-extract /path/to/Assets.car LOGICAL_NAME /fresh/extraction
icon-recreate /fresh/extraction/manifest.json /fresh/extraction/Assets /output/Example.icon
```

The procedure uses a fresh extraction directory and passes the `Assets/` subdirectory rather than the extraction root. Recompose does not overwrite an existing `.icon` package implicitly.

Focused regression cases:

| Case | Coverage |
|---|---|
| Maps | conventional single `AppIcon`, ordering, specializations |
| Microsoft Excel | multiple nonstandard names |
| Keka / Xcode | appearance-specific artwork |
| Image Playground | group-level Screen blending |
| Preview | Soft Light |
| Apple Developer `AppIcon-Release` | Plus Darker, when available |
| Image Capture | `system-dark`, explicit Dark background, disabled specular, mixed media, non-square placement |

Structural fidelity means preserving groups, leaf slots, source alternatives, and property values. Visual fidelity means that the reconstructed document, after compilation, reproduces the original stack under equivalent system rendering conditions. They are separate results.
