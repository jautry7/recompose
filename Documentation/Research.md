# Research log

## 2026-08-30

### CoreUI surface discovery

The first probe loaded the system CoreUI framework and enumerated the Objective-C methods, properties, and instance variables exposed by classes involved in catalogs, theme renditions, named icons, layers, colors, and gradients. This established that the compiled catalog retained a structured icon layer stack rather than only a flattened bitmap.

### Catalog inspection

A focused catalog inspector then opened a supplied catalog through `CUICatalog`, requested an icon layer stack by name and appearance, and recorded the returned lookup and rendition structure as JSON. The result confirmed that an icon could be addressed as a hierarchy of groups and layers with appearance-specific renditions.

### Icon Composer runtime discovery

A second runtime probe enumerated the classes and methods in Icon Composer's bundled foundation framework. The command-line utility bundled with Icon Composer could export a rendered image, which made it useful as a document-acceptance diagnostic, but it did not expose an operation for decoding or creating an editable document. Reconstruction therefore required learning the accepted document schema and writing it directly.
