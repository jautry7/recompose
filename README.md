# Recompose

Recompose is an experimental macOS app that reconstructs an editable Icon Composer `.icon` document using information recovered from compiled asset catalogs. Because compilation can discard, transform, or specialize source data, **Recompose cannot perfectly reconstruct the icon document as originally authored**.

Drop in an `Assets.car` file and Recompose will identify the icon stack(s) present in the catalog, recover the underlying layer stack and rendering annotations, and save it as an editable `.icon` document.

Recompose relies on private CoreUI interfaces and undocumented Apple behavior, so results may vary between macOS releases.

## Download

Download the [0.1.0 alpha](https://github.com/jautry7/recompose/releases/latest)

## Known issues

The project is still an early prototype. Current known issues include:

- The reconstruction pipeline is still being refined; minor details in the recomposed icon may not perfectly match the original rendering.
- Recompose was developed and tested on macOS Golden Gate 27 beta; it is technically compatible with macOS Tahoe 26, but reconstruction results are unknown and untested.
- Xcode's default icon name ("AppIcon") is currently the only supported asset. Support for arbitrarily named `IconImageStack` assets is WIP.
  - The generated `.icns` file contained in the app's Resources folder, alongside `Assets.car`, typically inherits the name of the icon asset that is bundled into the asset catalog. From this you can tell whether that app's asset catalog is likely to be compatible with Recompose; if it's named anything other than `AppIcon`, the icon asset likely won't be recognized.
