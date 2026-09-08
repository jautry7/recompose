# Format unknowns

- Status: open
- Priority: 2

## Scope

This ticket covers questions about the Icon Composer and compiled icon formats that exist now. It does not speculate about features Apple might add later. When the tools or format change, the project can revise its documentation from new evidence.

## Current unknowns

- Whether the current Icon Composer can author appearance trees with different group or leaf counts or ordering. No such divergence occurred in the audited corpus.
- Which fill types the current Icon Composer exposes and their CoreUI numeric gradient types.
- The accepted grammar and defaults for current `supported-platforms` selections.
- Whether package members beyond `icon.json` and `Assets/` carry durable document meaning.
- Which current root, group, and layer properties can be specialized for Default, Dark, and Mono.
- Whether `renderingProperties` contains independently useful semantics not exposed through the known accessors.
- Whether current bundle or asset-catalog metadata identifies a primary icon when a CAR contains several stacks.
- The current stack shapes, leaf classes, appearance combinations, and source object versions that Recompose must accept.

The current Icon Composer UI has no observed multi-stop gradient support. Treat multi-stop gradients as unsupported by the present authoring surface, not as a future feature to investigate. Reopen that question only if an existing document, compiled stack, or current tool provides contrary evidence. Apply the same rule to non-linear fill types and theoretical stack limits.

## Approach

1. Use direct inspection of the current Icon Composer and Xcode interfaces to eliminate questions the authoring surface already answers.
2. Consult current public documentation where it describes an existing feature.
3. Inspect current authored documents and compiled records for evidence not visible in the UI.
4. Build a controlled fixture only when an existing feature remains ambiguous after those checks.
5. Record each result as supported, unsupported, compiled-only, or unrepresentable.

User-observed Icon Composer behavior is useful evidence here and can remove unnecessary experiments quickly.

## Completion criteria

The remaining current format surface is described without hypothetical future cases, and Recompose either supports or explicitly rejects every structure demonstrated by the current tools and maintained corpus.
