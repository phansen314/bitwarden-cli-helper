# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Shell helpers wrapping the Bitwarden CLI (`bw`) for faster unlocking, searching, and copying credentials. Single-file bash utility (`bitwarden.sh`) meant to be sourced in `~/.bashrc` or `~/.bash_aliases`.

## Architecture

All functionality lives in `bitwarden.sh` as three bash functions:

- **`bwu`** — Login/unlock flow; exports `BW_SESSION` for subsequent `bw` calls
- **`bwf <search>`** — Search vault items, display as formatted table via `jq` + `column`
- **`bwg [field] <item>`** — Copy a vault field to clipboard via `xclip` (defaults to password)
- **`bwgen [length|args...]`** — Generate a password and copy to clipboard (defaults: `-ulns --length 20`)

There is no build system, package manager, or test framework. The script is sourced directly.

## External Dependencies

`bw` (Bitwarden CLI), `jq`, `xclip`, and standard bash utilities (`column`, `grep`).

## Required Environment

`BW_EMAIL` must be set before sourcing. `BW_SESSION` is exported by `bwu` at runtime.

## Shell Compatibility

Script targets bash (shebang: `#!/usr/bin/env bash`). Functions use bash-specific features like `local` and `export`.
