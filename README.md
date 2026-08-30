# Recompose

Recompose is an experimental macOS project for reconstructing editable Icon Composer documents (`.icon`) from compiled asset catalogs.

The current prototype reads icon-layer stacks through Apple's CoreUI runtime, exports their source layers with Apple frameworks, and translates the recovered rendering metadata into Icon Composer's document schema.

The prototype was developed against macOS 27 beta, Xcode 27 beta, and Icon Composer 2. It uses private CoreUI interfaces and an undocumented Core Graphics SVG serializer, so compatibility must be revalidated for each system release.

## Build

Build the command-line tools with Apple's active Xcode toolchain:

```sh
make
```

Products are written to `../Build/`.

## Prototype pipeline

First extract an icon stack and its manifest:

```sh
../Build/coreui-icon-extract /path/to/Assets.car asset-name /path/to/extraction
```

Then reconstruct an Icon Composer document from that manifest and its extracted assets:

```sh
../Build/icon-recreate \
  /path/to/extraction/manifest.json \
  /path/to/extraction/Assets \
  /path/to/output.icon
```

The tools refuse or fail rather than silently flattening unsupported structures.
