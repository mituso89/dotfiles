# dotfiles

<p align="center">
  <a href="https://discord.gg/Wsy2NpnZDu"
    ><img
      alt="Discord"
      src="https://img.shields.io/discord/1439901831038763092?style=flat-square&label=discord"
  /></a>
</p>

Watch the walkthrough: https://youtu.be/5N-okeDdIuI

My personal Mac setup, managed with nix-darwin and home-manager, plus a Linux
profile of the same config managed with standalone home-manager.
One repo, one command, and a fresh machine ends up configured the same way every time.

- **macOS** gets the full stack: system defaults, Homebrew, and the user environment.
- **Linux** (Ubuntu and other non-NixOS distros, including WSL2) gets the user
  environment only - there is no nix-darwin, no Homebrew, and no OS defaults layer.

## Contributing / Using This Repo

These are my personal dotfiles, shared publicly so people can read them, learn from them, and fork them freely.
Feature requests and pull requests are not accepted here, and PRs are auto-closed.
If you find a bug, please open a GitHub Issue using the bug report template.

## What you get

Running the switch builds, on both platforms:

- Nix user packages (ripgrep, fd, fzf, jq, lazygit, Neovim, Hack Nerd Font)
- Shell (zsh, aliases, starship prompt)
- Editor (Neovim config with the rose-pine moon theme)
- Terminal (WezTerm config with the rose-pine moon theme and dimmed unfocused windows)
- Agent configs (Claude, Codex, opencode all share one AGENTS.md)
- Optional Pi theme and local extensions, generic UI settings and model overrides, plus two deliberately pinned third-party Pi packages

macOS additionally builds:

- System settings (dark mode, key repeat, dock, Finder, trackpad)
- Homebrew apps (casks and CLI tools)

Linux does not, because there is no system layer there. It installs `herdr`
from Nix instead (see below). The `claude-code` app and WezTerm come from
Homebrew on macOS only; on Linux you install those yourself from their own
sources (see "WezTerm on Linux and WSL" below).

## Prerequisites

**macOS**

- Apple Silicon Mac, by default.
- Intel Mac: change one line.
  In `configuration.nix`, set `nixpkgs.hostPlatform = "x86_64-darwin";` (the comment right there tells you the same thing).

**Linux**

- A non-NixOS distro (developed against Ubuntu 22.04, including under WSL2), x86_64 by default.
- ARM: `bootstrap-linux.sh` detects your CPU and offers to set `linuxSystem = "aarch64-linux";` in `flake.nix` for you.
- On real NixOS you would wire `home-linux.nix` into your system flake instead of using standalone home-manager; that is not covered here.

## Fresh-machine setup (macOS)

On a brand new Mac, from a bare clone of this repo:

```sh
git clone https://github.com/kunchenguid/dotfiles.git
cd dotfiles
```

Before you run it: review "Make it yours" below.
Change the host label or CPU architecture if needed, and read the Homebrew cleanup warning.
`bootstrap.sh` applies the config to your machine, so do this first.

```sh
./bootstrap.sh
```

`bootstrap.sh` does four things, in order:

1. Installs Determinate Nix, if it isn't already installed.
2. Symlinks this repo to `~/.dotfiles`.
   This has to happen before the first build, because `home-common.nix` points at config files through `~/.dotfiles`.
3. Checks the `user` configured in `flake.nix` against your actual macOS username, and offers to fix it for you if they differ.
4. Runs the first `darwin-rebuild switch`.
   It fetches the `darwin-rebuild` tool from the nix-darwin 26.05 release branch, then applies this repo's locked flake config.

After that, `darwin-rebuild` exists and you're on the normal workflow below.

## Fresh-machine setup (Linux)

On a brand new Ubuntu box, from a bare clone of this repo:

```sh
git clone https://github.com/kunchenguid/dotfiles.git
cd dotfiles
./bootstrap-linux.sh
```

`bootstrap-linux.sh` does four things, in order:

1. Installs Determinate Nix, if it isn't already installed.
   If systemd isn't PID 1 (some WSL2 setups), it installs with `--init none` automatically.
2. Symlinks this repo to `~/.dotfiles`, and stops if any `.nix` file is still
   untracked - Nix evaluates a flake from git's tracked tree, so an untracked
   file is invisible to the build.
3. Checks the `linuxUser` and `linuxSystem` configured in `flake.nix` against
   your actual username and CPU, and offers to fix them for you if they differ.
4. Runs the first `home-manager switch`, backing up conflicts.

That last part matters on a machine that isn't fresh: any file Home Manager
wants to own and that already exists - a distro-provided `~/.zshrc`, say - is
renamed rather than blocking the switch. The backup extension is timestamped
(`-b "backup-$(date +%Y%m%d%H%M%S)"`) rather than a plain `backup`, because
Home Manager also aborts when the backup name is itself already taken, and an
old `~/.zshrc.backup` you still want is exactly the sort of file that would
collide. Nothing is ever deleted, but read the `.backup-*` files afterwards if
you had settings you care about - see "Machine-specific shell setup" below.

No `sudo` is needed: standalone Home Manager only writes inside your home
directory and the Nix store.

### Validate without applying

Once Nix is installed (step 1 of either bootstrap script handles that), you can check that the config builds without touching your system - handy when you have edited something:

```sh
nix flake check --no-build

# macOS
nix build .#darwinConfigurations.mac.system --dry-run

# Linux
nix build .#homeConfigurations.linux.activationPackage --dry-run
```

If you renamed the host label in "Make it yours", substitute your label for `mac` or `linux` in these commands.

## Daily use

Edit the config files in place, then apply:

```sh
./rebuild.sh
```

That's it.
No separate build-and-copy step.
`rebuild.sh` looks at `uname` and runs `darwin-rebuild switch --flake ~/.dotfiles#mac`
on macOS or `home-manager switch -b "backup-<timestamp>" --flake ~/.dotfiles#linux`
on Linux, so the same command works on either machine.

## Make it yours

This repo is mine.
If you clone it, review these before you run either bootstrap script:

- **Username**: run `./bootstrap.sh` on macOS or `./bootstrap-linux.sh` on Linux (each detects your username and offers to set it) OR change the single `user = "kunchen"` / `linuxUser = "mitu"` line in `flake.nix`.
  Everything else (`configuration.nix`, `home.nix`, `home-linux.nix`, home directory paths) is threaded from those two variables.
- **Host labels** `"mac"` and `"linux"`: each name appears in `flake.nix` (the `darwinConfigurations."mac"` / `homeConfigurations."linux"` names), in `rebuild.sh`, and in its bootstrap script's first-switch command.
  All of a label's occurrences have to match.
- **CPU architecture**: `hostPlatform` in `configuration.nix` for macOS, `linuxSystem` in `flake.nix` for Linux (see Prerequisites above).

**Git identity:** this config deliberately does not set your git name or email.
Git will stop your first commit and tell you to set them (`git config --global user.name "Your Name"` and `git config --global user.email you@example.com`).
If you'd rather manage that declaratively, add this back to `home-common.nix` with your own identity:

```nix
programs.git = {
  enable = true;
  settings.user = {
    name = "Your Name";
    email = "you@example.com";
  };
};
```

**Homebrew cleanup warning (macOS only):** `configuration.nix` sets `homebrew.onActivation.cleanup = "zap"`.
That means every time you switch, Homebrew removes any package or cask on your machine that isn't listed in the `brews` and `casks` arrays in `configuration.nix`.
If you already have Homebrew stuff installed that isn't in that list, the first switch will uninstall it.
Read through `brews` and `casks` before you run `bootstrap.sh` or `rebuild.sh` for the first time, and add anything you want to keep.

**About `herdr`:** it's the agent multiplexer whose panes, machines and agents panels `home/.config/herdr/config.toml` configures.

On macOS it's in the `brews` list.
It's a real public Homebrew formula (`brew info herdr` finds it in homebrew-core, no tap needed), so it will install fine.
If you don't use it, just remove it from `brews` in your copy.

On Linux it comes from Nix, declared in `home-linux.nix`.
It hasn't landed in a numbered nixpkgs release yet, so `flake.nix` carries a `nixpkgs-unstable` input and a deliberately narrow overlay that takes **only** `herdr` from it:

```nix
overlays = [
  (_final: _prev: {
    inherit (import nixpkgs-unstable { ... }) herdr;
  })
];
```

Everything else on Linux stays on the 26.05 release.
Widening that overlay would quietly move the whole profile off a stable release, so `tests/linux-profile.test.sh` asserts it provides exactly one package.
Once `herdr` reaches a numbered release, drop the input and the overlay and move it into the normal package list.

**Heads-up:**

- `home/AGENTS.md` is my personal agent policy, and `home-common.nix` installs it for Claude, Codex, and opencode.
  If you clone this repo, you'd silently inherit my agent instructions - edit or delete `home/AGENTS.md` if you don't want that.
- The `cc` and `co` shell aliases in `home-common.nix` are high-agency shortcuts: `claude --dangerously-skip-permissions` and `codex --full-auto`.
  They're convenient for me, but know what they do before you use them.

## Repo tour

- `flake.nix` - the entry point.
  Wires up nixpkgs, nix-darwin, home-manager, and nix-homebrew, and declares the `mac` machine and the `linux` home profile.
- `configuration.nix` - system-level config, macOS only: macOS defaults, Homebrew.
- `home-common.nix` - the user-level config both platforms share: shell, packages, prompt, and the symlinks described below.
  Anything added here has to work on macOS *and* Linux.
- `home.nix` - the macOS entry point. Sets the username and `/Users/...` home, then imports `home-common.nix`.
- `home-linux.nix` - the Linux entry point. Sets the username and `/home/...` home, enables `programs.home-manager` (standalone Home Manager has to install its own CLI) and `targets.genericLinux` (so Nix programs, fonts, and desktop entries are found on a non-NixOS distro), then imports `home-common.nix`.
- `bootstrap-linux.sh` - the Linux counterpart of `bootstrap.sh`.
- `rebuild.sh` - re-applies the config after the first switch, on either platform.
  Run this every time you make a change.
- `home/` - the actual config files that get symlinked into place; the sections below explain the shared symlink model and Pi's narrower selective setup.

## How the symlinks work

The files under `home/` are the real files - editing them here is editing your live config, no rebuild needed to see the change in your editor.
`home-common.nix` uses `mkOutOfStoreSymlink` to point paths like `~/.config/nvim` straight at `home/.config/nvim` in this repo, so the two never drift out of sync.
You only run `./rebuild.sh` when you change something that isn't just a symlinked file, like a package list or a system default.

## Optional Pi configuration

Pi is an opt-in CLI, not a dependency this repository vendors. Install it from its owner with the [official Pi instructions](https://pi.dev), for example:

```sh
npm install -g --ignore-scripts @earendil-works/pi-coding-agent
```

[Pi Launcher](https://github.com/kunchenguid/homebrew-tap) is also optional and installed from its owner, not declared by this config:

```sh
brew install --cask kunchenguid/tap/pi-launcher
```

Home Manager owns exactly two repository-authored Pi directories: `~/.pi/agent/themes` and `~/.pi/agent/extensions`. It also links `models.json` and `settings.json` as individual files. The local extension directory is for public, repository-authored extensions only - third-party package code never belongs there. Run `/reload` after editing a local extension or other Pi resources. The terminal-title extension shows a spinner while Pi is working, then a completion mark with the session name or current directory. The `rose-pine-moon` theme was authored clean-room from the public [Rosé Pine Moon palette](https://rosepinetheme.com/palette) and Pi's [public theme schema](https://raw.githubusercontent.com/earendil-works/pi/main/packages/coding-agent/src/modes/interactive/theme/theme-schema.json), not from a private or live theme file.

### Pi Calm

`home/.pi/agent/extensions/calm` is a standalone local Pi extension. Home Manager's existing global extensions-directory link makes Pi auto-load it without another declaration. `/calm` toggles a conversation-only presentation mode and is off by default. Its choice is stored locally in `~/.pi/agent/calm` (or the directory selected by `PI_CODING_AGENT_DIR`), not in this repository or Home Manager. Adapted from Firstmate under the bundled MIT license, Calm imports no Firstmate modules and has no Firstmate runtime dependency.

When enabled, Calm hides collapsed thinking and the call/result shells for Pi's seven built-in tools (`read`, `bash`, `edit`, `write`, `grep`, `find`, and `ls`) without leaving blank transcript rows. During an active run it replaces Pi's working row with a two-line animated blue-water, yellow-boat widget. `/calm` restores Pi's stock rendering and preserves the existing Ctrl+O tool-expansion choice.

Calm never changes prompts, tool execution, model context, session data, or ordering. `/share` and `/export` use the complete stock transcript. Generic custom tools, images, and unsupported Pi transcript classes deliberately remain visible because Pi has no safe general-purpose transcript filter. If a future Pi release no longer exports the exact collapsed-thinking rendering seam, Calm logs one diagnostic and leaves only that adapter disabled; all other behavior remains available.

Pi's package system declares two third-party sources in the linked global `settings.json`:

- `npm:pi-web-access@0.14.0` - the exact public npm release for web access.
- `npm:@ryan_nookpi/pi-extension-codex-fast-mode@0.2.6` - the exact public npm release from `ryan_nookpi`.

The versions are immutable pins, so Pi does not move them during package updates. Deliberate updates require a new source and security audit, followed by an explicit pin change in `home/.pi/agent/settings.json`. On Pi 0.82.0, global settings declarations install missing pinned packages automatically at startup. No one-time install command is required. Pi keeps the downloaded npm package trees in its own unmanaged `~/.pi/agent/npm` runtime directory, outside Home Manager and Git tracking.

Both packages execute with your full user permissions and must be trusted like any other executable code.

Home Manager deliberately does not manage `~/.pi/agent` itself, or Pi authentication, sessions, trust decisions, caches, npm/git package trees, or any other runtime state. The model overrides contain no credentials or endpoint settings, do not choose a default model, and only take effect after you authenticate Pi yourself. This remains an additive post-video layer: it does not install Pi, a launcher, or package source code into this repository.

## Machine-specific shell setup

Home Manager owns `~/.zshrc`, so anything that was in it before the first switch
is replaced - toolchain managers like nvm and pyenv, SDK paths, work-only
settings. That is the point on a reproducible machine, but those things are
absolute paths belonging to one box, and they have no business in a public repo.

The generated `~/.zshrc` therefore ends with:

```sh
[ -f ~/.zshrc.local ] && . ~/.zshrc.local
```

`~/.zshrc.local` is untracked, optional, and absent on a fresh machine. Put
per-machine setup there and it survives every rebuild:

```sh
# ~/.zshrc.local
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
command -v pyenv >/dev/null && eval "$(pyenv init -)"
```

Adopting these dotfiles also replaces oh-my-zsh and powerlevel10k with starship,
plus Home Manager's own autosuggestions and syntax highlighting. If you want
oh-my-zsh back, set `programs.starship.enable = false;` in your platform entry
point and source oh-my-zsh from `~/.zshrc.local`.

## WezTerm on Linux and WSL

On macOS the `wezterm` cask installs WezTerm and Home Manager links
`~/.config/wezterm` at this repo's copy.

On Linux nothing here installs WezTerm - install it from your distro or from
[wezterm.org](https://wezterm.org) if you want it natively, and the same
`~/.config/wezterm` link will pick up this config.

Under **WSL2** the usual setup is a WezTerm running on the *Windows* side that
opens a WSL shell, so the `~/.config/wezterm` link inside WSL is inert. WezTerm
on Windows reads `%USERPROFILE%\.config\wezterm\wezterm.lua`, so point that at
this repo from a Windows shell, for example:

```powershell
# from Windows PowerShell, adjust the WSL distro name and repo path
New-Item -ItemType SymbolicLink -Force `
  -Path "$env:USERPROFILE\.config\wezterm" `
  -Target "\\wsl$\Ubuntu\home\<you>\.dotfiles\home\.config\wezterm"
```

Two WSL-specific notes: install Hack Nerd Font on Windows (the Nix font package
inside WSL is not visible to a Windows GUI app), and add a default domain if you
want WezTerm to open straight into WSL:

```lua
config.wsl_domains = wezterm.default_wsl_domains()
config.default_domain = "WSL:Ubuntu-22.04"
```

The domain name has to match the distro exactly as `wsl -l -v` reports it on
Windows, which is also what `echo $WSL_DISTRO_NAME` prints inside the distro.
`Ubuntu-22.04` and `Ubuntu` are different names and only one of them will
resolve.

`config.macos_window_background_blur` in `wezterm.lua` is simply ignored off macOS.

## Notes

The first time you launch `nvim`, it bootstraps [lazy.nvim](https://github.com/folke/lazy.nvim) by cloning plugins from GitHub.
That needs network access once; after that it's offline.
Neovim and WezTerm both use the rose-pine moon theme.
Neovim keeps italics off and uses a transparent background on macOS, Windows, and WSL so it matches the terminal setup.
On a native Linux desktop it keeps an opaque background, because the terminal there isn't assumed to be translucent.

## License

This repo is licensed under MIT No Attribution.
See `LICENSE`.
