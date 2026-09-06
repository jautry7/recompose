# `IconImageStack` specification

Project notes for the Liquid Glass icon subset of macOS `Assets.car` and its reconstruction as an Icon Composer document.

Scope:

- logical icon-stack discovery;
- CoreUI lookup conditions;
- resolved background, group, and leaf records;
- mapping resolved records to `.icon` fields;
- extraction and reconstruction invariants;
- current preservation limits;
- regression procedure.

Out of scope: the general CAR container, unrelated asset types, and raw BOMStore/CSI layout.

## Model

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

`AppIcon` is conventional, not required. A CAR can contain zero, one, or several icon stacks.

Validated discovery sequence:

1. Open the CAR with `CUICatalog`.
2. Enumerate named lookups.
3. Collect names from multisize-image and directly visible icon-layer-stack lookups.
4. Collect both `name` and `renditionName` when present.
5. Remove a terminal `.iconstack` suffix from candidate names.
6. Attempt `iconLayerStack` resolution for every candidate under the recognized appearance aliases.
7. Keep only names that resolve as an icon stack.
8. Present all suffixless logical names; do not infer a primary stack.

Direct class filtering is incomplete. Calendar, Font Book, and Stocks did not enumerate as direct icon-stack objects in the audit. Treating every multisize lookup as an icon stack creates false positives. Type-specific resolution is the decisive test.

### Discovery outcomes

| State | Meaning |
|---|---|
| Cannot open CAR | Input, catalog, runtime, or environment failure. |
| No icon stack | Valid CAR with no logical `IconImageStack`. |
| One icon stack | Reconstruct the discovered logical name. |
| Multiple icon stacks | Require a selection. |

Do not collapse “no icon stack” into “cannot process CAR.”

## Lookup tuple

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

Appearance aliases:

| Manifest role | Catalog aliases |
|---|---|
| `UIAppearanceLight` | `UIAppearanceLight`, `NSAppearanceNameAqua` |
| `UIAppearanceDark` | `UIAppearanceDark`, `NSAppearanceNameDarkAqua` |
| `ISAppearanceTintable` | `ISAppearanceTintable` |

Record the alias that resolved. Do not expose alias differences as different authored appearances.

## Extraction manifest

Recompose separates CoreUI extraction from `.icon` assembly. The intermediate manifest is project-owned, not an Apple format.

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

Each appearance contains the resolved stack record and its background/group/leaf tree. Extracted SVG and PNG files live in the adjacent `Assets/` directory. Keep private runtime identity, selection conditions, rendition metadata, and otherwise unmapped values in the manifest.

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
| `sourceObjectVersion` | compiled stack generation |
| `renderingProperties` | diagnostic metadata |
| `layers` | background followed by groups, in compiled order |
| `dataRepresentation` | opaque diagnostic representation |

Audit snapshot: 38 stacks across 36 human-selected macOS CARs.

| Observation | Result |
|---|---:|
| CARs containing a stack | 31 of 36 |
| Logical stacks | 38 |
| Stacks named `AppIcon` | 20 |
| CARs with multiple stacks | 4 |
| CARs with no stack | 5 |
| Canvas | 1024 × 1024 for all 38 |
| Scale | 1 for all 38 |
| Source object version | 17 for all 38 |
| Appearance representations | 3 for all 38 |

The detailed corpus remains in `recompose/docs/car-audit.md`.

## Compiled order

CoreUI order is the inverse of authored `icon.json` order at both hierarchy levels.

```text
CoreUI stack: [background, back group, ..., front group]
icon.json:    [front group, ..., back group]

CoreUI group: [back leaf, ..., front leaf]
icon.json:    [front leaf, ..., back leaf]
```

Reconstruction removes child zero and reverses the remaining groups. It also reverses every group's leaves.

## Background record

Child zero is the root background, not an authored group. It carries a color or gradient and can retain a semantic preset name.

Known preset names:

- `system-light`
- `system-dark`

The name is rendering data. Do not reduce these presets to their resolved color components.

Validated `system-dark` result:

- Image Capture resolved the same named `system-dark` record for Default, Dark, and Tintable.
- Reconstructing its gamma-2.2 gray stops as a literal gray gradient rendered too light.
- Reconstructing `automatic-gradient` from black rendered too dark.
- Reconstructing equal-channel Display P3/sRGB stops matched an Icon Composer preview and flattened companion closely but remained too light after compilation.
- The RGB reconstruction compiled as a generated `Gradient-1`; the source retained the named `system-dark` record.
- Emitting the string value `"system-dark"` preserved the semantic record.
- The rebuilt icon matched Image Capture in a Finder-to-Finder comparison.

Root appearance handling is not ordinary value deduplication:

```text
fill-specializations = [
    { value: Default },
    { appearance: dark, value: Dark },
    Tinted != Dark ? { appearance: tinted, value: Tinted } : omitted
]
```

Always retain the explicit Dark root specialization, even when its resolved value equals Default. Omitting Dark asks Icon Composer to supply its automatic system Dark background. Tintable can inherit Dark when equal.

## Group record

Observed runtime class: `CUINamedIconLayerGroup`.

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

Do not clamp material numbers to UI-looking ranges.

### Specular mapping

```text
hasSpecular == false -> false
hasSpecular == true, placement 0 -> "automatic"
hasSpecular == true, placement 1 -> "inside"
hasSpecular == true, placement 2 -> "outside"
```

Boolean `false` is required for the disabled state. The string `"none"` was accepted structurally but produced unwanted highlights and dark outlines. Manual comparison confirmed that `false` removed the defect.

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

Corresponding appearance slots may resolve to different filenames or media types. Compare source bytes and emit `image-name-specializations` when the resolved assets differ.

Nine audited stacks swapped artwork between appearances. One Xcode Intelligence slot changed from vector to raster in Dark.

## Rendition diagnostics

Retain for each lookup when available:

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

## Appearance alignment

Current assembly requires:

- equal stack-child counts across Default, Dark, and Tintable;
- equal leaf counts in corresponding groups;
- matching group names at corresponding compiled indexes.

Leaf class, filename, and bytes are allowed to differ.

For ordinary properties, synthesize specializations from the three effective values:

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

Apply the mapping to groups and leaves, including appearance specializations. Reject other Core Graphics modes instead of emitting an invalid `.icon` token.

## Colors and fills

Color-space mapping:

| Core Graphics name | `.icon` token |
|---|---|
| `kCGColorSpaceDisplayP3` | `display-p3` |
| `kCGColorSpaceExtendedSRGB` | `extended-srgb` |
| `kCGColorSpaceSRGB` | `srgb` |
| `kCGColorSpaceExtendedGray` | `extended-gray` |
| `kCGColorSpaceGenericGrayGamma2_2` | `gray` |

Serialize all components, including alpha:

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
| two-color linear gradient | `linear-gradient` plus start/stop orientation |

Preserve gradient colors, stops, points, numeric type, and name in the manifest even when the writer uses only part of that data.

## Vector extraction

For `CUINamedLayerVectorSVGImage`:

1. Read the Core Graphics SVG document from `svgDocument`.
2. Resolve `CGSVGDocumentWriteToData`.
3. Serialize into mutable data.
4. Reject a missing document, symbol, or empty result.
5. Parse the serialized SVG `viewBox` for intrinsic width and height.

Do not copy raw rendition `data`/`srcData` as SVG. Compiled vectors are CSI/`ISTC` data; the Core Graphics document is the serialization source.

The serialized SVG is equivalent source artwork, not the original byte stream.

## Raster extraction

For `CUINamedLayerImage`:

1. Read the resolved `CGImage`.
2. Encode it as PNG with ImageIO.
3. Record intrinsic size and `fixedFrame`.
4. Reject a null image or failed/empty destination.

This does not preserve original compression, ancillary metadata, encoded bytes, or unselected rendition alternatives.

## Geometry

CoreUI supplies frame `(x, y, w, h)`. Source intrinsic dimensions are `(iw, ih)`.

Scale candidates:

```text
sw = w / iw
sh = h / ih
```

Select the candidate whose predicted opposite dimension has the lower residual:

```text
rw = abs(ih * sw - h)
rh = abs(iw * sh - w)
s  = sw when rw <= rh, otherwise sh
```

Current tolerance: minimum residual no greater than `1.1` points.

For the 1024-square macOS canvas:

```text
tx = x + w / 2 - 512
ty = y + h / 2 - 512
```

Emit:

```json
{
  "scale": 1.25,
  "translation-in-points": [24, -12]
}
```

Omit `position` for frame `(0, 0, 1024, 1024)`.

Use raster intrinsic size or the SVG `viewBox`. Do not default non-square vectors to 1024 × 1024.

## Current preservation limits

The current lookup selects one effective value for gamut, locale, and layout direction.

- Six audited apps contained P3 raster alternatives across 11 logical assets.
- Font Book contained 17 localized forms of one vector leaf.
- Calendar, Font Book, and Stocks contained flippable/right-pointing conditions.
- PNG export from `CGImage` does not preserve the original encoded raster.
- SVG export through Core Graphics does not preserve the original source bytes or author metadata.
- Calendar and Clock stacks contained static artwork only; no date, time, animation, or rotation semantics were present in the inspected stack records.

Investigations needed to close or extend these limits are in [`backlog.md`](../backlog.md).

## Assembly failures

Abort instead of silently changing the document when:

- an appearance cannot be resolved;
- appearance trees cannot be aligned;
- a group or leaf type is unsupported;
- an enum or color space has no mapping;
- a fill cannot be represented;
- SVG bounds are missing or invalid;
- a frame does not fit the supported uniform transform;
- an asset reference escapes `Assets/`;
- the output package already exists.

Preserve the extraction manifest when assembly stops.

## Regression procedure

For discovery or extraction changes:

1. Run the 36-CAR audit set read-only.
2. Confirm the same 38 logical names, including zero-stack and multi-stack catalogs.
3. Resolve all three appearances for every stack.
4. Compare stack/group/leaf counts, classes, names, conditions, and rendition diagnostics.
5. Check appearance-specific asset bytes and media types.
6. Check P3, locale, and direction-bearing cases separately.

For mapping or assembly changes:

1. Extract into a fresh directory.
2. Assemble into a new `.icon` path.
3. Validate package references and JSON.
4. Open or export with the exact Icon Composer executable under test.
5. Compile through the intended Xcode generation.
6. Read the compiled CAR back through CoreUI.
7. Compare Default, Dark, and Tintable structures.
8. Compare the compiled icon under the same system renderer as the source.

Pipeline commands:

```sh
coreui-icon-extract /path/to/Assets.car LOGICAL_NAME /fresh/extraction
icon-recreate /fresh/extraction/manifest.json /fresh/extraction/Assets /output/Example.icon
```

Use a fresh extraction directory, pass the `Assets/` subdirectory rather than the extraction root, and do not overwrite an existing `.icon` package implicitly.

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

Structural success and visual fidelity are separate results.
