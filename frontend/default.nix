{
  bun,
  gleam,
  fetchHex,
  formats,
  lib,
  linkFarm,
  makeWrapper,
  stdenv,
}:
let
  src = ./.;

  gleam-toml = lib.importTOML ./gleam.toml;
  manifest-toml = lib.importTOML ./manifest.toml;

  inherit (gleam-toml) name;
  version = gleam-toml.version;

  nodeModules = stdenv.mkDerivation {
    pname = "node_modules";
    version = "0.0.1";
    inherit src;

    nativeBuildInputs = [
      bun
    ];

    dontConfigure = true;
    dontFixup = true;

    buildPhase = ''
      runHook preBuild

      export HOME=$TMPDIR
      bun install --no-progress --frozen-lockfile

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p $out/lib/node_modules
      cp -R ./node_modules/* $out/lib/node_modules

      mkdir -p $out/bin
      cp -R ./node_modules/.bin/* $out/bin

      runHook postInstall
    '';

    outputHash = "sha256-NF0w45x/XjH78JxGCS/h7l/tK6npntODfMugEwXbdks=";
    outputHashAlgo = "sha256";
    outputHashMode = "recursive";
  };

  link-farm-package-entries = map (
    {
      name,
      version ? "0.1.0",
      source,
      ...
    }@package:
    if source == "hex" then
      let
        path = fetchHex {
          pkg = name;
          inherit version;
          sha256 = package.outer_checksum;
        };
      in
      {
        inherit name path;
      }
    else if source == "local" then
      {
        inherit name;
        path = src + "/${package.path}";
      }
    else
      throw "gleam2nix: unsupported dependency source: ${source}"
  ) manifest-toml.packages;

  packages-name = "${name}-${version}-packages";

  packages-toml.packages = builtins.listToAttrs (
    map (
      { name, version, ... }:
      {
        inherit name;
        value = version;
      }
    ) manifest-toml.packages
  );
  packages-toml-file = (formats.toml { }).generate "${packages-name}.toml" packages-toml;

  link-farm-entries = link-farm-package-entries ++ [
    {
      name = "packages.toml";
      path = packages-toml-file;
    }
  ];

  build-packages = linkFarm packages-name link-farm-entries;
in
stdenv.mkDerivation {
  pname = name;
  inherit version src;

  buildInputs = [ nodeModules ];

  nativeBuildInputs = [
    bun
    gleam
    makeWrapper
  ];

  configurePhase = ''
    runHook preConfigure

    mkdir -p .bin

    for bin in ${nodeModules}/bin/*; do
      name=$(basename "$bin")
      target=$(readlink "$bin")
      module_name=''${target#../}
      module_path="${nodeModules}/lib/node_modules/$module_name"

      makeWrapper ${bun}/bin/bun .bin/$name \
        --add-flags "$module_path" \
        --set NODE_PATH "${nodeModules}/lib/node_modules"
    done

    export PATH="$PWD/.bin:$PATH"
    ln -sf ${nodeModules}/lib/node_modules ./node_modules

    rm -rf build
    mkdir build
    cp -r --no-preserve=mode --dereference ${build-packages} build/packages

    runHook postConfigure
  '';

  buildPhase = ''
    runHook preBuild

    ${bun}/bin/bun run --prefer-offline --no-install build

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/static
    mv ./dist $out

    runHook postInstall
  '';
}
