#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
ln -sfn "$DIR" ~/.dotfiles
case "$(uname -s)" in
  Darwin) exec sudo darwin-rebuild switch --flake ~/.dotfiles#mac ;;
  Linux)  exec home-manager switch -b "backup-$(date +%Y%m%d%H%M%S)" --flake ~/.dotfiles#linux ;;
  *)      echo "Unsupported platform: $(uname -s)" >&2; exit 1 ;;
esac
