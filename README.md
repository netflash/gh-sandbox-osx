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

4. Authenticate `gh` inside the sandbox. Two options:

   **Option A — import from existing system keychain** (if you already use `gh` on this machine):

   ```bash
   gh-sandbox/import-token
   ```

   This reads your token from the macOS Keychain (where the system `gh` stores it) and writes it into the sandbox's isolated config. Accepts an optional username argument if auto-detection fails:

   ```bash
   gh-sandbox/import-token your-username
   ```

   **Option B — fresh login inside the sandbox:**

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
| `import-token` | Copies your existing gh token from the macOS Keychain into the sandbox |
| `env/` | Isolated HOME directory for sandboxed `gh` (created on first run) |

## How it works

The wrapper script (`gh`) runs the real `/opt/homebrew/bin/gh` binary through `sandbox-exec` with a custom Seatbelt profile. The profile:

1. Allows all file reads by default (system libs, frameworks)
2. Denies all access to `/Users` (home directories)
3. Re-allows access to `env/` (sandbox HOME) and the parent project directory
4. Restricts writes to `env/`, `/tmp`, and `/dev` only
5. Allows network and IPC (required by Go runtime and GitHub API)

## Testing

`import-token` has a [bats-core](https://github.com/bats-core/bats-core) test suite.

Install bats (macOS):

```bash
brew install bats-core
```

Run the tests:

```bash
bats tests/import-token.bats
```

## Customization

To change the `gh` binary path, edit `GH_BIN` in `gh`.

To allow access to additional directories, add `(allow file-read* (subpath "/your/path"))` to `gh-sandbox.sb`.
