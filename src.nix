with (import <nixpkgs> {}).pkgs;

let
  nix-gitignore = lib.importJSON ./nix-gitignore.json;
  gitignore = callPackage (pkgs.fetchFromGitHub {
    owner = "siers";
    repo = "nix-gitignore";
    inherit (nix-gitignore) rev sha256;
  }) {};
  gitignoreExtra = ''
    /.build/k
    *.nix
  '';
in
  with gitignore;

gitignoreSourceAux gitignoreExtra ./.
