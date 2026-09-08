# Automatic-gradient orientation

- Status: open
- Priority: 2

## Problem

CoreUI gradient type `0` is the compiled form of the public `.icon` `automatic-gradient` value. Recompose now preserves that semantic mapping instead of converting a one-color gradient to a solid.

A focused recompilation audit found one remaining difference. Two Screen Sharing layers retain their automatic-gradient type, color, stop, and start point, but their source end point `{x: 0.5120722055, y: 0.9652591348}` recompiles as the default `{x: 0.5, y: 1}`. The public automatic-gradient form has no known orientation field.

## Goal

Determine whether automatic-gradient orientation is representable in the current public `.icon` format. If it is not, record the endpoint change as a known format limitation rather than approximating it with a different fill type.

## Investigation

1. Test whether an `orientation` object is accepted alongside `automatic-gradient` by the current Icon Composer and Xcode compiler.
2. Reserialize any accepted form through Icon Composer and check whether the orientation survives.
3. Compile and read the resulting CAR back through CoreUI.
4. Compare the Screen Sharing layers under the same system renderer to determine whether the endpoint difference affects appearance.

Do not substitute a solid or duplicate-stop linear gradient. Those forms have different semantics from CoreUI gradient type `0`.

## Resolution

Close the ticket with either a stable authored mapping or evidence that the public editable format cannot preserve the compiled endpoint.
