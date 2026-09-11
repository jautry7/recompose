# Tahoe runtime compatibility

- Status: open
- Priority: 0

## Problem

The application targets macOS 26 Tahoe, and the assembler can emit the verified v26 `.icon` document form. Subsequent user testing nevertheless found the current application unable to complete reconstruction on Tahoe.

The Tahoe support audit did not exercise Recompose's discovery and extraction pipeline end to end on Tahoe. It verified generated-document acceptance, Xcode 26 compilation, and CoreUI read-back instead. The current failure therefore does not invalidate the v26 serialization findings, but it leaves the advertised minimum operating system without a functional reconstruction path.

## Open evidence

- The exact user-visible error and failing pipeline stage have not been captured.
- The Tahoe availability and signatures of the private CoreUI classes and selectors used for discovery and extraction remain unverified.
- The preview path additionally loads IconFoundation and invokes a private renderer. Preview failure is optional and must be distinguished from a failure in discovery, extraction, or assembly.
- Direct `.car` input and the fixed `.app/Contents/Resources/Assets.car` path both ultimately use the same staged catalog; they still require separate end-to-end confirmation on Tahoe.

## Completion criteria

- Direct `.car` reconstruction completes on the supported Tahoe release.
- A valid `.app` containing `Contents/Resources/Assets.car` completes through the same pipeline.
- Zero-stack, one-stack, multiple-stack, and generic-error outcomes remain distinct.
- Preview renderer unavailability does not turn a successful reconstruction into a pipeline failure.
- The macOS 27 reconstruction and three-appearance preview behavior remain intact.
