# gh-sandbox

Sandboxed GitHub CLI (`gh`) wrapper for macOS. Runs `gh` with its own isolated HOME directory using macOS Seatbelt (`sandbox-exec`), preventing access to your real home directory and filesystem.

## Motivation

The `gh` CLI has unrestricted access to your entire filesystem, which is a concern when used with extensions or in automated workflows. There is a [long-standing request](https://github.com/cli/cli/issues/326) to support scoped tokens and restricted filesystem access, but it remains unresolved. This wrapper provides filesystem-level sandboxing as a workaround.

## What it does

- Blocks all read/write access to `/Users` (all home directories)
- Gives `gh` its own isolated HOME at `gh-sandbox/env/` (created on first run)
- Allows read-only access to the parent project directory (auto-detected)
- Allows network access (GitHub API)
- Allows access to system libraries, `/tmp`, and `/opt/homebrew` (git, gh binary)

## Prerequisites

- macOS (uses `sandbox-exec` / Seatbelt)
- [gh](https://cli.github.com/) installed at `/opt/homebrew/bin/gh`
- [direnv](https://direnv.net/) installed and hooked into your shell

## Installation

1. Clone into your project directory:

   ```bash
   cd ~/project
   git clone https://github.com/caseycs/gh-sandbox-osx.git gh-sandbox
   ```

2. Add to your project `.envrc`:

   ```bash
   PATH_add gh-sandbox
   ```

3. Allow the updated `.envrc`:

   ```bash
   direnv allow
   ```

4. Authenticate `gh` inside the sandbox:

   ```bash
   gh auth login
   ```

   The token is stored in `gh-sandbox/env/.config/gh/`, separate from your real `~/.config/gh`.

5. Verify:

   ```bash
   gh auth status
   ```

## Files

| File | Purpose |
|------|---------|
| `gh` | Wrapper script that invokes `gh` inside the sandbox |
| `gh-sandbox.sb` | macOS Seatbelt profile defining filesystem access rules |
| `env/` | Isolated HOME directory for sandboxed `gh` (created on first run) |

## How it works

The wrapper script (`gh`) runs the real `/opt/homebrew/bin/gh` binary through `sandbox-exec` with a custom Seatbelt profile. The profile:

1. Allows all file reads by default (system libs, frameworks)
2. Denies all access to `/Users` (home directories)
3. Re-allows access to `env/` (sandbox HOME) and the parent project directory
4. Restricts writes to `env/`, `/tmp`, and `/dev` only
5. Allows network and IPC (required by Go runtime and GitHub API)

## Customization

To change the `gh` binary path, edit `GH_BIN` in `gh`.

To allow access to additional directories, add `(allow file-read* (subpath "/your/path"))` to `gh-sandbox.sb`.
