{
  description = "basic flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    crane.url = "github:ipetkov/crane";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      crane,
      rust-overlay,
    }:
    {
      overlays = {
        cargo-tauri = final: prev: {
          cargo-tauri =
            let
              version = "2.0.4";
              craneLib = (crane.mkLib final).overrideToolchain final.rust-bin.stable.latest.default;

              src = final.fetchCrate {
                pname = "tauri-cli";
                inherit version;
                hash = "sha256-MPxOJxvbm4RPWMwcKqDgtkf+47na96xyHsVc1BGhu3s=";
              };

              commonArgs = {
                inherit version src;
                pname = "cargo-tauri";
              };

              cargoArtifacts = craneLib.buildDepsOnly commonArgs;

            in
            craneLib.buildPackage (
              commonArgs
              // {
                inherit cargoArtifacts;

                buildInputs =
                  with final;
                  [
                    pkg-config
                    openssl
                  ]
                  ++ final.lib.optionals final.stdenv.isDarwin [
                    final.libiconv
                    final.darwin.apple_sdk.frameworks.Security
                    final.darwin.apple_sdk.frameworks.SystemConfiguration
                  ];

                nativeBuildInputs = with final; [
                  pkg-config
                ];
              }
            );
        };

        default = nixpkgs.lib.composeManyExtensions [
          (import rust-overlay)
          self.overlays.cargo-tauri
        ];
      };
    }
    // flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system}.extend self.overlays.default;

        rustToolchain = pkgs.rust-bin.stable.latest.default;

        craneLib = (crane.mkLib pkgs).overrideToolchain rustToolchain;

        frontend = pkgs.callPackage ./frontend { };

        default = pkgs.callPackage ./backend { inherit craneLib frontend; };
      in
      {
        checks = {
          inherit default;
        };

        packages = {
          inherit frontend default;
        };

        devShells.default = craneLib.devShell {
          inputsFrom = [
            frontend
            default
          ];

          packages = [
            pkgs.rust-analyzer
          ];
        };
      }
    );
}
