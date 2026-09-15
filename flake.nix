{
  description = "dotfiles";

  inputs = {
    # Use `github:NixOS/nixpkgs/nixpkgs-26.05-darwin` to use Nixpkgs 26.05.
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-26.05-darwin";
    # Linux gets its own nixpkgs branch: the `-darwin` channel above is only
    # release-tested for macOS. Same 26.05 release, matching Home Manager.
    nixpkgs-linux.url = "github:NixOS/nixpkgs/nixos-26.05";
    # Only for packages that have not reached the 26.05 release yet; see the
    # narrow overlay below. Nothing else is taken from unstable.
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    # Use `github:nix-darwin/nix-darwin/nix-darwin-26.05` to use Nixpkgs 26.05.
    nix-darwin.url = "github:nix-darwin/nix-darwin/nix-darwin-26.05";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager/release-26.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
  };

  outputs = inputs@{ self, nix-darwin, nix-homebrew, home-manager, nixpkgs, nixpkgs-linux, nixpkgs-unstable }:
    let
      # The one username line to change if this isn't your machine.
      # bootstrap.sh offers to rewrite this for you if your macOS username differs.
      user = "kunchen";

      # The Linux equivalents. bootstrap-linux.sh offers to rewrite both of
      # these for you if your Linux username or CPU architecture differs.
      linuxUser = "mitu";
      linuxSystem = "x86_64-linux"; # use aarch64-linux on ARM

      # herdr has not landed in a numbered release yet, so pull that single
      # package from unstable instead of moving the whole Linux profile off
      # 26.05. macOS installs herdr through Homebrew (configuration.nix).
      linuxPkgs = import nixpkgs-linux {
        system = linuxSystem;
        config.allowUnfree = true;
        overlays = [
          (_final: _prev: {
            inherit (import nixpkgs-unstable {
              system = linuxSystem;
              config.allowUnfree = true;
            }) herdr;
          })
        ];
      };
    in
    {
      darwinConfigurations."mac" = nix-darwin.lib.darwinSystem {
        specialArgs = { inherit user; };
        modules = [
          ./configuration.nix
          nix-homebrew.darwinModules.nix-homebrew
          home-manager.darwinModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = { inherit user; };
            home-manager.users.${user} = import ./home.nix;
          }
        ];
      };

      # Ubuntu and other non-NixOS Linux: standalone Home Manager, no system
      # layer. There is no nix-darwin, no Homebrew, and no macOS defaults here -
      # this output configures the user environment only.
      homeConfigurations."linux" = home-manager.lib.homeManagerConfiguration {
        pkgs = linuxPkgs;
        extraSpecialArgs = { user = linuxUser; };
        modules = [ ./home-linux.nix ];
      };
    };
}
