# Recompose command-line reference

Recompose includes a command-line tool inside the application bundle at:

```text
Recompose.app/Contents/Helpers/recompose
```

The examples below use `recompose` for brevity. This assumes that the tool is available on your `PATH`; otherwise, use its full path.

## Usage

```text
recompose CATALOG [--asset NAME] [--output OUTPUT.icon]
recompose reconstruct CATALOG [--asset NAME] [--output OUTPUT.icon]
recompose extract CATALOG [--asset NAME] [--output DIRECTORY]
recompose assemble DIRECTORY [--output OUTPUT.icon]
recompose list CATALOG [--json]
```

`CATALOG` is the path to a compiled asset catalog, typically an `Assets.car` file.

In the default output names below, `<asset-name>` is a filesystem-safe form of the selected icon-stack name. Characters other than letters, numbers, periods, underscores, and hyphens are replaced with underscores.

## Commands

```text
recompose CATALOG
```
Runs the complete reconstruction pipeline. This is shorthand for `recompose reconstruct CATALOG`.

```text
recompose reconstruct CATALOG
```
Discovers an icon stack, extracts its contents, and creates an editable Icon Composer document. Unless `--output` is provided, the document is written to the current directory as `<asset-name>.icon`.

```text
recompose extract CATALOG
```
Extracts an icon stack without assembling an Icon Composer document. Unless `--output` is provided, the manifest and accompanying `Assets/` directory are written to `<asset-name>-extracted` in the current directory.

```text
recompose assemble DIRECTORY
```
Creates an Icon Composer document from a previously extracted directory. `DIRECTORY` must contain a supported `manifest.json` and its accompanying `Assets/` directory. Unless `--output` is provided, the document is written to the current directory as `<asset-name>.icon`.

```text
recompose list CATALOG
```
Lists the logical `IconImageStack` assets found in the catalog.

## Options

```text
--asset NAME
```

Reconstructs or extracts the `IconImageStack` with the specified name. This option is not accepted by `assemble` or `list`.

```text
--output PATH
```

Sets the output document or extraction-directory path. Recompose will not overwrite an existing output.

```text
--json
```

Writes the results of `list` as JSON to standard output. This option is available only with `list`.

```text
recompose -h
recompose --help
```

Displays the command synopsis.

## Selecting an icon stack

Reconstruction and extraction discover the available icon stacks automatically:

- If the catalog contains one icon stack, it is selected automatically.
- If it contains multiple icon stacks and the command is running interactively, Recompose asks you to choose one.
- In noninteractive use, a catalog containing multiple icon stacks requires `--asset NAME`.
- If the requested name does not exist, Recompose reports the available icon-stack names.

## Examples

Reconstruct the only icon stack in a catalog:

```sh
recompose "/Applications/Example.app/Contents/Resources/Assets.car"
```

Reconstruct a particular icon stack and choose the output path:

```sh
recompose Assets.car --asset AppIcon --output Example.icon
```

List the icon stacks in a catalog:

```sh
recompose list Assets.car
```

Save the machine-readable icon-stack list to a file:

```sh
recompose list Assets.car --json > icon-stacks.json
```

Extract and assemble in separate steps:

```sh
recompose extract Assets.car --asset AppIcon --output AppIcon-extracted
recompose assemble AppIcon-extracted --output AppIcon.icon
```
