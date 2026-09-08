# Icon Composer `.icon` document specs

> Project notes for the editable Liquid Glass icon package and `icon.json` vocabulary.

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

Common feature set:

```json
"features": ["refractivity", "specular-location"]
```

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

`system-light` and `system-dark` are semantic preset values. Preserve them by name. Do not replace them with their resolved CoreUI gradient components.

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

Canonical specialization items use sibling `appearance` and `value` members. The older nested `slot.appearance` form can parse but did not reproduce authored specialization behavior; do not emit it.

When a variant adds a property absent from the base, the base item can require JSON `null`. For fills, use the semantic value `"none"` when native source paint must be suppressed.

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

The component list includes alpha. Preserve the numeric values without clamping them to UI ranges.

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

Do not use `automatic-gradient` as a numerical substitute for `system-light` or `system-dark`.

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

Negative compiled strengths occur. Do not constrain values to `0...1`.

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

Current writers emit `specular`. Older experimental documents used `specular-highlight-placement`; do not emit the older key.

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

Opacity zero does not remove a leaf. Keep it when the slot is visible in another appearance.

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

The list applies to groups and layers. Do not map other `CGBlendMode` values into invented document strings.

## Writer rules

- Preserve array order.
- Use sibling `appearance`/`value` specialization entries.
- Order specializations base, Dark, Tinted.
- Apply Dark→Tinted inheritance for ordinary properties.
- Always emit an explicit Dark root-background specialization.
- Preserve `system-light` and `system-dark` by name.
- Use `false` for disabled specular.
- Use `"none"` for an explicitly absent fill.
- Use the exact position object and two-element translation array.
- Emit only supported blend-mode strings.
- Keep all referenced assets inside `Assets/`.
- Preserve source intrinsic dimensions.

## Reader rules

- Ignore JSON member order.
- Preserve array order.
- Resolve specialization inheritance explicitly.
- Retain unrecognized keys in any lossless editor path.
- Recognize the older specialization and specular spellings only as migration input.
- Validate finite numbers, not guessed UI ranges.
- Resolve asset paths inside the package boundary.
- Do not treat a structurally accepted document as visually validated. Structural fidelity means preserving the hierarchy, source alternatives, and property values; visual fidelity means reproducing the compiled icon under equivalent system rendering conditions. Visual fidelity will generally require human review.

## Verification

For schema changes:

1. Generate the smallest synthetic package that isolates one field.
2. Confirm `icon.json` and asset references parse.
3. Open/export with the exact Icon Composer version under test.
4. Save a copy and compare Icon Composer's canonical serialization.
5. Compile the document through the intended Xcode generation.
6. Read the resulting stack back through CoreUI.
7. Compare Default, Dark, and Mono/Tintable.
8. Compare the compiled result under Finder or the target system renderer.

Record exact tool paths and versions. `xcrun --find ictool` can resolve Xcode's unrelated `ibtoold`-family utility rather than Icon Composer's export tool.

Open format questions and proposed probes are in the backlog.
