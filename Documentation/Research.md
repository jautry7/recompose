# Research log

## 2026-08-30

### CoreUI surface discovery

The first probe loaded the system CoreUI framework and enumerated the Objective-C methods, properties, and instance variables exposed by classes involved in catalogs, theme renditions, named icons, layers, colors, and gradients. This established that the compiled catalog retained a structured icon layer stack rather than only a flattened bitmap.

### Catalog inspection

A focused catalog inspector then opened a supplied catalog through `CUICatalog`, requested an icon layer stack by name and appearance, and recorded the returned lookup and rendition structure as JSON. The result confirmed that an icon could be addressed as a hierarchy of groups and layers with appearance-specific renditions.

### Icon Composer runtime discovery

A second runtime probe enumerated the classes and methods in Icon Composer's bundled foundation framework. The command-line utility bundled with Icon Composer could export a rendered image, which made it useful as a document-acceptance diagnostic, but it did not expose an operation for decoding or creating an editable document. Reconstruction therefore required learning the accepted document schema and writing it directly.

### Schema candidate generation

The first schema experiment generated progressively richer `.icon` packages from a known accepted document, extracted layer assets, and a preliminary reconstruction. Each candidate added a controlled portion of the recovered structure so Icon Composer's export result could act as a binary acceptance test.

The generated documents and their copied artwork were retained as local research artifacts rather than repository fixtures.

The known-good control, a single extracted layer, all extracted layers using the safe schema, and the recovered document restricted to known keys all passed validation. The candidates containing every recovered base key and the full appearance specializations both failed with Icon Composer's generic incorrect-format error. This localized the failure to one or more additional metadata encodings rather than the extracted assets or overall package structure.

### Key-by-key schema isolation

A second generator added recovered group and layer properties one key at a time. Group name, opacity, specular placement, lighting, layer blend mode, glass, and fill all passed. Adding the recovered layer position was the only failing case, identifying its serialized shape as the malformed value.

### Accepted position encoding

The accepted representation is a position object containing a numeric `scale` and a two-element `translation-in-points` array. Encoding the translation as an object with named `x` and `y` members, or reducing the complete position to a vector array, was rejected. After converting the nested translation to `[x, y]`, both the full base document and the full document with specializations passed validation.

### First editable Maps reconstruction

The first generated Maps document opened successfully in Icon Composer. It proved that the extracted layers and recovered rendering properties could be reassembled into a structurally valid editable document.

Visual inspection exposed two related ordering problems. The four recovered groups appeared in descending order, and each group's layers were also emitted in compiled order. Large background shapes consequently covered colored foreground layers, making much of the icon appear black and white even though color metadata was present in the document.

### Authored stacking order

Reversing both arrays translated CoreUI's back-to-front compiled stacks into Icon Composer's front-to-back authoring order. The resulting second document restored the intended composition and revealed the expected full-color Default appearance.

### Canonical appearance specializations

The corrected Default appearance revealed that Dark and Mono still differed from the production icon. A document reserialized by Icon Composer showed that specializable properties use an ordered array whose first item contains only a default `value`; later items carry `appearance` and `value` as siblings. The earlier nested `slot` representation was accepted but did not reproduce the authored specialization behavior.

The generator was updated to emit the canonical array, encode an absent fill as `"none"`, use the current `specular` property name, and model Mono/Tinted as inheriting the effective Dark value unless it supplies a distinct override. The third Maps reconstruction then matched the observed Default, Dark, and Mono compositions.

### Reusable CoreUI extraction

The exploratory catalog code was consolidated into a reusable extractor. It requests Light, Dark, and Tintable stacks; normalizes macOS Aqua appearance names to those manifest roles; records group, layer, fill, frame, and rendition metadata; and preserves intrinsic raster dimensions.

Vector layers are serialized from Core Graphics SVG documents with Apple's SVG writer. Raster layers are encoded as PNG with ImageIO. The output is a local manifest plus extracted source layers, which are deliberately excluded from this repository.

### First reconstruction from a macOS-only app

Image Capture provided a second case with a different catalog profile: its appearance stacks use macOS Aqua names, it mixes vector and non-square raster source layers, and one layer uses Core Graphics blend mode 27. Normalizing those appearances, deriving authored scale from each raster's intrinsic dimensions, and translating blend mode 27 to `plus-lighter` produced an editable document that opened cleanly and was broadly recognizable in all three appearances.
