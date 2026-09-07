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

## Interpretation

The Tahoe and Golden Gate tests produced the same boundary:

| Representation | Icon Composer 1.5 / Xcode 26.5 | Golden Gate tools / Xcode 27 beta |
|---|---|---|
| Literal one-stop `linear-gradient` | Rejected | Rejected |
| Two identical endpoint colors | Opened and compiled | Opened and compiled |

This rules out the Xcode 26-to-27 compiler transition as the cause of the audited difference. It also rules out the idea that Icon Composer accepts a one-stop value but merely presents or serializes it differently. In both public toolchains, the one-stop array is invalid at the editable-document boundary.

The tests do not reveal which tool(s) originally emitted the one-stop CoreUI records. They do show that those records cannot be reproduced by either tested public `.icon` toolchain. Their presence in shipping CARs must therefore be treated as a relic of an internal or prototype authoring or compilation tool, rather than as a representation available through the public Icon Composer format.

## Reconstruction decision

Recompose will reconstruct a source one-stop gradient as a valid two-stop gradient with identical endpoint colors. It will preserve the source gradient's type, color, channel, and orientation rather than converting it to a solid fill.

This representation is semantically faithful and retains gradient identity throughout the editable document and the compiled CAR. It cannot produce exact structural equality with the source: the recompiled gradient necessarily contains stops at 0 and 1 instead of the source's single stop. That remaining one-versus-two-stop delta is a limitation of the public `.icon` format established by the tested toolchains, not a semantic conversion performed by Recompose.
