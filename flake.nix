{
  description = "Declaratively bear (manage) Linux users and groups";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };

    pre-commit = {
      url = "github:cachix/pre-commit-hooks.nix";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-compat.follows = "flake-compat";
      };
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      ...
    }:
    let
      eachSystem = nixpkgs.lib.genAttrs [
        "x86_64-linux"
        "aarch64-linux"
      ];
    in
    {
      packages = eachSystem (
        system:
        (import ./nix/packages { pkgs = nixpkgs.legacyPackages.${system}; })
        // {
          default = self.packages.${system}.userborn;
        }
      );

      checks = eachSystem (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          userborn = self.packages.${system}.userborn;
          overlayedPkgs = pkgs.extend (_final: _prev: { inherit userborn; });
        in
        {
          clippy = userborn.overrideAttrs (
            _: previousAttrs: {
              pname = previousAttrs.pname + "-clippy";
              nativeCheckInputs = (previousAttrs.nativeCheckInputs or [ ]) ++ [ pkgs.clippy ];
              checkPhase = "cargo clippy";
            }
          );
          rustfmt = userborn.overrideAttrs (
            _: previousAttrs: {
              pname = previousAttrs.pname + "-rustfmt";
              nativeCheckInputs = (previousAttrs.nativeCheckInputs or [ ]) ++ [ pkgs.rustfmt ];
              checkPhase = "cargo fmt --check";
            }
          );
          # Check whether the vendored schema is up-to-date with the Rust
          # sources.
          vendored-schema = pkgs.runCommand "vendored-schema" { } ''
            ${pkgs.diffutils}/bin/diff --color ${./userborn.schema.json} ${userborn.dev}/userborn.schema.json
            touch $out
          '';
          pre-commit = inputs.pre-commit.lib.${system}.run {
            src = ./.;
            hooks = {
              nixfmt.enable = true;
              deadnix.enable = true;
              statix.enable = true;
            };
          };
          inherit (overlayedPkgs.nixosTests)
            userborn
            userborn-mutable-users
            userborn-mutable-etc
            userborn-immutable-users
            userborn-immutable-etc
            ;
        }
      );

      devShells = eachSystem (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            shellHook = ''
              ${self.checks.${system}.pre-commit.shellHook}
            '';

            packages = [
              pkgs.nix-eval-jobs
              pkgs.nixfmt
              pkgs.clippy
              pkgs.rustfmt
              pkgs.cargo-machete
              pkgs.cargo-edit
              pkgs.cargo-bloat
              pkgs.cargo-deny
              pkgs.cargo-cyclonedx
              pkgs.cargo-flamegraph
              pkgs.hyperfine
            ];

            inputsFrom = [ self.packages.${system}.userborn ];

            RUST_SRC_PATH = "${pkgs.rust.packages.stable.rustPlatform.rustLibSrc}";
          };

          ci = pkgs.mkShell {
            packages = [
              (pkgs.writeShellApplication {
                name = "eval-checks";

                runtimeInputs = [
                  pkgs.nix-eval-jobs
                  pkgs.jq
                ];

                text = ''
                  nix-eval-jobs --check-cache-status --flake .\#checks.x86_64-linux | jq -s 'map({attr, isCached})'
                '';
              })
            ];
          };
        }
      );

    };
}
