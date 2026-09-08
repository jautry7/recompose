# Icon Stack Recompilation Audit

> This audit was conducted by Codex on September 6, 2026 against Recompose commit `defc255016e0d8f111b402784a4aaf16eabc7eb1`. It studies direct application-level `Assets.car` catalogs from a broad corpus of Apple and third-party macOS applications. Each discovered `IconImageStack` was reconstructed as an editable `.icon` document, compiled in a fresh copy of the CompilerTest app, extracted again from the resulting `Assets.car`, and compared with its original stack.
>
> The findings are empirical observations from this corpus and the tested Apple toolchain. They are not official Apple documentation. A structural match does not prove pixel-perfect rendered fidelity, and a structural difference does not by itself prove a visible difference.

## Summary results

“Exact structural match” means that all normalized rendering fields matched and every corresponding extracted artwork file was byte-identical. Compiler-generated names, source paths, rendition names, data-representation filenames, and encoded byte-length fields were excluded from the structural comparison. The `Assets.car` files themselves were not compared byte-for-byte.

The CAR compiler value comes directly from each catalog's `AssetStorageVersion` metadata; it is not inferred from the app version. Of the 110 retained catalogs, 69 report Xcode 27, 35 report Xcode 26, and 6 report an older Xcode generation.

| App | CAR compiler | Icon stack | Result |
|---|---|---|---|
| 1Password v8.12.34 | Xcode 26.2 (17C52) | `Icon` | Differences — Tinted inheritance; fill encoding |
| Activity Monitor v10.14 | Xcode 27.0 (27A200c) | `AppIcon` | Differences — geometry rounding; artwork re-encoded |
| Adobe Acrobat v26.001.21691 | Xcode 26.0.1 (17A400) | — | No `IconImageStack` found |
| Adobe After Effects 2026 v26.3.0 | — | — | No direct `Assets.car` found |
| Adobe Illustrator v30.8.1 | — | — | No direct `Assets.car` found |
| Adobe Media Encoder 2026 v26.3.2 | — | — | No direct `Assets.car` found |
| Adobe Photoshop 2026 v27.10.0 | — | — | No direct `Assets.car` found |
| Adobe Premiere Pro 2026 v26.3.2 | — | — | No direct `Assets.car` found |
| Adobe XD v61.0.12.1 | Xcode 12.2 (12B45b) | — | No `IconImageStack` found |
| AirPort Utility v6.3.9 | Xcode 27.0 (27A200c) | `AppIcon` | Exact structural match |
| Amphetamine v5.3.2 | Xcode 15.0.1 (15A507) | — | No `IconImageStack` found |
| App Store v3.0 | Xcode 27.0 (27A200c) | `AppIcon` | Differences — artwork re-encoded |
| AppCleaner v3.6.8 | Xcode 14.2 (14C18) | — | No `IconImageStack` found |
| Apps v1.0 | Xcode 27.0 (27A200c) | `AppIcon` | Differences — fill encoding |
| Asset Catalog Tinkerer v2.9 | Xcode 16.0 (16A5211f) | — | No `IconImageStack` found |
| Audio MIDI Setup v3.9 | Xcode 27.0 (27A200c) | `AppIcon` | Exact structural match |
| Automator v2.10 | Xcode 27.0 (27A200c) | `AppIcon` | Differences — Tinted inheritance; effects |
| Automator v2.10 | Xcode 27.0 (27A200c) | `AutomatorService` | Exact structural match |
| Automator v2.10 | Xcode 27.0 (27A200c) | `Speech` | Differences — Tinted inheritance; fill encoding |
| Bluetooth File Exchange v9.0 | Xcode 27.0 (27A200c) | `AppIcon` | Differences — fill encoding |
| Books v9.0 | Xcode 27.0 (27A200c) | `AppIcon` | Exact structural match |
| Calculator v12.0 | Xcode 27.0 (27A200c) | `AppIcon` | Differences — Tinted inheritance; effects |
| Calendar v27.0 | Xcode 27.0 (27A200c) | `AppIcon` | Differences — Tinted inheritance; fill encoding; effects |
| ChatGPT.app v26.901.51231 | Xcode 26.6 (17F113) | `Icon` | Differences — Tinted inheritance |
| Chess v3.18 | Xcode 27.0 (27A200c) | `AppIcon` | Exact structural match |
| Clock v1.1 | Xcode 27.0 (27A200c) | `AppIcon` | Differences — Tinted inheritance; fill encoding |
| ColorSync Utility v12.2.0 | Xcode 27.0 (27A200c) | `AppIcon` | Differences — artwork re-encoded |
| Compressor Creator Studio v5.3 | Xcode 26.4 (17E192) | `AppIcon` | Exact structural match |
| Console v1.1 | Xcode 27.0 (27A200c) | `AppIcon` | Exact structural match |
| Contacts v14.0 | Xcode 27.0 (27A200c) | `Contacts` | Differences — Tinted inheritance; fill encoding; effects |
| Creative Cloud v6.10.0.253 | Xcode 26.2 (17C52) | — | No `IconImageStack` found |
| DaisyDisk v4.34.2 | Xcode 26.6 (17F113) | `DaisyDisk` | Differences — Tinted inheritance |
| Developer v11.0.2 | Xcode 26.2 (17C52) | `AppIcon-Release` | Differences — fill encoding |
| Dictionary v2.3.0 | Xcode 27.0 (27A200c) | `AppIconLoc` | Differences — scale metadata |
| Digital Color Meter v6.11 | Xcode 27.0 (27A200c) | `AppIcon` | Differences — Tinted inheritance |
| Disk Utility v22.7 | Xcode 27.0 (27A200c) | `AppIcon` | Differences — Tinted inheritance; effects |
| Dropbox v269.4.4231 | Xcode 16.3 (16E140) | — | No `IconImageStack` found |
| FaceTime v36 | Xcode 27.0 (27A200c) | `AppIcon` | Differences — Tinted inheritance; effects |
| Figma v126.8.18 | Xcode 26.6 (17F113) | `Icon` | Differences — Tinted inheritance; fill encoding |
| Final Cut Pro Creator Studio v12.3 | Xcode 26.4 (17E192) | `AppIcon` | Exact structural match |
| FindMy v5.0 | Xcode 27.0 (27A200c) | `AppIcon` | Differences — Tinted inheritance; effects |
| Firefox v152.0.6 | Xcode 26.0.1 (17A400) | `AppIcon` | Differences — Tinted inheritance; fill encoding |
| Font Book v11.0 | Xcode 27.0 (27A200c) | `fontbook` | Differences — Tinted inheritance; scale metadata |
| Freeform v5.0 | Xcode 27.0 (27A200c) | `AppIcon` | Differences — fill encoding |
| Games v1.0 | Xcode 27.0 (27A200c) | `AppIcon` | Differences — Tinted inheritance |
| GarageBand v10.4.14 | Xcode 26.0 (17A324) | `AppIcon` | Exact structural match |
| GitHub Desktop v3.6.4 | Xcode 26.2 (17C52) | `icon-logo` | Exact structural match |
| Google Chrome v152.0.7977.77 | Xcode 26.0 (17A5285i) | `AppIcon` | Exact structural match |
| Grapher v2.8 | Xcode 27.0 (27A200c) | `Grapher` | Differences — Tinted inheritance; effects |
| Home v11.0 | Xcode 27.0 (27A200c) | `AppIcon` | Exact structural match |
| Icon Composer v2.0 | Xcode 27.0 (27A5252e) | `AppIcon` | Exact structural match |
| Image Capture v8.0 | Xcode 27.0 (27A200c) | `AppIcon` | Differences — geometry rounding; artwork re-encoded |
| Image Playground v1.0 | Xcode 27.0 (27A200c) | `AppIcon` | Exact structural match |
| iMovie v10.4.4 | Xcode 26.2 (17C52) | `iMovieAppIcon` | Differences — Tinted inheritance; effects |
| iPhone Mirroring v2.0 | Xcode 27.0 (27A200c) | `AppIcon` | Differences — Tinted inheritance; effects |
| Journal v3.0 | Xcode 27.0 (27A200c) | `AppIcon` | Exact structural match |
| Keka v1.6.7 | Xcode 26.0.1 (17A400) | `Keka` | Differences — artwork re-encoded |
| Keynote Creator Studio v15.3.1 | Xcode 26.4 (17E192) | `AppIcon` | Exact structural match |
| Logic Pro Creator Studio v12.3.1 | Xcode 26.0 (17A324) | `AppIcon` | Differences — layer omitted |
| Mactracker v8.2.3 | Xcode 26.2 (17C52) | `MactrackerIcon` | Differences — Tinted inheritance; fill encoding; artwork re-encoded |
| Magnifier v1.0 | Xcode 27.0 (27A200c) | `AppIconMac` | Exact structural match |
| Mail v16.0 | Xcode 27.0 (27A200c) | `ApplicationIcon` | Differences — Tinted inheritance; effects |
| MainStage Creator Studio v4.3.1 | Xcode 26.0 (17A324) | `MainStageCS` | Exact structural match |
| Maps v3.0 | Xcode 27.0 (27A200c) | `AppIcon` | Differences — Tinted inheritance; effects; artwork re-encoded |
| Messages v26.0 | Xcode 27.0 (27A200c) | `AppIcon` | Differences — Tinted inheritance; effects |
| Microsoft Excel v16.112.3 | Xcode 26.4.1 (17E202) | `Excel_macOS` | Exact structural match |
| Microsoft Excel v16.112.3 | Xcode 26.4.1 (17E202) | `PrideThemedAppIcon` | Exact structural match |
| Microsoft PowerPoint v16.112.3 | Xcode 26.4.1 (17E202) | `Powerpoint_macOS` | Differences — Tinted inheritance; fill encoding |
| Microsoft PowerPoint v16.112.3 | Xcode 26.4.1 (17E202) | `PrideThemedAppIcon` | Differences — Tinted inheritance; fill encoding |
| Microsoft Word v16.112.3 | Xcode 26.4.1 (17E202) | `PrideThemedAppIcon` | Exact structural match |
| Microsoft Word v16.112.3 | Xcode 26.4.1 (17E202) | `Word_macOS` | Exact structural match |
| Migration Assistant v1.0 | Xcode 27.0 (27A200c) | `AppIcon` | Exact structural match |
| Mission Control v1.2 | Xcode 27.0 (27A200c) | `AppIcon` | Exact structural match |
| Motion Creator Studio v6.3 | Xcode 26.4 (17E192) | `AppIcon` | Exact structural match |
| Music v1.7 | Xcode 27.0 (27A200c) | `AppIcon` | Exact structural match |
| News v12.0 | Xcode 27.0 (27A200c) | `AppIcon` | Exact structural match |
| Notes v4.13 | Xcode 27.0 (27A200c) | `AppIcon` | Exact structural match |
| Numbers Creator Studio v15.3.1 | Xcode 26.4 (17E192) | `AppIcon` | Differences — Tinted inheritance; artwork re-encoded |
| OneDrive v26.153.0809 | Xcode 26.0 (17A324) | — | No `IconImageStack` found |
| Pages Creator Studio v15.3.1 | Xcode 26.4 (17E192) | `AppIcon` | Exact structural match |
| Paprika Recipe Manager 3 v3.8.4 | Xcode 26.2 (17C52) | — | No `IconImageStack` found |
| Passwords v3.0 | Xcode 27.0 (27A200c) | `AppIconUpdated` | Exact structural match |
| Phone v1.0 | Xcode 27.0 (27A200c) | `AppIcon` | Differences — Tinted inheritance; effects |
| Photo Booth v13.1 | Xcode 27.0 (27A200c) | `AppIcon` | Exact structural match |
| Photos v12.0 | Xcode 27.0 (27A200c) | `AppIcon` | Differences — Tinted inheritance |
| Pixelmator Pro Creator Studio v4.3 | Xcode 26.4 (17E192) | `PixelmatorPro` | Differences — fill encoding; artwork re-encoded |
| Plex Media Server v1.43.3 | — | — | No direct `Assets.car` found |
| Podcasts v1.1.0 | Xcode 27.0 (27A200c) | `AppIcon` | Differences — Tinted inheritance |
| Preview v11.0 | Xcode 27.0 (27A200c) | `AppIcon` | Differences — artwork re-encoded |
| Print Center v1.0 | Xcode 27.0 (27A200c) | `AppIcon` | Exact structural match |
| QuickTime Player v10.5 | Xcode 27.0 (27A200c) | `AppIcon` | Exact structural match |
| Recompose v1.0 | Xcode 27.0 (27A5252f) | `recompose-new` | Differences — Tinted inheritance; fill encoding |
| Reminders v7.0 | Xcode 27.0 (27A200c) | `AppIcon` | Differences — Tinted inheritance; effects |
| Screen Sharing v7.0 | Xcode 27.0 (27A200c) | `AppIcon` | Differences — Tinted inheritance; fill encoding; effects |
| Screenshot v1.0 | Xcode 27.0 (27A200c) | `AppIcon` | Differences — Tinted inheritance; geometry rounding; effects |
| Script Editor v2.11 | Xcode 27.0 (27A200c) | `AppIcon` | Differences — Tinted inheritance; effects; artwork re-encoded |
| SF Symbols Beta v8.0 | Xcode 27.0 (27A193b) | `AppIcon` | Exact structural match |
| Shortcuts v10.0 | Xcode 27.0 (27A200c) | `AppIcon` | Exact structural match |
| Siri AI v1.0 | Xcode 27.0 (27A200c) | `AppIcon` | Differences — Tinted inheritance; effects; artwork re-encoded |
| Siri v1.0 | Xcode 27.0 (27A200c) | `AppIcon` | Differences — Tinted inheritance; artwork re-encoded |
| Sketch v2026.2.1 | Xcode 26.4 (17E192) | `app` | Exact structural match |
| Spotify v1.2.98.301 | Xcode 26.0 (17A5295f) | `AppIcon` | Differences — Tinted inheritance; geometry rounding; effects |
| Stickies v10.3 | Xcode 27.0 (27A200c) | `AppIcon` | Exact structural match |
| Stocks v8.0 | Xcode 27.0 (27A200c) | `AppIcon` | Exact structural match |
| Suspicious Package v4.6.2 | Xcode 15.2 (15C500b) | — | No `IconImageStack` found |
| System Information v11.0 | Xcode 27.0 (27A200c) | `ASP` | Differences — Tinted inheritance; geometry rounding; effects |
| System Settings v1.0 | Xcode 27.0 (27A200c) | `Settings` | Exact structural match |
| Terminal v2.15 | Xcode 27.0 (27A200c) | `Terminal` | Exact structural match |
| TextEdit v1.21 | Xcode 27.0 (27A200c) | `AppIcon` | Exact structural match |
| The Unarchiver v4.3.9 | — | — | No direct `Assets.car` found |
| Time Machine v1.3 | Xcode 27.0 (27A200c) | `AppIcon` | Differences — fill encoding |
| Tips v27.0 | Xcode 27.0 (27A200c) | `AppIcon` | Differences — Tinted inheritance; effects |
| Transmission v4.1.3 | Xcode 26.6 (17F113) | `Transmission_Tahoe` | Differences — Tinted inheritance; fill encoding; effects |
| TV v1.7 | Xcode 27.0 (27A200c) | `AppIcon` | Differences — artwork re-encoded |
| Typora v1.14.8 | Xcode 26.6 (17F113) | `AppIcon` | Differences — artwork re-encoded |
| Visual Studio Code v1.136.1 | — | — | No direct `Assets.car` found |
| VLC v3.0.23 | — | — | No direct `Assets.car` found |
| VoiceMemos v4.0 | Xcode 27.0 (27A200c) | `VoiceMemosApp` | Exact structural match |
| VoiceOver Utility v10 | Xcode 27.0 (27A200c) | `AppIcon` | Differences — Tinted inheritance; fill encoding |
| Weather v6.0 | Xcode 27.0 (27A200c) | `AppIcon` | Differences — Tinted inheritance; effects |
| WhatsApp v26.30.77 | Xcode 26.6 (17F113) | `AppIcon` | Differences — Tinted inheritance; fill encoding |
| xattred v1.7 | Xcode 26.0.1 (17A400) | `xattred` | Differences — Tinted inheritance; fill encoding |
| Xcode Beta v27.0 | Xcode 27.0 (27A5252e) | `XcodeBeta` | Exact structural match |
| Xcode Beta v27.0 | Xcode 27.0 (27A5252e) | `XcodeCloud` | Differences — Tinted inheritance; effects |
| Xcode Beta v27.0 | Xcode 27.0 (27A5252e) | `XcodeIntelligence` | Differences — Tinted inheritance; fill encoding |
| Xcode v26.6 | Xcode 26.6 (17F112) | `Xcode` | Differences — Tinted inheritance; effects |
| Xcode v26.6 | Xcode 26.6 (17F112) | `XcodeCloud` | Exact structural match |
| Xcode v26.6 | Xcode 26.6 (17F112) | `XcodeIntelligence` | Differences — Tinted inheritance; fill encoding |

## Headline results

- 110 direct `Assets.car` files were inspected.
- 100 catalogs contained at least one `IconImageStack`; 10 contained none.
- 109 logical icon stacks were found.
- All 109 stacks reconstructed successfully.
- All 109 reconstructed `.icon` documents contained valid JSON and every referenced asset.
- All 109 documents compiled successfully after a clean build in an isolated CompilerTest project and DerivedData directory.
- All 109 resulting `Assets.car` files exposed a readable compiled `AppIcon` stack.
- 44 stacks were exact structural matches with byte-identical extracted artwork.
- 7 additional stacks had matching normalized rendering fields but at least one changed artwork file.
- 48 stacks had rendering-field differences while all corresponding artwork files remained byte-identical.
- 10 stacks had both rendering-field and artwork differences.

These categories total 109. In aggregate, 51 stacks had no normalized rendering-field difference and 58 had at least one. No source catalog, application bundle, Recompose source file, or test fixture was changed during the run.

## Method

The run used Recompose's logical stack discovery rather than assuming an asset named `AppIcon`. Every discovered stack was processed independently:

1. Copy the direct application `Contents/Resources/Assets.car` into task-scoped temporary storage.
2. Run `recompose list --json` and enumerate every logical `IconImageStack` name.
3. Reconstruct one named stack into a `.icon` document.
4. Validate `icon.json` and confirm that every referenced asset exists.
5. Copy the CompilerTest project, replace its `AppIcon.icon` with that one reconstruction, and assign a unique DerivedData directory.
6. Run an Xcode `clean build` so neither the project copy nor build products can reuse a previously compiled icon.
7. Copy the newly compiled `Assets.car`, extract its `AppIcon`, and compare it with the original stack using the same CoreUI-backed extractor.

All reconstructed documents were compiled with Xcode 27.0 beta build `27A5252f`, running on macOS 27.0 build `26A5425a`. The stable Xcode installed alongside it could not open the current CompilerTest project format, so it was not used for this audit. Consequently, rows whose original CAR reports Xcode 26 or earlier cross a compiler-generation boundary, while rows reporting Xcode 27 provide a closer same-generation comparison.

The comparison retained canvas, appearance, layer and group structure; frames and image sizes; opacity; blend modes; fills; shadows; translucency; refraction; lighting and specular properties; rendition class and semantic flags; and color/gradient values. It excluded identity and encoding fields that necessarily change when the logical stack is renamed to `AppIcon` and compiled into a new catalog.

Extracted artwork was compared by SHA-256 at matching appearance/group/leaf slots. Changed raster files were also decoded to RGBA for sample-level comparison. This checks the recovered payloads, not the unavailable pre-CAR developer source files.

## Finding 1: omitted Tinted specializations inherit from Light, not Dark

This is the dominant and most consequential result.

The current specialization writer omits a Tinted value when that value matches Dark. The recompiled evidence shows that an omitted specialization resolves to the document's default value, which is represented by Light in these documents—not Dark.

Across 48 stacks, 162 changed fields in the compiled Tinted appearance exactly matched the compiled Light value while differing from the source Tinted value. The affected fields included:

- layer and group opacity
- blend mode
- shadow style and opacity
- specular placement
- specular and lighting flags
- fills

ChatGPT.app supplies an additional, especially clear asset-level case. Its source Tinted slot uses the dark `Blossom` artwork, but the recompiled Tinted slot inherits the Light artwork. Its other normalized fields match, so this case is visible only when the source payload assigned to the slot is compared.

Taken together, 49 of 109 stacks show direct evidence of the same inheritance problem. The interpretation is strong because the compiled result repeatedly chooses Light/default across unrelated applications and property types. The effect and opacity differences grouped under Finding 3 are downstream manifestations of this same behavior. Correcting the specialization writer may therefore eliminate Finding 3 entirely, although the audit must be rerun after the change to confirm that no independent effect-mapping problem remains. No code change was made in response.

## Finding 2: one-stop gradients do not preserve their original representation

Twenty-four stacks showed at least one fill-related manifest difference. Two closely related patterns occurred:

1. In 11 stacks, a root `CUINamedGradient` containing one color and one stop recompiled as `CUINamedColor`. The underlying rendition class changed from `_CUIThemeNamedColorGradientRendition` to `_CUIThemeColorRendition`, and its CoreUI type changed from 1021 to 1009.
2. In other groups, a source one-stop gradient in the material channel recompiled as the same color in the solid-color channel, leaving the gradient channel null.

The color components were retained in these transitions, but Recompose never wrote a literal one-stop gradient into the reconstructed document. Its fill conversion treated a source gradient containing one color as semantically equivalent to a solid and serialized a `solid` value into `icon.json`. The representation therefore changed before Xcode compiled the document.

That was a semantic inference by the reconstruction pipeline rather than an exact encoding of the extracted data. It is a likely straightforward code correction if the current `.icon` format accepts a one-stop `linear-gradient`: preserve the gradient record, including its orientation, instead of converting it to a solid. A focused probe is still needed because the source CARs span compiler generations; Xcode 27 may accept and preserve that literal representation, canonicalize it back to a solid, or reject it. Until that is tested, this finding is evidence of a Recompose serialization miss, not proof of a compiler limitation.

## Finding 3: effects and material values fall back or remap

Twenty-six stacks differed in one or more effect-related fields. Across the corpus, the changed properties were:

| Property | Affected stacks | Field occurrences |
|---|---:|---:|
| Specular placement | 11 | 16 |
| Blend mode | 8 | 9 |
| Shadow style | 6 | 6 |
| Lighting effects | 4 | 5 |
| Specular enabled | 3 | 3 |
| Shadow opacity | 3 | 3 |

All 42 effect-field occurrences in this table were confined to the Tinted appearance. Opacity likewise changed in 18 stacks and 36 field occurrences, all in Tinted. The common opacity transitions were 0→1 and 1→0, but the corpus also contained partial-value changes such as 1→0.95, 0.5→0.2, and 0.8→0.9.

These values describe how Icon Composer renders and composites each group: blend mode controls compositing, specular placement controls where the highlight appears, lighting determines whether elements gather highlights individually or as a combined group, and shadow values control the group's shadow treatment. They are serialized through the same appearance-specialization helper as image names and opacity.

The audit therefore does not currently support treating Finding 3 as an independent mapping defect. When a source Tinted effect matches Dark, Recompose omits it; the compiler then inherits the Light/default effect instead. This explains why transitions occur in both directions rather than converging on one constant default. Fixing Finding 1 may fix every difference summarized here, but a post-fix recompilation audit is required before closing Finding 3.

## Finding 4: five stacks show one-point frame rounding

Five stacks recompiled with one-point coordinate or size differences:

| App | Source → compiled |
|---|---|
| Spotify | frame origin x/y 100→99 |
| Image Capture | y 219→218 and height 585→586 |
| Activity Monitor | y -496→-497 and height 2228→2229 |
| Screenshot | x 99→98 and y 70→69 |
| System Information | y 294→293 |

The repeated negative-one shift suggests an asymmetry in the conversion between CoreUI frames and Icon Composer position/size values, or in compiler rounding of the reconstructed values. Recompose has to reverse-engineer authored scale and translation from CoreUI's integer origin and size plus the asset's intrinsic dimensions. It emits decimal scale values, after which Icon Composer's compiler reconstructs an integer frame. A one-point delta may therefore be an expected rounding error in Recompose's inverse calculation rather than lost source data.

This is potentially straightforward to correct once the rounding direction is understood, but the formula should not be changed from these five outcomes alone. Reserializing representative documents in Icon Composer before compilation may reveal whether the editor itself rewrites the decimal scale or translation. Focused half-point and non-square probes can then distinguish Recompose rounding from editor or compiler rounding.

Dictionary and Font Book separately changed layer scale metadata from 0 to 1 in every appearance. Their frames and source payloads remained otherwise stable. This may be compiler normalization of an implicit scale, but the exact meaning of source scale zero remains unverified.

## Finding 5: one zero-opacity SVG layer is omitted

Logic Pro Creator Studio's stack contains two SVG leaves in one group. The second is a plus-lighter glow layer with opacity zero in all three appearances. The reconstructed document contains the file and references it, but the compiler emits only the first leaf.

The compiled stack therefore has one fewer leaf in that group for Light, Dark, and Tinted. Because the omitted leaf is fully transparent in the source, its removal may have no visible effect in the current appearances. It is nevertheless genuine structural loss and would matter if the reconstructed document were edited to make that layer visible.

Recompose did encode this layer, its zero opacity, and its plus-lighter blend mode in `icon.json`; the disappearance occurs during compilation. The original Logic CAR reports Xcode 26.0 while the reconstructed document was compiled with Xcode 27.0. Dead-layer optimization by the compiler could therefore be the sole driver of this finding. Compiling the same document with both generations is the clearest next test.

## Finding 6: artwork differences have three distinct causes

The 109 source manifests contained 1,695 appearance-specific artwork slots. After recompilation:

- 1,620 slots contained byte-identical extracted files.
- 72 slots contained files with different bytes.
- 3 slots—the same Logic Pro glow SVG referenced by three appearances—were absent.

The 72 byte-different slots are not one phenomenon. They break down as follows:

- One ChatGPT.app slot switched to different artwork because of Tinted inheritance, as described in Finding 1. Its decoded pixels and alpha differ substantially.
- 68 PNG slots, representing 26 distinct source assets, retained identical dimensions and alpha. Decoded color samples differed by at most 1 on an 8-bit channel. Five of those slots were also identical after premultiplication. This is consistent with color-model conversion or quantization during recompilation, but remains a real pixel-data difference.
- Three Typora slots reference the same SVG. The only textual change was removal of an empty `<defs/>` element, which is structurally different but should be rendering-neutral.

The ChatGPT.app difference belongs to Finding 1 rather than to a general artwork-rewriting problem. Typora's change is structural SVG canonicalization with no expected rendering consequence. The remaining differences are color-sample changes in raster artwork.

The small PNG changes occurred in Keka, Mactracker, Numbers Creator Studio, Pixelmator Pro Creator Studio, App Store, Image Capture, Maps, Preview, Siri AI, Siri, TV, Activity Monitor, ColorSync Utility, and Script Editor. Recompose copied the extracted source files into each `.icon` package without intentionally replacing or normalizing them. The changes could be compiler-side color-model conversion or quantization, but the audit has not yet ruled out a simpler Recompose miss: color-space or source-representation information needed for exact recompilation may exist outside the copied payload and may not have been encoded into `icon.json`. Because affected apps include CARs authored by both Xcode 26 and Xcode 27, a 26→27 compiler transition cannot be the sole explanation.

## Exact-match observations

The 44 exact structural matches span both Apple and third-party software, raster and vector content, and standard and nonstandard logical stack names. They include the pilot's News and Print Center cases, which again produced no normalized field differences and byte-identical corresponding artwork.

The exact group also includes multi-stack catalogs: both Microsoft Excel stacks, both Microsoft Word stacks, Xcode 26's `XcodeCloud`, Xcode 27 beta's `XcodeBeta`, and Automator's `AutomatorService`. This helps rule out catalog multiplicity or a nonstandard stack name as a general cause of recompilation drift.

An exact result is deliberately narrower than “visually identical.” It establishes that the current extractor observes the same retained rendering model and payload bytes on both sides of the compilation. It does not independently render the two stacks or prove that the extractor exposes every private compiler behavior.

## Catalogs without a tested stack

Ten readable direct catalogs contained no discoverable `IconImageStack`: Adobe Acrobat, Adobe XD, Amphetamine, AppCleaner, Asset Catalog Tinkerer, Dropbox, OneDrive, Paprika Recipe Manager 3, Suspicious Package, and Creative Cloud.

Nine in-scope main application bundles had no direct `Contents/Resources/Assets.car`: Adobe After Effects 2026, Adobe Illustrator, Adobe Media Encoder 2026, Adobe Photoshop 2026, Adobe Premiere Pro 2026, Plex Media Server, The Unarchiver, VLC, and Visual Studio Code.

These results do not imply that the applications lack icons or other icon resources; only that they lacked an in-scope direct catalog stack for this test.

## Interpretation and next validation boundary

The audit demonstrates that the reconstruction is mechanically robust across this corpus: every discovered stack produced a valid document, compiled from a clean state, and could be read back. It also shows that mechanical validity is not fidelity. The strongest cross-cutting fidelity issue is Tinted inheritance, followed by fill representation and effect-property mappings.

No implementation changes were made and none of the differences above have been adjudicated as acceptable. The next useful step is visual triage, using this report to choose representative icons from each difference family rather than reviewing all 109 indiscriminately. That visual evidence can then distinguish compiler canonicalization from changes that affect appearance.
