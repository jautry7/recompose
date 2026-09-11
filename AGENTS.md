## Platform compatibility

- Target macOS 26 Tahoe as the minimum supported operating system.
- Do not use APIs or behavior introduced in macOS 27 Golden Gate unless an availability-gated fallback preserves full functionality on Tahoe.

## Project character

- Keep Recompose a casual, lightweight, somewhat scrappy open-source project. Maintain good repository hygiene without introducing enterprise-scale process or architecture.
- Keep the public repository lean and product-facing. Put contributor and implementation guidance in this file rather than expanding the README with internal detail.

## Documentation

- Keep documentation as light as possible. Avoid duplicate explanations, documents that must be synchronized, and unnecessary indexes or cross-reference maintenance.
- `docs/backlog/` contains one discrete project brief per active item. Delete a brief when work on that item begins; preserve settled results only in the appropriate durable specification or research record.
- `docs/specs/` contains the durable current icon-system specifications. Keep definitions with the specification that needs them rather than creating additional reference layers.
- `docs/research/` contains point-in-time research records and is not a collection of living specifications. Current v26 compatibility rules belong beside the affected v27 behavior in the two documents under `docs/specs/`; the completed Tahoe investigation is preserved in `docs/research/tahoe-support-audit.md`.
- Make only explicitly requested documentation changes. Flag stale links, inconsistencies, possible consolidation, and other adjacent cleanup for the user instead of changing them without authorization.

## Application architecture

- Build the native interface with AppKit and prefer native macOS controls, semantic colors, text styles, SF Symbols, and window behavior over custom reproductions.
- Do not recreate or imitate system window controls; let AppKit provide them.
- `RecompositionEngine.swift` is a thin Swift orchestration layer. It stages the user-selected catalog in a task-scoped temporary workspace and invokes the bundled `Contents/Helpers/recompose` executable.
- `RecomposeCLI/` owns icon-stack discovery, extraction, and `.icon` assembly in Objective-C. Preserve that responsibility boundary; do not rewrite the pipeline in Swift or substantially reorganize it without explicit approval.
- The `Recompose CLI` Xcode target builds the `recompose` helper from source for arm64 and x86_64, and the app target embeds it. Do not reintroduce checked-in helper binaries or the removed legacy `cli/` tree.
- The same `recompose` executable serves as the app's embedded helper and as an independently runnable Terminal tool. Keep one implementation built entirely through Xcode; do not introduce a second CLI implementation, a Makefile, or another build system.
- The GUI accepts either a direct `.car` file or an `.app` bundle whose catalog exists at exactly `Contents/Resources/Assets.car`. Do not broaden app-bundle discovery into a recursive package search without explicit discussion. The CLI contract remains catalog-based.
- Keep production code organized in the sibling `Recompose/` and `RecomposeCLI/` source roots. Deleted research probes remain available in Git history and should not be restored without an explicit request.
- Do not make paid Apple signing, Developer ID distribution, or notarization a prerequisite for building the app or CLI from source. Discuss changes to signing or distribution requirements explicitly.

## Terminology and CLI contract

- Use the Pipeline definitions section in `compiled-icon-stack-specs` as the source of truth for project terminology. Do not maintain competing definitions here.
- Use the public `docs/cli.md` as the source of truth for the CLI interface. Do not maintain a competing specification here.

## Reconstruction scope and evidence

- Discover logical `IconImageStack` assets by name rather than assuming `AppIcon`. Support catalogs with one, multiple, or no icon stacks; when `AppIcon` exists, the UI may prefer it as the initial selection.
- Preserve the Apple-only implementation: system tools and Apple frameworks are acceptable, while third-party runtime dependencies require explicit discussion.
- CoreUI is private and undocumented. Describe behavior as observed, audited, inferred, or documented as appropriate; do not turn corpus results into universal platform claims.
- Treat `docs/research/car-audit.md`, `docs/research/recompilation-audit.md`, and the other research documents as point-in-time evidence, not exhaustive format specifications or living documents to revise as the implementation evolves.
- Treat the human-selected CAR corpus as a living, user-curated library. The 38 icon stacks recorded in `docs/research/car-audit.md` are a point-in-time audit count, not a fixed test standard, exhaustive fixture set, or claim about the format. The user may add CAR files to the library whenever they are considered useful. When the library is available, regression-test every icon stack currently present and keep each one producing a valid `.icon`; do not confuse successful document creation with rendering fidelity.
- Codex-side reconstruction validation must stop at nonvisual structural checks: the pipeline completes without error, `icon.json` parses, and every referenced asset is present. The user validates that the document opens in Icon Composer and that every expected layer renders. Overtly absent content is a validity defect even when its layer exists in the sidebar; subtler differences in material appearance are fidelity work.
- Icon Composer's command-line tools do not work reliably in the Codex environment and cannot be used to validate reconstructed `.icon` documents. Do not invoke `ictool`, `ibtoold`, `actool` icon export, or alternate command-line variants as a workaround. Present the reconstructed `.icon` to the user and let the user perform all Icon Composer opening, rendering, and visual comparison.
- Useful focused regressions include Maps for a conventional single `AppIcon`, Microsoft Excel for multiple nonstandard names (`Excel_macOS` and `PrideThemedAppIcon`), Keka/Xcode for appearance-specific source artwork, Image Playground for group-level Screen blending, Preview for Soft Light, and Apple Developer's `AppIcon-Release` when available for Plus Darker. Diagnose discovery, extraction, and assembly separately when a full reconstruction fails.
- Icon-stack discovery is an established part of the architecture. Do not redesign it while addressing extraction, assembly, or fidelity issues unless new evidence demonstrates a discovery defect.
- Changes to discovery, extraction, appearance handling, or assembly should preserve the audited behavior across logical asset names, multiple stacks, light/dark/tinted source variants, fills, shadows, and blend modes.
- Treat blend-mode support as one format feature, not a corpus-driven list of exceptions. Icon Composer exposes exactly Normal, Darken, Multiply, Plus Darker, Lighten, Screen, Plus Lighter, Overlay, Soft Light, and Hard Light. Map the corresponding Core Graphics raw values `0`, `4`, `1`, `26`, `5`, `2`, `27`, `3`, `8`, and `9`; reject other Core Graphics modes explicitly rather than emitting invalid `.icon` values. Preserve blend modes on both groups and leaves, including appearance specializations. Group blend modes can determine whether content renders at all.
- Icon Composer natively supports appearance-specific images through `image-name-specializations`. Preserve and copy Default, Dark, and Mono/Tinted source assets rather than requiring corresponding appearance slots to share a source name or media type.
- Treat the root background fill as a special appearance case with two independent concerns. Preserve the extracted Dark root-fill specialization even when its value is identical to Default, because equality does not prove that the appearance override was absent. Preserve recognized compiled `system-light` and `system-dark` background names as the matching semantic `.icon` string presets; resolved gradient components are not equivalent substitutes. Mono/Tinted may continue to inherit the effective Dark value when its extracted background is equal. This mapping was visually validated with Image Capture in a compiled Finder-to-Finder comparison.
- Keep authoring, compiled-reference, and system-presentation evidence separate. Icon Composer preview, a flattened CAR companion, and Finder can expose different aspects of the same logical icon. Preserve semantic values before attempting numeric compensation, and use a compiled Finder-to-Finder comparison for claims about final system fidelity.
- Preserve disabled specular highlights as the Boolean value `false`. CoreUI's `hasSpecular == NO` is an explicit opt-out; the string `"none"` is not the equivalent `.icon` representation and can cause Icon Composer to apply unwanted specular highlights and dark outlines.
- Preserve raster intrinsic dimensions and derive vector intrinsic dimensions from the serialized SVG `viewBox`; do not assume vector layers are 1024×1024.
- Keep corpus observations, CoreUI runtime observations, inferences, and behavior manually validated in Icon Composer distinct. When editable-format semantics remain uncertain, the user can perform targeted Icon Composer tests.
- Do not claim that Recompose can perfectly recover an originally authored Icon Composer document; compilation may discard or transform source information.

## Fidelity and release boundary

- Do not knowingly ship overt rendering defects.
- Other known preservation gaps include P3/high-bit-depth raster alternatives and localization or layout-direction variants. Keep these distinct from document validity, and verify whether the editable `.icon` format can represent them before designing a solution.

## UI workflow

- Keep the interface small, simple, and native rather than introducing a larger navigation or view architecture without discussion.
- Preserve four outcome states: a valid catalog with no icon stack, one identified icon, multiple identified icons with an inline dropdown, and a generic processing failure. Do not treat “no icon stack” as a processing failure.
- The multiple-icon dropdown changes which icon will be saved; it is not a separate wizard step. Prefer `AppIcon` initially when present, otherwise use the stable sorted first name, and cache successfully prepared outputs.
- GUI saves use `<asset-name>-recomposed.icon`. Keep the medium AppKit popup size and the label-to-dropdown gap centralized in `Layout.assetLabelToDropdownSpacing` rather than duplicating the value.
- Success previews render the original CAR's named icon stack through the private CoreUI/IconFoundation path at 256 points and scale 2 for Default, Dark, and Tinted. Keep this optional presentation path separate from reconstruction success, and do not replace it with Quick Look, Finder thumbnails, or flattened companion assets.
- App-icon artwork and its Xcode build settings are user-owned. Do not rename, delete, replace, reinterpret, or “clean up” app-icon assets unless the user explicitly asks for that exact change.
- The user performs visual inspection of running builds. Do not request or perform visual inspection of the app unless the user explicitly asks for it.

## Working conventions

- Confirm substantial architectural, structural, or repository-organization changes before implementing them. Exploratory discussion does not make a proposal final.
- Treat discrepancies in path spelling, capitalization, staging state, repository layout, or other user-created structure as unresolved intent. Ask the user before changing or committing a discrepancy; never silently normalize it or include a guessed correction in a commit.
- When the user asks to commit a decision to project memory, says “going forward,” or otherwise establishes a durable rule, consider whether this file should also be updated. Add it only when it is useful to future repository work and appropriate for a public file; keep private or session-specific context out.
- For commits Codex creates at the user's request, preserve the user's configured identity as author, add `Co-authored-by: Codex <codex@openai.com>`, and set `Codex <codex@openai.com>` as committer with command-scoped Git configuration. Never change persistent Git identity, and verify author and committer metadata before pushing.
- A push has no separate authorship metadata. Do not rewrite a commit the user created in GitHub Desktop merely to add Codex attribution unless explicitly asked.
