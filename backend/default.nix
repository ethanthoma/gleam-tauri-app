{
  craneLib,
  lib,
  stdenv,
  cairo,
  dbus,
  gdk-pixbuf,
  glib,
  gtk3,
  libsoup_3,
  webkitgtk_4_1,
  pkg-config,
  libiconv,
  makeWrapper,
  frontend,
  cargo-tauri,
  openssl,
  jq,
  writeText,
}:
let
  src = lib.cleanSourceWith {
    src = ./.;
    filter =
      path: type:
      (craneLib.filterCargoSources path type)
      || (lib.hasSuffix "\.json" path)
      || (lib.hasSuffix "\.png" path);
  };

  tauriConfig = lib.recursiveUpdate (builtins.fromJSON (builtins.readFile ./tauri.conf.json)) {
    build.beforeBuildCommand = "true";
  };

  commonArgs = {
    inherit src;

    strictDeps = true;

    buildInputs =
      [
        cairo
        dbus
        gdk-pixbuf
        glib
        gtk3
        libsoup_3
        webkitgtk_4_1
        openssl
      ]
      ++ lib.optionals stdenv.isDarwin [
        libiconv
      ];

    nativeBuildInputs = [
      pkg-config
      cargo-tauri
      jq
      makeWrapper
    ];
  };

  cargoArtifacts = craneLib.buildDepsOnly commonArgs;
in
craneLib.buildPackage (
  commonArgs
  // {
    inherit cargoArtifacts;

    buildInputs = cargoArtifacts.buildInputs ++ [
      frontend
    ];

    nativeBuildInputs = commonArgs.nativeBuildInputs ++ [
      craneLib.installFromCargoBuildLogHook
      craneLib.removeReferencesToVendoredSourcesHook
    ];

    preConfigure = ''
      ln -sf ${frontend}/dist ./dist
    '';

    buildPhaseCargoCommand = ''
      cargoBuildLog=$(mktemp cargoBuildLogXXXX.json)

      cargo tauri build -c ${writeText "tauri.json" (builtins.toJSON tauriConfig)} \
          -- --message-format json-render-diagnostics >"$cargoBuildLog"
    '';
  }
)
