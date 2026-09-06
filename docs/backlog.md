# Liquid Glass icon research backlog

Open questions and provisional mappings removed from the two specifications.

## Workflow

Each item stays here until a controlled test resolves it.

1. Record the source observation and current implementation behavior.
2. Build the smallest synthetic fixture that isolates the variable.
3. Validate in Icon Composer.
4. Compile with a recorded Xcode version.
5. Read the CAR back through CoreUI.
6. Compare under the same system renderer when the question affects appearance.
7. Move the settled result into [`icon-document.md`](icon-system-specs/icon-document.md) or [`icon-image-stack.md`](icon-system-specs/icon-image-stack.md).
8. Record rejected hypotheses when they prevent repeating a failed path.

Status values: `open`, `testing`, `validated`, `rejected`, `blocked`.

## Pipeline correctness

### LG-001 — Shadow style zero

- Status: `open`
- Current code: CoreUI raw shadow style `0` → `.icon` `shadow.kind = "none"`.
- Basis: raw `0` appears when serialized catalog metadata omits a shadow style; accepted documents use `none`.
- Missing proof: controlled Shadow Off compile/read-back.
- Test: author Off, Layer Color, and Neutral with distinct opacities; compile and compare raw style plus effective rendering.

### LG-002 — Refraction enablement

- Status: `open`
- Current code: `refractivity.enabled` is true when depth or strength is nonzero.
- Risk: an author may disable refraction while retaining nonzero slider values.
- Test: save enabled and disabled documents with identical nonzero depth/strength; compile and find the independent enablement signal.

### LG-003 — Translucency enablement

- Status: `open`
- Current code: `translucency.enabled` is true when the numeric value is nonzero.
- Risk: a disabled control may retain a nonzero value.
- Test: save enabled and disabled documents with the same nonzero value; compile and compare the group records.

### LG-004 — One-color compiled gradient

- Status: `open`
- Current code: a one-color CoreUI gradient record becomes `.icon` `{ "solid": ... }`.
- Corpus: 17 records across 1Password, Firefox, Mactracker, Transmission, WhatsApp, Xcode Intelligence, Automator Speech, and Time Machine.
- Test: author the same visible color through every fill UI path; compile and identify which path creates a one-color gradient record.

### LG-005 — Divergent appearance trees

- Status: `open`
- Current code: requires equal group counts, equal corresponding leaf counts, and matching group names.
- Known supported variation: corresponding slots may change filename and media type.
- Test: determine whether Icon Composer can author different group/leaf counts or reorder slots per appearance.
- Follow-up: define stable slot matching if valid trees can diverge.

### LG-006 — Group `hasLightingEffects`

- Status: `open`
- Current code: records the Boolean but does not emit a distinct group field.
- Test: isolate all group-level Effects/lighting controls and correlate the value with `lighting`, leaf `glass`, and rendered output.

### LG-007 — Leaf `blurStrength`

- Status: `open`
- Current code: records the value but does not map it to an authored layer field.
- Test: vary layer and group blur independently, compile, and compare accessors and JSON.

### LG-008 — Raster `fixedFrame`

- Status: `open`
- Current code: records the flag but does not map it to `.icon`.
- Test: identify the Icon Composer control or source condition that changes `fixedFrame`; compare placement at multiple platforms/sizes.

## Backgrounds and fills

### LG-009 — `automatic-gradient`

- Status: `open`
- Known: it is an accepted authored fill form and is not a substitute for `system-light` or `system-dark`.
- Test: author each automatic-background choice, reserialize it, compile it, and compare the named/unnamed CoreUI gradient record and system rendering.

### LG-009A — System Light preset round trip

- Status: `open`
- Current mapping: compiled `system-light` name → `.icon` `"system-light"`.
- Known control: the equivalent `system-dark` mapping is validated Finder-to-Finder.
- Test: reconstruct a catalog using the named System Light background, compile it, and compare the resulting named gradient plus system rendering.

### LG-010 — More than two gradient colors

- Status: `open`
- Current writer: supports two-color linear gradients.
- Test: determine whether Icon Composer can author three or more stops and whether it stores stops separately from colors.

### LG-011 — Non-linear gradient types

- Status: `open`
- Manifest: retains numeric gradient type, colors, stops, and endpoints.
- Test: exercise every fill type exposed by Icon Composer and map the compiled gradient type back to JSON.

### LG-012 — Null, omission, and zero blur

- Status: `open`
- Observation: accepted documents contain both omitted `blur-material` and JSON `null`; current output omits zero.
- Test: reserialize and compile absent, `null`, and zero values; compare resulting records and rendering.

### LG-013 — Group-level fill

- Status: `open`
- Corpus: no group-level fill was observed.
- Test: determine whether the current Icon Composer UI or schema can assign a group fill and identify its CoreUI representation.

## Document schema

### LG-014 — Required and optional root keys

- Status: `open`
- Test matrix: remove or vary `features`, root fill, `groups`, and `supported-platforms` one at a time across current Icon Composer versions.
- Deliverable: minimum accepted document and canonical saved document.

### LG-015 — Feature-token semantics

- Status: `open`
- Current output: `refractivity`, `specular-location`.
- Test: remove each token while retaining the corresponding fields; reserialize, compile, and compare behavior.
- Also enumerate new tokens produced by later Icon Composer versions.

### LG-016 — `supported-platforms` grammar

- Status: `open`
- Current output: `circles: [watchOS]`, `squares: shared`.
- Test: save every platform-selection combination and determine allowed tokens, scalar/array forms, defaults, and inheritance.

### LG-017 — Additional package members

- Status: `open`
- Known package: `icon.json` plus `Assets/`.
- Test: create documents through all supported workflows and compare package members before and after save/export.

### LG-018 — Historical schema migration

- Status: `open`
- Inputs to test:
  - nested `slot.appearance` versus sibling `appearance`;
  - `specular-highlight-placement` versus `specular`;
  - Boolean and string disabled-specular forms.
- Run through Icon Composer 1.x and 2.x; record accepted, migrated, rejected, and rendering behavior.

### LG-019 — Hidden state

- Status: `open`
- Observation: `hidden` occurs in authored groups and layers.
- Test: compile hidden group/leaf cases with nonzero opacity and compare whether CoreUI retains a distinct field, changes opacity, or prunes content.

### LG-020 — Group position

- Status: `open`
- Observation: `position` occurs on authored groups; leaf mapping is validated.
- Test: author group-only translation and scale, compile, and locate the corresponding CoreUI geometry.

### LG-021 — Specializable-property completeness

- Status: `open`
- Current list comes from accepted documents and successful generation.
- Test: attempt Default/Dark/Mono overrides for every root, group, and layer inspector control; reserialize and compile each.

## Variants and fidelity

### LG-022 — Display gamut and high-bit-depth artwork

- Status: `open`
- Current lookup: gamut `0`; resolved `CGImage` is encoded as PNG.
- Corpus: P3 alternatives across 11 logical assets in six apps; higher-precision alternatives can be missed.
- Test: enumerate gamut keys, request each alternative, preserve bit depth/profile, and determine whether `.icon` can encode the selection.

### LG-023 — Locale variants

- Status: `open`
- Corpus: Font Book had 17 localized forms of one vector leaf.
- Current lookup: `locale:nil` resolves one form.
- Test: enumerate locales, request each value, and determine whether variants originate in `.icon`, another source resource, or compilation.

### LG-024 — Layout direction and flippable variants

- Status: `open`
- Corpus: Calendar, Font Book, and Stocks carry direction conditions.
- Test: request left-to-right and right-to-left variants and determine whether `.icon` can author or preserve them.

### LG-025 — Original raster preservation

- Status: `open`
- Current behavior: resolved `CGImage` → new PNG.
- Goal: determine whether safe rendition/source data access can preserve original bit depth, profile, and encoding without copying an unrelated CSI wrapper.

### LG-026 — Original SVG preservation

- Status: `open`
- Current behavior: Core Graphics SVG document → `CGSVGDocumentWriteToData` serialization.
- Goal: characterize what source metadata, IDs, structure, and unsupported SVG features are normalized or lost.

### LG-027 — General transform model

- Status: `open`
- Current mapping: uniform scale plus center translation with a `1.1`-point residual tolerance.
- Test: author rotation, nonuniform scale, crop, alternate anchors, and subpoint translation if the UI/schema permits them.

### LG-028 — Non-1024 canvas geometry

- Status: `open`
- Known: Apple Watch authoring uses 1088 × 1088; audited macOS stacks use 1024 × 1024.
- Test: compile and inspect watchOS output, then generalize center and default-frame calculations by resolved canvas size.

### LG-029 — Flattened companion semantics

- Status: `open`
- Corpus: every stack had flattened and multisize companions elsewhere in the CAR.
- Test: compare companion pixels with Icon Composer export and system rendering across size, appearance, and design generation.
- Goal: identify masking, postprocessing, material rendering, or size-specific treatment not present in the stack.

### LG-030 — `renderingProperties`

- Status: `open`
- Current manifest: retains the stack dictionary diagnostically.
- Test: diff it across isolated authoring changes and identify fields not already exposed through group/leaf accessors.

## Compatibility and tooling

### LG-031 — Tahoe 26 runtime validation

- Status: `open`
- Current app target: macOS 26 minimum.
- Existing broad audit: macOS 27 beta runtime.
- Test: run discovery, extraction, assembly, Icon Composer acceptance, and compiled read-back on Tahoe 26 with the same representative corpus.

### LG-032 — Icon Composer/Xcode generation matrix

- Status: `open`
- Recorded tool split: standalone Icon Composer 2.0 versus Xcode 26.6-bundled Icon Composer CLI 1.6.
- Test: run the same synthetic fixtures through each installed combination and record schema migration and rendered differences.

### LG-033 — Icon Composer CLI failure in restricted environments

- Status: `open`
- Observation: direct JSON reads succeeded while several known-good packages failed document opening with exit 255 under a restricted Codex environment.
- Test: compare environment, cache, XPC, sandbox, and bundle execution outside the restricted process.
- Rule: do not treat this diagnostic as document corruption.

### LG-034 — Private CoreUI surface stability

- Status: `open`
- Test: enumerate only the selectors Recompose uses across supported macOS versions and record changes in class names, signatures, defaults, and lookup behavior.

### LG-035 — Primary-icon role outside the stack records

- Status: `open`
- Audit result: no universal primary marker in the inspected CAR metadata.
- Test: correlate bundle metadata, asset-catalog build settings, and multiple-stack CARs without changing the rule that ambiguous stacks require a user choice.

### LG-036 — Stack-shape limits

- Status: `open`
- Corpus: one to four groups, raster/SVG leaves, three appearances, source object version 17.
- Test: use synthetic documents and future corpora to determine whether more groups, other leaf classes, missing appearances, or another object generation are valid.

## Regression assets to create

- [ ] Minimal one-group SVG icon.
- [ ] Four-group/two-leaf ordering icon.
- [ ] Every group blend mode.
- [ ] Every leaf blend mode.
- [ ] Default/Dark/Mono source swap.
- [ ] Vector/raster media swap by appearance.
- [ ] System Light and System Dark backgrounds with explicit and omitted Dark values.
- [ ] None, solid, linear, one-color, multi-stop, and automatic fills.
- [ ] Non-square SVG and raster placement.
- [ ] Specular Off/Automatic/Inside/Outside.
- [ ] Refraction enabled/disabled with retained nonzero values.
- [ ] Translucency enabled/disabled with retained nonzero values.
- [ ] Shadow None/Layer Color/Neutral with opacity above 1.
- [ ] Individual/Combined lighting.
- [ ] P3/high-bit-depth alternatives.
- [ ] Locale and layout-direction alternatives.
