# Recompose

Recompose is an experimental macOS project for reconstructing editable Icon Composer documents from compiled asset catalogs.

The current prototype reads icon-layer stacks through Apple's CoreUI runtime, exports their source layers with Apple frameworks, and translates the recovered rendering metadata into Icon Composer's document schema. It is research software and currently relies on private system interfaces that can change between macOS releases.

Only source code and project documentation belong in this repository. Catalogs, extracted artwork, generated documents, screenshots, and validation artifacts are maintained separately.

