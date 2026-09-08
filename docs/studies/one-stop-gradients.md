# One-Stop Gradients

> This study was conducted by Codex on September 7, 2026 following the icon-stack recompilation audit. It documents an empirical investigation into whether a compiled one-stop CoreUI gradient can be reconstructed through the public Icon Composer `.icon` format. The behavior described here was observed with the tested Apple tools and is not official Apple documentation.

## Purpose

Recompose reconstructs editable Icon Composer documents from compiled `IconImageStack` renditions. Some source stacks contain gradients with only one color and one stop. The recompilation audit found that Recompose converted those records into solid fills, changing both their editable representation and their compiled CoreUI rendition type.

This study tested whether the public `.icon` format can encode the source representation directly and, if not, which valid representation most faithfully preserves its meaning.

## Initial audit finding

The recompilation audit found fill-related differences in 24 stacks. One recurring pattern affected 11 root fills: a source `CUINamedGradient` containing one color and one stop recompiled as a `CUINamedColor`. The rendition class changed from `_CUIThemeNamedColorGradientRendition` to `_CUIThemeColorRendition`, and the CoreUI type changed from 1021 to 1009.

A related pattern occurred in material fills. A source one-stop gradient in the material channel recompiled with the same color in the solid-color channel and a null gradient channel.

The color components survived, but the gradient representation did not. Inspection of Recompose showed that this happened before compilation: the reconstruction pipeline treated a one-stop gradient as semantically equivalent to a solid fill and wrote `solid` into `icon.json`. Recompose had inferred an equivalent visual meaning instead of retaining the extracted data's gradient identity and orientation.

The initial proposed correction was to write a literal one-stop `linear-gradient`. Because the audited source CARs spanned compiler generations, it was not yet known whether the public format accepted that representation or whether a newer compiler had stopped supporting it.

## Golden Gate probe

A controlled `.icon` document was constructed with a root `linear-gradient` containing one color. Icon Composer in the tested Golden Gate toolchain refused to open the document. Xcode 27.0 beta build `27A5252f` also refused to compile it.

A second document represented the same fill as a two-stop gradient whose endpoint colors were identical. Icon Composer opened this document, and Xcode compiled it successfully. The resulting CAR retained a named gradient with two references to the same color, stops at 0 and 1, and the authored orientation.

This established that a duplicated-color gradient was valid under the newer toolchain, but it left open the possibility that rejection of the literal one-stop representation was a Golden Gate change.

## Tahoe probe

Manual user testing repeated the experiment on a separate Tahoe system with the following environment:

- macOS Tahoe 26.6.2
- Xcode 26.5
- Icon Composer 1.5

Icon Composer 1.5 was selected because it was the latest release from before WWDC 2026 and therefore predated Golden Gate support.

The test used the same two representations:

- `one-stop-gradient.icon`, containing one color in `linear-gradient`
- `two-red-stops.icon`, containing the same red color at both endpoints

Icon Composer 1.5 refused to open the one-stop document. Xcode 26.5 refused to compile it and reported the following underlying `actool` exception:

```text
Exception while running actool: *** -[__NSPlaceholderArray initWithObjects:count:]: attempt to insert nil object from objects[0]
```

Icon Composer 1.5 opened the two-stop document successfully. Manual user verification confirmed that the fill appeared in the document. Reserializing the document through Icon Composer produced an `icon.json` file with the same SHA-256 digest as the input, demonstrating that the editor preserved the duplicated endpoint colors exactly rather than normalizing them into a solid:

```json
{
  "fill" : {
    "linear-gradient" : [
      "extended-srgb:1.00000,0.21961,0.23529,1.00000",
      "extended-srgb:1.00000,0.21961,0.23529,1.00000"
    ]
  }
}
```

Xcode 26.5 compiled the original two-stop document successfully. The resulting CAR identified its toolchain as `Xcode 26.5 (17F42)` and contained the following named-gradient data for the default appearance:

```text
Gradient Colors: [Color-2, Color-2]
Gradient Stops: [0, 1]
Gradient Start/Stop: 0.500,0.000 - 0.500,1.000
Gradient Type: 1
```

The compiler therefore retained a gradient with two identical endpoint colors. It did not collapse the gradient into a solid or optimize it into a one-stop record.

### Updated Tahoe toolchain control

A later test repeated the Tahoe experiment with Icon Composer 1.6 and Xcode 26.6 build `17F113` on the same macOS Tahoe 26.6.2 system. This was necessary because Icon Composer 1.6 had added awareness of newer document features. When given the Golden Gate one-stop probe, it identified `refractivity` and `specular-location` as features from a newer Icon Composer version instead of producing the generic format error shown by Icon Composer 1.5. That message explained the incompatibility more precisely, but the Golden Gate document could not isolate gradient cardinality under the updated Tahoe tools.

Manual human experimentation in Icon Composer 1.6 therefore produced a new native control document. Its background contained two identical blue gradient entries, and its single image layer contained two identical purple gradient entries. A probe copy was made by deleting only one entry from the background gradient. The layer gradient and referenced PNG were left unchanged.

Icon Composer 1.6 rejected the one-stop probe, and Xcode 26.6 refused to compile it. The untouched two-stop control opened and compiled successfully. Its resulting CAR reported `Xcode 26.6 (17F113) via AssetCatalogAgent-AssetRuntime` and contained the expected icon stack.

As a final single-variable confirmation, user testing edited the rejected probe's enclosed `icon.json` in place inside the Xcode project. The sole background color was copied onto a second line and separated with a comma. With no other document change, the icon immediately opened in Icon Composer 1.6 and compiled as expected. This directly tied acceptance to the presence of two gradient entries rather than to unrelated schema, asset, or project differences.

## Interpretation

The Tahoe and Golden Gate tests produced the same boundary:

| Representation | Icon Composer 1.5 / Xcode 26.5 | Icon Composer 1.6 / Xcode 26.6 | Icon Composer 2.0 beta / Xcode 27 beta |
|---|---|---|---|
| Literal one-stop `linear-gradient` | Rejected | Rejected | Rejected |
| Two identical endpoint colors | Opened and compiled | Opened and compiled | Opened and compiled |

This rules out the Xcode 26-to-27 compiler transition as the cause of the audited difference. It also rules out the idea that Icon Composer accepts a one-stop value but merely presents or serializes it differently. The one-stop array is invalid at the editable-document boundary in all three tested public configurations, including the final Xcode 26 and Icon Composer 1 releases.

The tests do not reveal which tool(s) originally emitted the one-stop CoreUI records. They do show that those records cannot be reproduced by either tested public `.icon` toolchain. Their presence in shipping CARs must therefore be treated as a relic of an internal or prototype authoring or compilation tool, rather than as a representation available through the public Icon Composer format.

## Reconstruction decision

Recompose will reconstruct a source one-stop gradient as a valid two-stop gradient with identical endpoint colors. It will preserve the source gradient's type, color, channel, and orientation rather than converting it to a solid fill.

This representation is semantically faithful and retains gradient identity throughout the editable document and the compiled CAR. It cannot produce exact structural equality with the source: the recompiled gradient necessarily contains stops at 0 and 1 instead of the source's single stop. That remaining one-versus-two-stop delta is a limitation of the public `.icon` format established by the tested toolchains, not a semantic conversion performed by Recompose.

Once Recompose has a version-aware Tahoe reconstruction path, the result can be checked against a shipping Xcode 26.x icon stack: reconstruct the source one-stop record into an otherwise v1-compatible document without applying the duplicate-stop normalization, then test that document directly in Icon Composer 1.6. The minimal probe predicts rejection, but the corpus-based check will confirm the boundary using an authentic v1 source after unrelated Golden Gate schema fields have been eliminated.
