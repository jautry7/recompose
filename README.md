# Recompose

Recompose is an experimental macOS app that reconstructs an editable Icon Composer `.icon` document from a compiled macOS asset catalog (`Assets.car` file). Because compilation can discard, transform, or specialize source data, **Recompose cannot perfectly reconstruct the icon document as originally authored**.

Drop in any CAR file and Recompose will identify the icon stack(s) present in the catalog, recover the underlying layer stack and rendering annotations, and save it as an editable `.icon` document which you can open in Icon Composer.

[Download Recompose](https://github.com/jautry7/recompose/releases/latest)


## Watchouts

- The reconstruction pipeline is still being refined; minor details in the recomposed icon may not perfectly match the original rendering.
- Recompose relies on private CoreUI interfaces and undocumented Apple behavior, so results may vary between macOS releases. The app was developed and tested on macOS Golden Gate 27 beta; though it will run on macOS Tahoe 26, results on that platform are unknown and untested.
- This app is not affiliated with or endorsed by Apple. It's a hobbyist project made by someone who loves iconography (with the help of ChatGPT). Please do not use Recompose to plagiarize another developer's icon.
