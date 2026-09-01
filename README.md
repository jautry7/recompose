# Recompose

Recompose is an experimental macOS app that reconstructs editable Icon Composer `.icon` documents from compiled asset catalogs.

Drop in an `Assets.car` file and Recompose will identify its AppIcon, recover the underlying layer stack and rendering annotations, and save it as an editable `.icon` document.

Recompose relies on private CoreUI interfaces and undocumented Apple behavior, so results may vary between macOS releases.

## Download

Download the latest release here on GitHub: https://github.com/jautry7/recompose/releases/latest

## Known issues

The project is still an early prototype. Current known issues include:

- "AppIcon" is currently the only supported asset. Support for arbitrarily named `IconImageStack` assets is WIP.
- Reconstruction pipeline is still being refined. Minor details in recomposed icon may not perfectly match the original rendering.
- Recompose was developed and tested on macOS Golden Gate 27 beta; it is technically compatible with macOS Tahoe 26, but reconstruction results are unknown and untested.
- The frontend is currently a wrapper for bundled command-line helpers. Building the reconstruction pipeline into the app directly is the end goal.
