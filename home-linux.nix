{ pkgs, user, ... }:

# Linux entry point, used by standalone Home Manager (there is no nix-darwin
# here, so this profile owns the whole configuration on its own).
# Everything shared with macOS lives in home-common.nix.
{
  imports = [ ./home-common.nix ];

  home.username = user;
  # Containers (WSL containers, Docker images) commonly run as root, whose home
  # is /root rather than /home/root. Everything else uses the usual layout.
  home.homeDirectory = if user == "root" then "/root" else "/home/${user}";

  # The agent multiplexer whose config home-common.nix already links at
  # ~/.config/herdr. On macOS this comes from Homebrew instead, so it is
  # declared here rather than in the shared module.
  home.packages = [ pkgs.herdr ];

  # Standalone Home Manager has to install its own CLI; on macOS the
  # nix-darwin module provides it instead.
  programs.home-manager.enable = true;

  # Ubuntu is not NixOS, so Home Manager has to fix up XDG_DATA_DIRS and friends
  # itself for Nix-installed programs, fonts, and desktop entries to be found.
  targets.genericLinux.enable = true;
}
