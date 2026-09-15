{ user, ... }:

# macOS entry point. Everything shared with Linux lives in home-common.nix.
{
  imports = [ ./home-common.nix ];

  home.username = user;
  home.homeDirectory = "/Users/${user}";
}
