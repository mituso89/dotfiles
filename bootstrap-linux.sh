#!/usr/bin/env bash
# Takes a fresh Ubuntu (or other non-NixOS Linux) box from nothing to a built
# standalone Home Manager config.
# Run this once. After it finishes, use ./rebuild.sh for every later change.
#
# This is the Linux counterpart of bootstrap.sh. There is no system layer here:
# no nix-darwin, no Homebrew, no OS defaults - just your user environment.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

if [ "$(uname -s)" != "Linux" ]; then
  echo "This is the Linux bootstrap. On macOS run ./bootstrap.sh instead."
  exit 1
fi

echo "==> Step 1: Determinate Nix"
if command -v nix >/dev/null 2>&1; then
  echo "    nix already installed, skipping"
else
  # WSL without systemd as PID 1 has no service manager for the Nix daemon,
  # so the installer needs to be told not to look for one.
  INIT_FLAGS=()
  if [ "$(ps -p 1 -o comm= 2>/dev/null)" != "systemd" ]; then
    echo "    systemd is not PID 1, installing with --init none"
    INIT_FLAGS=(--init none)
  fi
  # ${arr[@]+"${arr[@]}"} so an empty array is not an unbound variable under set -u.
  curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix \
    | sh -s -- install linux --no-confirm ${INIT_FLAGS[@]+"${INIT_FLAGS[@]}"}
  # shellcheck disable=SC1091
  . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
fi

echo "==> Step 2: symlink this repo to ~/.dotfiles"
# home-common.nix resolves its mkOutOfStoreSymlink paths through ~/.dotfiles, so
# this has to exist before the first switch or the build will fail to find them.
ln -sfn "$DIR" ~/.dotfiles

# Nix evaluates a flake in a git repo from the *tracked* tree, so an untracked
# .nix file is invisible to the build and fails with a confusing "does not
# exist" error. Catch that here instead.
if git -C "$DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  UNTRACKED="$(git -C "$DIR" ls-files --others --exclude-standard -- '*.nix')"
  if [ -n "$UNTRACKED" ]; then
    echo "    These .nix files are untracked, so Nix cannot see them:"
    printf '      %s\n' $UNTRACKED
    echo "    Run: git add $(echo $UNTRACKED | tr '\n' ' ')"
    exit 1
  fi
fi

echo "==> Step 3: personalize the configured username and architecture"
REAL_USER="$(whoami)"
FLAKE_USER="$(sed -nE 's/^[[:space:]]*linuxUser = "([^"]+)";.*/\1/p' "$DIR/flake.nix" | head -n1)"
if [ -z "$FLAKE_USER" ]; then
  echo "    Could not find the single \"linuxUser = \" line in flake.nix."
  echo "    Edit flake.nix yourself before continuing."
  exit 1
elif [ "$FLAKE_USER" != "$REAL_USER" ]; then
  echo "    flake.nix is configured for user \"$FLAKE_USER\", but you are \"$REAL_USER\"."
  read -r -p "    Rewrite flake.nix's \"linuxUser = \" line to \"$REAL_USER\"? [y/N] " REPLY
  if [ "$REPLY" = "y" ] || [ "$REPLY" = "Y" ]; then
    sed -i -E "s/^([[:space:]]*linuxUser = \")[^\"]+(\";.*)/\1${REAL_USER}\2/" "$DIR/flake.nix"
    echo "    Updated. Review the change with: git diff flake.nix"
  else
    echo "    Skipped. Edit the single \"linuxUser = \" line in flake.nix yourself before continuing."
    exit 1
  fi
else
  echo "    flake.nix already matches \"$REAL_USER\", nothing to do."
fi

case "$(uname -m)" in
  x86_64)          REAL_SYSTEM="x86_64-linux" ;;
  aarch64 | arm64) REAL_SYSTEM="aarch64-linux" ;;
  *)               REAL_SYSTEM="" ;;
esac
FLAKE_SYSTEM="$(sed -nE 's/^[[:space:]]*linuxSystem = "([^"]+)";.*/\1/p' "$DIR/flake.nix" | head -n1)"
if [ -z "$REAL_SYSTEM" ]; then
  echo "    Unrecognized CPU \"$(uname -m)\"; leaving linuxSystem = \"$FLAKE_SYSTEM\" alone."
elif [ "$FLAKE_SYSTEM" != "$REAL_SYSTEM" ]; then
  echo "    flake.nix is configured for \"$FLAKE_SYSTEM\", but this machine is \"$REAL_SYSTEM\"."
  read -r -p "    Rewrite flake.nix's \"linuxSystem = \" line to \"$REAL_SYSTEM\"? [y/N] " REPLY
  if [ "$REPLY" = "y" ] || [ "$REPLY" = "Y" ]; then
    sed -i -E "s/^([[:space:]]*linuxSystem = \")[^\"]+(\";.*)/\1${REAL_SYSTEM}\2/" "$DIR/flake.nix"
    echo "    Updated. Review the change with: git diff flake.nix"
  else
    echo "    Skipped. Edit the single \"linuxSystem = \" line in flake.nix yourself before continuing."
    exit 1
  fi
else
  echo "    flake.nix already matches \"$REAL_SYSTEM\", nothing to do."
fi

echo "==> Step 4: first home-manager switch (pinned to release-26.05)"
# home-manager doesn't exist yet on a fresh machine, so run it straight from its
# flake this once. After this, rebuild.sh works normally.
# -b renames any pre-existing file Home Manager wants to own (a distro ~/.zshrc,
# for example) instead of refusing to switch. The extension is timestamped
# because Home Manager also refuses when the backup name is itself taken - a
# plain "backup" would collide with an older ~/.zshrc.backup you want to keep.
# "linux" is the flake output label - if you renamed it, change it in
# flake.nix and rebuild.sh too.
nix --extra-experimental-features 'nix-command flakes' \
  run github:nix-community/home-manager/release-26.05 -- \
  switch -b "backup-$(date +%Y%m%d%H%M%S)" --flake ~/.dotfiles#linux
# If this fails with "nix: command not found", open a new terminal
# (Determinate adds nix to new shells' PATH) and re-run ./bootstrap-linux.sh.

echo "==> Done. Use ./rebuild.sh for future changes."
