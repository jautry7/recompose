# Recompose

Recompose is an experimental macOS app that reconstructs an editable Icon Composer `.icon` document from a compiled macOS asset catalog (`Assets.car` file). Because compilation can discard, transform, or specialize source data, **Recompose cannot perfectly reconstruct the icon document as originally authored**.

Drop in any CAR file and Recompose will identify the icon stack(s) present in the catalog, recover the underlying layer stack and rendering annotations, and save it as an editable `.icon` document which you can open in Icon Composer.

[Download Recompose](https://github.com/jautry7/recompose/releases/latest)

## How to use

Recompose requires an app's compiled asset catalog ( `.car` file) as input. These can be found inside an app's bundle package:

- Right click on the app and select "Show packaged contents"
- Navigate to `Contents/Resources/Assets.car`. This is the file you need; drag it to Recompose to extract the icon(s).

If multiple icons are present, Recompose will offer all `IconImageStack` assets it finds.

If an app does not have an `Assets.car` file in its `Resources` directory, that means the app has not been updated to use Apple's layered icon rendering system yet. In that case, the `.icns` file present in `Resources` is the source of truth for the app's icon.

In rare cases, a developer may use Apple's catalog system for some assets, but may decline to use the new layered icon rendering system. In these cases, Recompose will report that no `IconImageStack` was found in the catalog.


## Watchouts

- The reconstruction pipeline is still being refined; minor details in the recomposed icon may not perfectly match the original rendering.
- Recompose relies on private CoreUI interfaces and undocumented Apple behavior, so results may vary between macOS releases. The app was developed and tested on macOS Golden Gate 27 beta; though it will run on macOS Tahoe 26, results on that platform are unknown and untested.
- This app is not affiliated with or endorsed by Apple. It's a hobbyist project made by someone who loves iconography (with the help of ChatGPT). Please do not use Recompose to plagiarize another developer's icon.
