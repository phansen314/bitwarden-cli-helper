# bitwarden-cli-helper

Shell helpers that wrap the [Bitwarden CLI](https://bitwarden.com/help/cli/) to make unlocking, searching, and copying credentials faster.

## Prerequisites

- [`bw`](https://bitwarden.com/help/cli/) — Bitwarden CLI
- [`jq`](https://jqlang.github.io/jq/) — JSON processor
- [`xclip`](https://github.com/astrand/xclip) — clipboard utility

## Installation

```bash
git clone https://github.com/<you>/bitwarden-cli-helper.git ~/bitwarden-cli-helper
```

Set your Bitwarden account email and source the helpers in your `~/.bashrc` or `~/.bash_aliases`:

```bash
export BW_EMAIL="you@example.com"
source ~/bitwarden-cli-helper/bitwarden.sh
```

Then reload your shell:

```bash
source ~/.bash_aliases
```

## Commands

### `bwu` — Unlock / login

Checks login status, logs in if needed, then unlocks and exports `BW_SESSION` so subsequent `bw` commands are authenticated.

```bash
bwu
```

### `bwf <search>` — Search vault items

Searches vault items and displays results in a formatted table (name, ID, URI).

```bash
bwf github
```

### `bwg [field] <item>` — Copy a field to clipboard

Copies a field from a vault item to the clipboard. Defaults to `password` if no field is specified.

```bash
bwg github              # copies password
bwg username github     # copies username
bwg totp github         # copies TOTP code
```
