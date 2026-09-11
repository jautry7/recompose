# v26 specular behavior under Xcode 27

- Status: open
- Priority: 1

## Problem

The September 11, 2026 recompilation regression audit found a cross-generation specular difference in Spotify. Its source CAR reports Xcode 26.0 and resolves the tested group with specular enabled in Light but explicitly disabled in Dark and Tinted.

Recompose correctly emits a v26 document with the enabled legacy base represented by omission and Boolean `false` specializations for Dark and Tinted. Xcode 27.0 build `27A266a` nevertheless recompiles both specialized appearances with specular enabled. Forcing the same reconstruction to v27 changes the enabled base to `"automatic"` while retaining the two `false` specializations, and Xcode 27 then preserves all three source states.

This may be an Xcode 27 compatibility change rather than a Recompose serialization defect. One hypothesis is that Golden Gate applies specular treatment more aggressively to Tahoe-era or legacy icons unless a v27 document explicitly opts out. The user's separate observation that flat Adobe icons without direct CARs receive apparent specular highlights under Golden Gate suggests a potentially broader system-presentation policy, but that behavior is not yet connected to the compiled Spotify result.

## Evidence boundary

- The confirmed evidence is a CoreUI read-back comparison of Spotify's source CAR, its automatically selected v26 reconstruction compiled by Xcode 27, and a forced-v27 control compiled by Xcode 27.
- The v26 document contains the expected Boolean `false` values; the difference appears after Xcode 27 compilation.
- A new Xcode 26 comparison was inconclusive because the current CompilerTest project uses an Xcode 27 project format. A mechanically downgraded task-local copy opened in Xcode 26.6, but `actool` crashed while selecting the Icon Composer item.
- No Finder or system-renderer comparison was performed during the regression audit.
- Apparent specular treatment of applications without a direct CAR may occur in a separate legacy-icon presentation path and must not be treated as evidence about `IconImageStack` compilation without a controlled comparison.

## Investigation

1. Compile the same reconstructed Spotify v26 document under Xcode 26.6 using a known-compatible test project, then extract and compare its Light, Dark, and Tinted specular states.
2. Build a minimal authored matrix covering an omitted enabled legacy value, Boolean `false` at the base, and appearance-specific Boolean `false`; compile it with both Xcode 26.6 and Xcode 27.
3. Compare v26 and v27 outputs under CoreUI read-back and the same Finder or system renderer on Tahoe and Golden Gate.
4. Test representative flat applications without a direct CAR separately to determine whether Golden Gate adds highlights through a legacy-icon presentation treatment rather than asset-catalog compilation.
5. Determine whether the result is Xcode 27 canonicalization, a Golden Gate runtime override, an authored-format compatibility rule, or a Recompose generation-classification problem before changing automatic generation selection.

## Completion criteria

- Appearance-specific disabled specular behavior is established for v26 documents under both Xcode 26 and Xcode 27.
- Compiler output is distinguished from Finder or system-renderer treatment on Tahoe and Golden Gate.
- The no-CAR legacy-icon observation is either connected to the same policy with controlled evidence or classified as a separate presentation path.
- Recompose either preserves the current earliest-compatible generation rule with the limitation documented or changes it based on a reproducible format requirement.
- The decided behavior has a focused regression fixture.
