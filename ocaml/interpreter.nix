with (import <nixpkgs> {}).pkgs;

let
  inherit (ocamlPackages_4_06_k)
    bn128 cryptokit ocaml-protoc ocp-ocamlres secp256k1;
in

stdenv.mkDerivation {
  name = "evm-semantics-ocaml-interpreter";
  src = import ../src.nix;

  buildInputs = [
    k pandoc
  ];

  propagatedBuildInputs = [
    bn128 cryptokit ocaml-protoc ocp-ocamlres secp256k1 zlib
  ];

  makeFlags = [
    "OPAM=true"
    "KOMPILE=kompile"
  ];

  preConfigure = ''
    export OCAMLPATH="$OCAMLPATH:$OCAMLFIND_DESTDIR"
  '';

  buildFlags = [ "build-ocaml" ];

  createFindlibDestdir = true;
  installPhase = ''
    runHook preInstall

    mkdir -p "$out/bin"
    cp ".build/ocaml/driver-kompiled/interpreter" -t "$out/bin"

    runHook postInstall
  '';
}
