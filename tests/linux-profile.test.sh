#!/usr/bin/env bash
# Static checks for the dual-platform layout: the macOS config keeps working
# while the Linux (standalone Home Manager) profile is wired up correctly.
#
# These are deliberately Nix-free so they run on a machine that has no Nix yet -
# `nix build .#homeConfigurations.linux.activationPackage --dry-run` is the
# evaluation check, this file is the wiring check.
#
# Coverage:
# - both platform outputs still exist in flake.nix;
# - each entry point imports the shared module and owns only its own home path;
# - the shared module stays platform-neutral;
# - rebuild.sh dispatches on uname for both platforms;
# - bootstrap-linux.sh is GNU-sed-safe and does not sudo the switch;
# - every .nix file is tracked, because Nix evaluates a flake from git's tree.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

FLAKE="$ROOT/flake.nix"
COMMON="$ROOT/home-common.nix"
DARWIN_HOME="$ROOT/home.nix"
LINUX_HOME="$ROOT/home-linux.nix"

test_flake_declares_both_platforms() {
  local flake
  flake=$(cat "$FLAKE")
  assert_contains "$flake" 'darwinConfigurations."mac"' "flake.nix lost the macOS output"
  assert_contains "$flake" 'homeConfigurations."linux"' "flake.nix lost the Linux output"
  assert_contains "$flake" 'nixpkgs-linux.url' "flake.nix has no Linux nixpkgs input"
  assert_contains "$flake" 'home-manager.lib.homeManagerConfiguration' \
    "the Linux output does not use standalone Home Manager"
  assert_contains "$flake" './home-linux.nix' "the Linux output does not load home-linux.nix"

  # herdr is not in 26.05 yet, so exactly one package is taken from unstable.
  # If the overlay ever widens, the Linux profile silently stops tracking the
  # release, so pin the shape of it here.
  assert_contains "$flake" 'nixpkgs-unstable.url' "flake.nix lost the unstable input herdr needs"
  assert_contains "$flake" 'inherit (import nixpkgs-unstable' "the unstable overlay is gone"
  # The closing line of the inherit carries the attribute names:
  #   }) herdr;
  local unstable_attrs
  unstable_attrs=$(sed -nE 's/^[[:space:]]*\}\) ([A-Za-z0-9_ -]+);[[:space:]]*$/\1/p' "$FLAKE")
  [ "$unstable_attrs" = "herdr" ] \
    || fail "the unstable overlay provides '$unstable_attrs', expected exactly 'herdr'"

  # Each platform has exactly one personalization line for bootstrap to rewrite.
  local user_lines linux_user_lines system_lines
  user_lines=$(grep -cE '^[[:space:]]*user = "[^"]+";' "$FLAKE")
  linux_user_lines=$(grep -cE '^[[:space:]]*linuxUser = "[^"]+";' "$FLAKE")
  system_lines=$(grep -cE '^[[:space:]]*linuxSystem = "[^"]+";' "$FLAKE")
  [ "$user_lines" = 1 ] || fail "flake.nix has $user_lines \"user = \" lines, bootstrap.sh needs exactly 1"
  [ "$linux_user_lines" = 1 ] || fail "flake.nix has $linux_user_lines \"linuxUser = \" lines, bootstrap-linux.sh needs exactly 1"
  [ "$system_lines" = 1 ] || fail "flake.nix has $system_lines \"linuxSystem = \" lines, bootstrap-linux.sh needs exactly 1"

  # bootstrap.sh's macOS regex must not be confused by the new linuxUser line.
  local matched
  matched=$(sed -nE 's/^[[:space:]]*user = "([^"]+)";.*/\1/p' "$FLAKE" | head -n1)
  [ -n "$matched" ] || fail "bootstrap.sh's username regex no longer matches flake.nix"
  assert_not_contains "$matched" "linux" "bootstrap.sh's username regex now picks up the Linux user"

  pass "flake.nix declares both the mac system and the linux home profile"
}

test_entry_points_import_shared_module() {
  for f in "$DARWIN_HOME" "$LINUX_HOME"; do
    assert_contains "$(cat "$f")" './home-common.nix' "$f does not import the shared module"
    assert_contains "$(cat "$f")" 'home.username = user;' "$f does not set home.username"
  done
  assert_contains "$(cat "$DARWIN_HOME")" 'home.homeDirectory = "/Users/${user}"' \
    "home.nix lost the macOS home directory"
  # Root's home is /root, not /home/root - containers routinely run as root.
  assert_contains "$(cat "$LINUX_HOME")" 'if user == "root" then "/root" else "/home/${user}"' \
    "home-linux.nix lost the Linux home directory, or the root special case"

  # Standalone Home Manager on a non-NixOS distro needs both of these.
  assert_contains "$(cat "$LINUX_HOME")" 'programs.home-manager.enable = true;' \
    "home-linux.nix does not install the home-manager CLI"
  assert_contains "$(cat "$LINUX_HOME")" 'targets.genericLinux.enable = true;' \
    "home-linux.nix does not enable targets.genericLinux"

  # macOS gets herdr from Homebrew, so Linux has to declare it itself. It must
  # not drift into the shared module, where macOS would try to build it too.
  assert_contains "$(cat "$LINUX_HOME")" 'pkgs.herdr' "home-linux.nix does not install herdr"
  assert_not_contains "$(cat "$COMMON")" 'herdr;' "herdr leaked into the shared module"
  assert_contains "$(cat "$ROOT/configuration.nix")" '"herdr"' \
    "macOS stopped installing herdr through Homebrew"

  pass "both entry points import home-common.nix and own only their platform's home path"
}

test_shared_module_is_platform_neutral() {
  local common
  common=$(cat "$COMMON")
  assert_not_contains "$common" '/Users/' "home-common.nix hardcodes a macOS home path"
  assert_not_contains "$common" 'homeDirectory =' "home-common.nix sets homeDirectory, which is per-platform"
  assert_not_contains "$common" 'homebrew' "home-common.nix references Homebrew, which is macOS-only"
  assert_not_contains "$common" 'targets.darwin' "home-common.nix uses a darwin-only target"

  # The shared symlinks all still live here, so neither platform drifts.
  local link
  for link in '.config/nvim' '.config/wezterm' '.config/herdr' '.claude/settings.json' \
    '.pi/agent/themes' '.pi/agent/extensions' '.pi/agent/models.json' '.pi/agent/settings.json' \
    '.claude/CLAUDE.md' '.codex/AGENTS.md' '.config/opencode/AGENTS.md'; do
    assert_contains "$common" "home.file.\"$link\".source" "home-common.nix no longer links $link"
  done

  # The prompt must stay a real file: the dev container has no Home Manager and
  # symlinks this same starship.toml, so inlining it as Nix settings again would
  # silently fork the prompt across environments.
  assert_contains "$common" 'home.file.".config/starship.toml".source' \
    "home-common.nix no longer links starship.toml"
  assert_not_contains "$common" 'starship.settings' "starship settings were inlined back into Nix"
  [ -f "$ROOT/home/.config/starship.toml" ] || fail "home/.config/starship.toml is missing"

  # Machine-specific PATH/toolchain setup lives outside the repo, so the
  # generated ~/.zshrc must still source it when present.
  assert_contains "$common" '~/.zshrc.local' "home-common.nix no longer sources ~/.zshrc.local"
  assert_not_contains "$common" '/home/mitu' "home-common.nix hardcodes a machine-specific path"
  assert_not_contains "$common" 'google-cloud-sdk' "machine-specific SDK setup leaked into the repo"

  pass "home-common.nix stays platform-neutral, owns every shared symlink, and keeps machine setup out of the repo"
}

test_rebuild_dispatches_on_platform() {
  local rebuild
  rebuild=$(cat "$ROOT/rebuild.sh")
  assert_contains "$rebuild" 'uname -s' "rebuild.sh does not detect the platform"
  assert_contains "$rebuild" '-b "backup-$(date' "rebuild.sh does not use a unique backup extension"
  assert_contains "$rebuild" 'darwin-rebuild switch --flake ~/.dotfiles#mac' \
    "rebuild.sh lost the macOS switch"
  assert_contains "$rebuild" 'home-manager switch -b "backup-' \
    "rebuild.sh lost the Linux switch"
  assert_contains "$rebuild" '--flake ~/.dotfiles#linux' \
    "rebuild.sh does not point at the linux flake output"
  # The Linux switch is user-level; sudo would write root-owned files into $HOME.
  assert_not_contains "$rebuild" 'sudo home-manager' "rebuild.sh runs home-manager under sudo"

  bash -n "$ROOT/rebuild.sh" || fail "rebuild.sh has a syntax error"
  [ -x "$ROOT/rebuild.sh" ] || fail "rebuild.sh is not executable"

  pass "rebuild.sh switches the right configuration on each platform"
}

test_linux_bootstrap() {
  local boot
  boot=$(cat "$ROOT/bootstrap-linux.sh")
  bash -n "$ROOT/bootstrap-linux.sh" || fail "bootstrap-linux.sh has a syntax error"
  [ -x "$ROOT/bootstrap-linux.sh" ] || fail "bootstrap-linux.sh is not executable"

  # BSD sed's mandatory in-place suffix arg is a syntax error under GNU sed.
  assert_not_contains "$boot" "sed -i ''" "bootstrap-linux.sh uses BSD sed in-place syntax"
  assert_contains "$boot" 'sed -i -E' "bootstrap-linux.sh does not use GNU sed in-place syntax"
  assert_contains "$boot" 'ln -sfn "$DIR" ~/.dotfiles' "bootstrap-linux.sh does not create ~/.dotfiles"
  # A plain "-b backup" aborts when <file>.backup already exists, so the
  # extension has to be unique per run.
  assert_contains "$boot" '-b "backup-$(date' "bootstrap-linux.sh does not use a unique backup extension"
  assert_not_contains "$boot" '-b backup ' "bootstrap-linux.sh uses a colliding backup extension"
  assert_contains "$boot" 'ls-files --others' "bootstrap-linux.sh does not guard against untracked .nix files"
  assert_not_contains "$boot" 'sudo' "bootstrap-linux.sh escalates for a user-level switch"

  pass "bootstrap-linux.sh is GNU-sed-safe, backs up conflicts, and never sudos"
}

test_nix_files_are_tracked() {
  git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
    pass "not a git work tree, skipping the tracked-file check"
    return
  }
  local untracked
  untracked=$(git -C "$ROOT" ls-files --others --exclude-standard -- '*.nix')
  [ -z "$untracked" ] || fail "Nix cannot see untracked flake files: $untracked"

  pass "every .nix file is tracked, so the flake evaluates from git's tree"
}

test_flake_declares_both_platforms
test_entry_points_import_shared_module
test_shared_module_is_platform_neutral
test_rebuild_dispatches_on_platform
test_linux_bootstrap
test_nix_files_are_tracked
