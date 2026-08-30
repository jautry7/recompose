# Research log

## 2026-08-30

### CoreUI surface discovery

The first probe loaded the system CoreUI framework and enumerated the Objective-C methods, properties, and instance variables exposed by classes involved in catalogs, theme renditions, named icons, layers, colors, and gradients. This established that the compiled catalog retained a structured icon layer stack rather than only a flattened bitmap.

### Catalog inspection

A focused catalog inspector then opened a supplied catalog through `CUICatalog`, requested an icon layer stack by name and appearance, and recorded the returned lookup and rendition structure as JSON. The result confirmed that an icon could be addressed as a hierarchy of groups and layers with appearance-specific renditions.
