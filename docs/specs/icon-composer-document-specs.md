# Icon Composer `.icon` document specs

> This document outlines observed specifications for the `.icon` Icon Composer document, which enables developers to create a Liquid Glass-ready icon asset for their app. It describes the latest version of the document format, introduced with Icon Composer 2 (v27), which was released alongside macOS Golden Gate 27. Due to changes in the Liquid Glass design system, Icon Composer 2 introduced several new rendering properties that are unsupported on v26; the differences between the v26 specification and v27 specification are denoted where applicable with compatibility notes.
>
> **Note:** Apple marketing refers to the 2026 version of Icon Composer as "Icon Composer 2", though the application bundle identifies it as version 27. For the purposes of the Recompose project, the second version of the document format is referred to as the v27 specification, as that version number aligns with the year-based versioning system now used by Xcode and macOS itself.

## Compatibility

Compatibility differs between the editable `.icon` document and the compiled icon resources that Xcode builds from it.

A document created with Icon Composer 1 can be opened with Icon Composer 2; this carry-forward behavior is explicitly communicated by Apple. The document's existing artwork automatically adopts the updated material rendering, after which the designer can optionally use the new refractivity and specular controls introduced with the v27 rendering system.

Compatibility does not extend in the opposite direction. Once a document uses properties exclusive to v27, it can no longer be opened by Tahoe-era Icon Composer, or compiled by Xcode 26. Icon Composer 1.5 and earlier display a generic error message, and version 1.6 – released shortly after macOS Golden Gate 27 was announced – recognizes that the document uses a newer specification but cannot open it, instead reporting: “This document uses features from a newer version of Icon Composer.” Xcode 26 likewise refuses to compile the document and reports a generic error through `actool`, its command-line asset-catalog compiler.

This compatibility restriction applies to the source document, but not to the systems on which the finished app can run. Xcode can generate appropriate icon resources for earlier deployment targets when it compiles the document; a v27 document can therefore be compiled to produce an app icon that works on Tahoe, even though Tahoe-era tools cannot read the original document.

## Package

A group is an ordered collection of artwork that receives shared composition and rendering properties. Each individual artwork item within a group is a leaf layer. Its source artwork is the SVG or raster file referenced by that leaf.

```text
Example.icon/
├── icon.json
└── Assets/
    ├── foreground.svg
    └── texture.png
```

- `.icon` is a directory package.
- `icon.json` is a JSON root object.
- Leaf source artwork is referenced from `Assets/`.
- SVG and PNG are validated source types.
- Recompose restricts asset references to direct package-local filenames and rejects absolute paths, `..`, or symlink escapes.

## Root object

An appearance is a visual mode for which an icon can supply different artwork or property values. Icon Composer presents Default, Dark, and Mono; `icon.json` identifies the latter two as `dark` and `tinted`, while the compiled representation calls the third Tintable. An appearance specialization is an alternate value for one property in one of these appearances.

A fill is a background or artwork treatment applied by Icon Composer rather than baked into source artwork. It may be absent, solid, gradient-based, or a semantic system preset.

| Key | Type | Meaning |
|---|---|---|
| `features` | string array | schema feature declarations |
| `fill` | fill value | root background without appearance overrides |
| `fill-specializations` | specialization array | appearance-specific root background |
| `groups` | group array | front-to-back authored groups |
| `supported-platforms` | object | platform shape families |

Current v27 feature set:

```json
"features": ["refractivity", "specular-location"]
```

> **v26 compatibility:** v26 documents omit the root `features` key. They also omit refractivity and the v27 specular-placement values described below.

Common platform value:

```json
"supported-platforms": {
  "circles": ["watchOS"],
  "squares": "shared"
}
```

## Canvas and order

Authored order is the order Icon Composer writes groups and layers into `icon.json`; the observed format places the frontmost item first.

- iPhone, iPad, and Mac source canvas: 1024 × 1024.
- Apple Watch source canvas: 1088 × 1088.
- Audited macOS compiled stacks: 1024 × 1024 at scale 1.
- `groups[0]` is frontmost.
- `group.layers[0]` is frontmost.
- Array order, not filename or numeric name prefix, controls stacking.
- The root background is separate from `groups`.
- The final platform mask is system-applied.

## Root background

Supported authored forms include:

- `"system-light"`
- `"system-dark"`
- `"none"`
- solid fill object
- linear-gradient object
- automatic-gradient object

`system-light` and `system-dark` are semantic preset values. Recompose preserves them by name rather than replacing them with their resolved CoreUI gradient components.

Root background inheritance is appearance-special:

- an omitted Dark value asks Icon Composer to supply its automatic system Dark gradient;
- an explicit Dark value records an authored override, even when equal to Default;
- Tintable/Mono can inherit the effective Dark value when equal.

Canonical form means the representation that the current Icon Composer writes or consistently interprets with the intended editable behavior. A form can parse without being canonical or preserving those semantics.

Canonical reconstruction:

```json
{
  "fill-specializations": [
    { "value": "system-dark" },
    { "appearance": "dark", "value": "system-dark" }
  ]
}
```

The duplicate Dark entry is semantically significant.

## Specializations

The base item is the default value of a specializable property. It applies to the Default appearance and supplies the inherited value when a later appearance does not provide an override.

Ordinary properties use a scalar when all appearances share one value:

```json
"opacity": 0.8
```

Appearance-specific values use `<key>-specializations`:

```json
"opacity-specializations": [
  { "value": 1 },
  { "appearance": "dark", "value": 0.8 },
  { "appearance": "tinted", "value": 0.6 }
]
```

Canonical order:

1. base item with `value` and no `appearance`;
2. optional `dark` item;
3. optional `tinted` item.

Ordinary inheritance:

- Dark inherits base when absent.
- Tinted inherits the effective Dark value when absent.

The root background uses the exception above.

Canonical specialization items use sibling `appearance` and `value` members. The older nested `slot.appearance` form can parse but did not reproduce authored specialization behavior, so Recompose accepts it only as migration input.

When a variant adds a property absent from the base, the base item can require JSON `null`. For fills, the semantic value `"none"` suppresses native source paint.

Observed specializable properties:

- root `fill`;
- group `blend-mode`, `opacity`, `refractivity`, `shadow`, `translucency`, `blur-material`, `specular`, and `lighting`;
- layer `image-name`, `opacity`, `blend-mode`, `glass`, `fill`, and `position`.

## Fill values

### None

```json
"none"
```

### System preset

```json
"system-dark"
```

### Solid

```json
{
  "solid": "display-p3:0.2,0.6,0.9,1"
}
```

Color syntax:

```text
color-space:component,component,...
```

Observed tokens:

- `display-p3`
- `extended-srgb`
- `srgb`
- `extended-gray`
- `gray`

The component list includes alpha. Recompose preserves the numeric values without clamping them to UI ranges.

### Linear gradient

```json
{
  "linear-gradient": [
    "display-p3:0.1,0.3,0.8,1",
    "display-p3:0,0.1,0.4,1"
  ],
  "orientation": {
    "start": { "x": 0, "y": 0 },
    "stop": { "x": 1, "y": 1 }
  }
}
```

### Automatic gradient

Observed document form:

```json
{
  "automatic-gradient": "extended-gray:1,1"
}
```

`automatic-gradient` is not a numerical substitute for `system-light` or `system-dark`.

## Position

Accepted form:

```json
{
  "scale": 1.25,
  "translation-in-points": [24, -12]
}
```

- `scale` is uniform.
- `translation-in-points` is a two-number array.
- Translation is relative to the canvas center.
- An `{x, y}` translation object was rejected.
- Replacing the complete position object with a vector array was rejected.
- Position occurs on layers and has also been observed on groups.

## Group object

Material annotations control system rendering rather than source pixels. Group-level examples include refraction, specular placement, blur, translucency, lighting, and shadow.

| Key | Type | Meaning |
|---|---|---|
| `name` | string | editable group name |
| `layers` | array | front-to-back leaves |
| `blend-mode` | string | group compositing |
| `opacity` | number | group opacity |
| `hidden` | Boolean | authoring visibility |
| `position` | position | group transform |
| `lighting` | string | `individual` or `combined` |
| `refractivity` | object | refraction state and values |
| `shadow` | object | shadow kind and opacity |
| `translucency` | object | translucency state and value |
| `blur-material` | number or null | blur amount |
| `specular` | Boolean or string | disabled state or enabled placement |

Any specializable group key can instead use its `-specializations` form.

### Refractivity

```json
{
  "enabled": true,
  "depth": 0.08,
  "strength": 0.56
}
```

Negative compiled strengths occur, so Recompose does not constrain values to `0...1`.

> **v26 compatibility:** Refractivity is available in v27 and later. A v26 document omits the `refractivity` property and the root `refractivity` feature declaration.

### Shadow

```json
{
  "kind": "neutral",
  "opacity": 0.5
}
```

Observed kinds:

- `none`
- `layer-color`
- `neutral`

Shadow opacity above `1` is valid; Icon Composer accepted and rendered values above 100%.

### Translucency

```json
{
  "enabled": true,
  "value": 0.4
}
```

### Blur

```json
"blur-material": 0.5
```

Zero is normally omitted. JSON `null` has also appeared in accepted documents.

### Lighting

- `"individual"`: apply group lighting per leaf.
- `"combined"`: apply group lighting to the combined group.

### Specular

Disabled:

```json
"specular": false
```

Enabled placement:

```json
"specular": "inside"
```

Values:

- `false`
- `automatic`
- `inside`
- `outside`

Boolean `false` is not interchangeable with the string `"none"`. The latter produced unwanted highlights and dark outlines in reconstructed icons.

> **v26 compatibility:** v26 represents a disabled specular effect explicitly as Boolean `false`. A different state, enabled specular with compiled placement `0`, is represented by omitting the `specular` property so the v26 toolchain supplies its enabled default behavior. The `automatic`, `inside`, and `outside` placement values and the root `specular-location` feature declaration are available in v27 and later.

Current writers emit `specular`. Recompose recognizes the older experimental `specular-highlight-placement` key only as migration input.

## Layer object

| Key | Type | Meaning |
|---|---|---|
| `name` | string | editable layer name |
| `image-name` | string | filename under `Assets/` |
| `opacity` | number | leaf opacity |
| `blend-mode` | string | leaf compositing |
| `glass` | Boolean | layer Liquid Glass effects |
| `fill` | fill value | source-shape fill |
| `position` | position | uniform scale and translation |
| `hidden` | Boolean | authoring visibility |

Appearance-specific artwork uses `image-name-specializations` and may change from SVG to PNG or PNG to SVG between appearances.

Opacity zero does not remove a leaf. Recompose retains it when the slot is visible in another appearance.

## Blend modes

Supported document values:

| Value | Raw Core Graphics value |
|---|---:|
| `normal` | 0 |
| `darken` | 4 |
| `multiply` | 1 |
| `plus-darker` | 26 |
| `lighten` | 5 |
| `screen` | 2 |
| `plus-lighter` | 27 |
| `overlay` | 3 |
| `soft-light` | 8 |
| `hard-light` | 9 |

The list applies to groups and layers. Other `CGBlendMode` values cause assembly to fail instead of being mapped to invented document strings.

## Writer behavior

- The writer selects the earliest specification capable of representing every observed compiled behavior.
- Array order is preserved.
- Specializations use sibling `appearance` and `value` entries in base, Dark, Tinted order.
- Ordinary properties use Dark-to-Tinted inheritance.
- The root background always includes an explicit Dark specialization.
- `system-light` and `system-dark` are preserved by name.
- Disabled specular uses Boolean `false`.
- An explicitly absent fill uses `"none"`.
- Position uses the exact object form with a two-element translation array.
- Only supported blend-mode strings are emitted.
- All referenced assets remain inside `Assets/`.
- Source intrinsic dimensions are preserved.
- A v26 document omits root feature declarations, refractivity, and enabled placement-`0` specular. Enabled nonzero specular placements require v27 rather than an approximation.

## Reader behavior

- JSON member order is ignored, while array order is preserved.
- Specialization inheritance is resolved explicitly.
- A lossless editor path retains unrecognized keys.
- Older specialization and specular spellings are recognized only as migration input.
- Numeric validation checks for finite values without imposing guessed UI ranges.
- Asset paths resolve within the package boundary.
- Structural acceptance does not establish visual fidelity. Structural fidelity means preserving the hierarchy, source alternatives, and property values; visual fidelity means reproducing the compiled icon under equivalent system rendering conditions and generally requires human review.

## Verification

Schema verification covers:

1. Generation of the smallest synthetic package that isolates one field.
2. Confirmation that `icon.json` and its asset references parse.
3. Opening or export with the exact Icon Composer version under test.
4. Comparison of a saved copy with Icon Composer's canonical serialization.
5. Compilation through the intended Xcode generation.
6. CoreUI read-back of the resulting stack.
7. Comparison of Default, Dark, and Mono/Tintable.
8. Comparison of the compiled result under Finder or the target system renderer.

Verification records exact tool paths and versions. `xcrun --find ictool` can resolve Xcode's unrelated `ibtoold`-family utility rather than Icon Composer's export tool.

Open format questions and proposed probes are in the backlog.
