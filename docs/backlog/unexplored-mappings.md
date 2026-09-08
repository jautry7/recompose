# Unexplored mappings

- Status: open
- Priority: 2

## Problem

The extractor records several CoreUI properties whose independent authored meaning has not been established. Some are inferred by the assembler, some are retained only in the manifest, and some may duplicate another property rather than require their own `.icon` field.

No independent rendering defect has yet been attributed to most of these properties. The recompilation audit's original effect differences were consequences of the corrected Tinted-inheritance rule, not evidence that every material property was mapped incorrectly.

## Properties to classify

- raw shadow style `0` and the authored Shadow Off state;
- independent refraction enablement versus retained depth and strength;
- independent translucency enablement versus retained numeric value;
- group `hasLightingEffects`;
- leaf `blurStrength`;
- raster `fixedFrame`;
- omitted, `null`, and numeric-zero blur material;
- group-level fill;
- hidden groups and leaves;
- group position and transforms.

## Approach

Survey before probing:

1. Measure which properties actually vary in the current corpus and whether they vary independently of already mapped fields.
2. Compare extractor fields, assembler mappings, and current recompilation results as one coverage table.
3. Classify each property as mapped, redundant, constant, compiler-only, or genuinely unexplained.
4. Create a controlled Icon Composer fixture only for a property that remains independently variable and unexplained.

This avoids building synthetic experiments for accessors that merely mirror another authored control or have never carried a meaningful value.

## Completion criteria

Every listed property has a documented classification. Any property with an independently observable current authored meaning is either mapped and regression-tested or recorded as unrepresentable.
