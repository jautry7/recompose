# Recompose

Recompose is an experimental macOS project for reconstructing editable Icon Composer documents (`.icon`) from compiled asset catalogs.

The current prototype is CLI only (availabile in `/cli/builds`) and reads icon-layer stacks through Apple's CoreUI runtime, exports their source layers with Apple frameworks, and translates the recovered rendering metadata into Icon Composer's document schema.

The prototype was developed against macOS 27 beta, Xcode 27 beta, and Icon Composer 2. It uses private CoreUI interfaces and an undocumented Core Graphics SVG serializer, so compatibility must be revalidated for each system release.
