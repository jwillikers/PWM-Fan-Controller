{
  inputs = {
    advisory-db = {
      flake = false;
      url = "github:rustsec/advisory-db";
    };
    crane.url = "github:ipetkov/crane";
    flake-utils.url = "github:numtide/flake-utils";
    nix-update-scripts = {
      url = "github:jwillikers/nix-update-scripts";
      inputs = {
        flake-utils.follows = "flake-utils";
        nixpkgs.follows = "nixpkgs";
        pre-commit-hooks.follows = "pre-commit-hooks";
        treefmt-nix.follows = "treefmt-nix";
      };
    };
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    pre-commit-hooks = {
      url = "github:cachix/pre-commit-hooks.nix";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        nixpkgs-stable.follows = "nixpkgs";
      };
    };
    rust-overlay = {
      inputs = {
        nixpkgs.follows = "nixpkgs";
      };
      url = "github:oxalica/rust-overlay";
    };
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs =
    {
      # deadnix: skip
      self,
      advisory-db,
      crane,
      flake-utils,
      nix-update-scripts,
      nixpkgs,
      pre-commit-hooks,
      rust-overlay,
      treefmt-nix,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        defaultBoard = "attiny85";
        overlays = [ (import rust-overlay) ];
        pkgs = import nixpkgs {
          inherit overlays system;
        };
        commonNativeBuildInputs = with pkgs; [
          asciidoctor
          clippy
          fish
          just
          lychee
          nil
          nushell
        ];
        pre-commit = pre-commit-hooks.lib.${system}.run (
          import ./pre-commit-hooks.nix { inherit pkgs treefmtEval; }
        );
        treefmtEval = treefmt-nix.lib.evalModule pkgs ./treefmt.nix;
        boards = {
          attiny85 = rec {
            # The development shell requires the GCC AVR toolchain to be available.
            # Thus, this cross-compilation configuration here does the trick.
            avrCrossPkgs = import nixpkgs {
              inherit overlays system;
              config.allowUnsupportedSystem = true;
              crossSystem = {
                inherit overlays;
                config = "avr";
                # todo Configure Rust for the proper cross-compilation target when that can be done for target without std.
                # Perhaps once AVR is stabilized for Rust this will be possible?
                # rust.rustcTarget = "avr-unknown-none-attiny85";
                # rust.platform = nixpkgs.lib.importJSON "${./boards/attiny85/avr-unknown-none-attiny85.json}";
                # rustc = {
                # config = "avr-unknown-none-attiny85";
                # platform = nixpkgs.lib.importJSON "${./boards/attiny85/avr-unknown-none-attiny85.json}";
                # };
              };
            };
            rustToolchainFor =
              p:
              (p.rust-bin.fromRustupToolchainFile ./boards/attiny85/rust-toolchain.toml).override {
                # Remove the avr-unknown-none-attiny85.json file from the list of targets for the Rust toolchain.
                # Nix doesn't really support target JSON files specified in the toolchain and even if it did, it won't be able to build a toolchain for AVR.
                # The AVR toolchain is unstable and does not include std.
                targets = [ p.stdenv.hostPlatform.rust.rustcTarget ];
              };
            rustToolchain = rustToolchainFor pkgs;

            craneLib = (crane.mkLib pkgs).overrideToolchain rustToolchainFor;
            nativeBuildInputs =
              with pkgs;
              [
                avrdude
                avrCrossPkgs.avrlibc
                avrCrossPkgs.buildPackages.binutils
                avrCrossPkgs.buildPackages.gcc
                cargo-binutils
                # ravedude
              ]
              ++ commonNativeBuildInputs;

            commonArgs = {
              pname = "pwm-fan-controller-attiny85";
              strictDeps = true;
              doCheck = false;

              src = pkgs.lib.cleanSourceWith {
                src = ./boards/attiny85;
                # Don't remove the avr-unknown-none-attiny85.json file from the sources.
                # See https://github.com/ipetkov/crane/issues/444
                filter =
                  path: type:
                  (craneLib.filterCargoSources path type)
                  || (builtins.baseNameOf path == "avr-unknown-none-attiny85.json");
              };

              cargoVendorDir = craneLib.vendorMultipleCargoDeps {
                inherit (craneLib.findCargoFiles commonArgs.src) cargoConfigs;
                cargoLockList = [
                  ./boards/attiny85/Cargo.lock

                  # Unfortunately this approach requires IFD (import-from-derivation)
                  # otherwise Nix will refuse to read the Cargo.lock from our toolchain
                  # (unless we build with `--impure`).
                  #
                  # Another way around this is to manually copy the rustlib `Cargo.lock`
                  # to the repo and import it with `./path/to/rustlib/Cargo.lock` which
                  # will avoid IFD entirely but will require manually keeping the file
                  # up to date!
                  "${rustToolchain.passthru.availableComponents.rust-src}/lib/rustlib/src/rust/Cargo.lock"
                  # "${rustToolchain.passthru.availableComponents.rust-src}/lib/rustlib/src/rust/library/Cargo.lock"
                ];
              };
              cargoExtraArgs = "--target avr-unknown-none-attiny85.json -Z build-std=core";
              inherit nativeBuildInputs;

              extraDummyScript = ''
                cp --archive ${./boards/attiny85/avr-unknown-none-attiny85.json} $out/avr-unknown-none-attiny85.json
                (shopt -s globstar; rm --force --recursive $out/**/src/bin/crane-dummy-*)
              '';
              #   # rm --force --recursive $out/src/bin/crane-dummy-*
            };

            cargoArtifacts = craneLib.buildDepsOnly commonArgs;

            packages.pwm-fan-controller = pkgs.callPackage ./boards/attiny85/package.nix {
              inherit cargoArtifacts commonArgs craneLib;
              inherit (avrCrossPkgs) stdenv;
            };
            apps.flash = {
              type = "app";
              program = builtins.toString (
                pkgs.writers.writeNu "flash-avrdude" ''
                  ^${pkgs.lib.getExe pkgs.avrdude} -c USBtiny -B 4 -p attiny85 -U flash:w:${
                    self.packages.${system}.pwm-fan-controller-attiny85
                  }/bin/pwm-fan-controller-attiny85.hex:i
                ''
              );
            };
            devShell = craneLib.devShell {
              env = {
                # Required by rust-analyzer
                # todo Check if I actually need this.
                RUST_SRC_PATH = "${rustToolchain.passthru.availableComponents.rust-src}/lib/rustlib/src/rust/library";
              };
              packages =
                nativeBuildInputs
                ++ [
                  treefmtEval.config.build.wrapper
                  # Make formatters available for IDE's.
                  (pkgs.lib.attrValues treefmtEval.config.build.programs)
                ]
                ++ pre-commit.enabledPackages;
              inherit (pre-commit) shellHook;
            };
          };
          pico = rec {
            craneLib = (crane.mkLib pkgs).overrideToolchain (
              p: p.rust-bin.fromRustupToolchainFile ./boards/pico/rust-toolchain.toml
            );

            commonArgs = {
              pname = "pwm-fan-controller-pico";
              strictDeps = true;
              doCheck = false;

              src = pkgs.lib.cleanSourceWith {
                src = ./boards/pico;
                # Don't remove the memory.x linker script file from the sources.
                filter =
                  path: type: (craneLib.filterCargoSources path type) || (builtins.baseNameOf path == "memory.x");
              };

              # Need to make the memory.x linker script available to the dummy crate.
              # See https://github.com/ipetkov/crane/issues/444
              # Should I symlink instead of copy?
              # ln --symbolic ${./memory.x} memory.x
              CARGO_TARGET_THUMBV6M_NONE_EABI_RUSTFLAGS = "-C link-arg=--library-path=.";
              extraDummyScript = ''
                cp --archive ${./boards/pico/memory.x} $out/memory.x
                rm --force --recursive $out/src/bin/crane-dummy-*
              '';

              cargoExtraArgs = "--target thumbv6m-none-eabi";

              nativeBuildInputs = with pkgs; [
                flip-link
              ];
            };

            cargoArtifacts = craneLib.buildDepsOnly commonArgs;

            apps = {
              flash = {
                type = "app";
                program = builtins.toString (
                  pkgs.writers.writeNu "flash-elf2uf2-rs" ''
                    ^${pkgs.lib.getExe pkgs.elf2uf2-rs} --deploy ${
                      self.packages.${system}.pwm-fan-controller-pico
                    }/bin/pwm-fan-controller-pico
                  ''
                );
              };
              run = {
                type = "app";
                program = builtins.toString (
                  pkgs.writers.writeNu "run-probe-rs" ''
                    ${pkgs.lib.getExe pkgs.probe-rs} run --chip RP2040 --protocol swd ${
                      self.packages.${system}.pwm-fan-controller-pico
                    }/bin/pwm-fan-controller-pico
                  ''
                );
              };
            };
            devShell = craneLib.devShell {
              packages =
                with pkgs;
                [
                  elf2uf2-rs
                  flip-link
                  probe-rs
                  treefmtEval.config.build.wrapper
                  # Make formatters available for IDE's.
                  (pkgs.lib.attrValues treefmtEval.config.build.programs)
                ]
                ++ commonArgs.nativeBuildInputs
                ++ commonNativeBuildInputs
                ++ pre-commit.enabledPackages;
              inherit (pre-commit) shellHook;
            };
            packages.pwm-fan-controller = pkgs.callPackage ./boards/pico/package.nix {
              inherit commonArgs cargoArtifacts craneLib;
            };
          };
          qt-py-ch32v203 = rec {
            craneLib = (crane.mkLib pkgs).overrideToolchain (
              p: p.rust-bin.fromRustupToolchainFile ./boards/qt-py-ch32v203/rust-toolchain.toml
            );

            commonArgs = {
              pname = "pwm-fan-controller-qt-py-ch32v203";
              strictDeps = true;
              doCheck = false;

              src = pkgs.lib.cleanSourceWith {
                src = ./boards/qt-py-ch32v203;
                # Don't remove the memory.x linker script file from the sources.
                filter =
                  path: type: (craneLib.filterCargoSources path type) || (builtins.baseNameOf path == "memory.x");
              };

              # Need to make the memory.x linker script available to the dummy crate.
              # See https://github.com/ipetkov/crane/issues/444
              # Should I symlink instead of copy?
              # ln --symbolic ${./memory.x} memory.x
              CARGO_TARGET_RISCV32IMAC_UNKNOWN_NONE_ELF_RUSTFLAGS = "-C link-arg=--library-path=.";
              extraDummyScript = ''
                cp --archive ${./boards/qt-py-ch32v203/memory.x} $out/memory.x
                rm --force --recursive $out/src/bin/crane-dummy-*
              '';

              cargoExtraArgs = "--target riscv32imac-unknown-none-elf";
            };

            cargoArtifacts = craneLib.buildDepsOnly commonArgs;
            apps.flash = {
              type = "app";
              program = builtins.toString (
                pkgs.writers.writeNu "flash-wchisp" ''
                  ^${pkgs.lib.getExe pkgs.wchisp} flash ${
                    self.packages.${system}.pwm-fan-controller-qt-py-ch32v203
                  }/bin/pwm-fan-controller-qt-py-ch32v203
                ''
              );
            };
            devShell = craneLib.devShell {
              packages =
                with pkgs;
                [
                  wchisp
                  # probe-rs
                  treefmtEval.config.build.wrapper
                  # Make formatters available for IDE's.
                  (pkgs.lib.attrValues treefmtEval.config.build.programs)
                ]
                ++ commonNativeBuildInputs
                ++ pre-commit.enabledPackages;
              inherit (pre-commit) shellHook;
            };
            packages.pwm-fan-controller = pkgs.callPackage ./boards/qt-py-ch32v203/package.nix {
              inherit (boards.qt-py-ch32v203) cargoArtifacts;
              inherit (boards.qt-py-ch32v203) commonArgs;
              inherit (boards.qt-py-ch32v203) craneLib;
            };
          };
        };
      in
      {
        apps = pkgs.lib.attrsets.genAttrs (builtins.attrNames boards) (board: boards.${board}.apps) // {
          inherit (nix-update-scripts.apps.${system}) update-nix-direnv update-nixos-release;
          default = self.apps.${system}.${defaultBoard}.flash;
        };
        checks = {
          # attiny85-pwm-fan-controller = boards.attiny85.pwm-fan-controller;
          # pico-pwm-fan-controller = boards.pico.pwm-fan-controller;
          # qt-py-ch32v203-pwm-fan-controller = boards.qt-py-ch32v203.pwm-fan-controller;

          attiny85-clippy = boards.attiny85.craneLib.cargoClippy (
            boards.attiny85.commonArgs
            // {
              inherit (boards.attiny85) cargoArtifacts;
              cargoClippyExtraArgs = "--all-targets -- --deny warnings";
            }
          );
          pico-clippy = boards.pico.craneLib.cargoClippy (
            boards.pico.commonArgs
            // {
              inherit (boards.pico) cargoArtifacts;
              cargoClippyExtraArgs = "--all-targets -- --deny warnings";
            }
          );
          qt-py-ch32v203-clippy = boards.qt-py-ch32v203.craneLib.cargoClippy (
            boards.qt-py-ch32v203.commonArgs
            // {
              inherit (boards.qt-py-ch32v203) cargoArtifacts;
              cargoClippyExtraArgs = "--all-targets -- --deny warnings";
            }
          );

          # attiny85.doc = craneLib.cargoDoc (boards.attiny85.commonArgs // {
          #   cargoArtifacts = boards.attiny85.cargoArtifacts;
          # });
          # pico.doc = craneLib.cargoDoc (boards.pico.commonArgs // {
          #   cargoArtifacts = boards.pico.cargoArtifacts;
          # });
          # qt-py-ch32v203.doc = craneLib.cargoDoc (boards.qt-py-ch32v203.commonArgs // {
          #   cargoArtifacts = boards.qt-py-ch32v203.cargoArtifacts;
          # });

          # attiny85.rustfmt = craneLib.cargoFmt {
          #   src = boards.attiny85.src;
          # };
          # pico.rustfmt = craneLib.cargoFmt {
          #   src = boards.pico.src;
          # };
          # qt-py-ch32v203.rustfmt = craneLib.cargoFmt {
          #   src = boards.qt-py-ch32v203.src;
          # };

          # attiny85.toml-fmt = craneLib.taploFmt {
          #   src = pkgs.lib.sources.sourceFilesBySuffices src [ ".toml" ];
          #   # taplo arguments can be further customized below as needed
          #   # taploExtraArgs = "--config ./taplo.toml";
          # };

          # Audit dependencies
          attiny85-audit = boards.attiny85.craneLib.cargoAudit {
            inherit advisory-db;
            inherit (boards.attiny85.commonArgs) src;
          };
          pico-audit = boards.pico.craneLib.cargoAudit {
            inherit advisory-db;
            inherit (boards.pico.commonArgs) src;
          };
          qt-py-ch32v203-audit = boards.qt-py-ch32v203.craneLib.cargoAudit {
            inherit advisory-db;
            inherit (boards.qt-py-ch32v203.commonArgs) src;
          };

          # Audit licenses
          attiny85-deny = boards.attiny85.craneLib.cargoDeny {
            inherit (boards.attiny85.commonArgs) src;
          };
          pico-deny = boards.pico.craneLib.cargoDeny {
            inherit (boards.pico.commonArgs) src;
          };
          qt-py-ch32v203-deny = boards.qt-py-ch32v203.craneLib.cargoDeny {
            inherit (boards.qt-py-ch32v203.commonArgs) src;
          };

          # Run tests with cargo-nextest
          # Consider setting `doCheck = false` on `my-crate` if you do not want
          # the tests to run twice
          # attiny85.nextest = craneLib.cargoNextest (boards.attiny85.commonArgs // {
          #   cargoArtifacts = boards.attiny85.cargoArtifacts;
          #   partitions = 1;
          #   partitionType = "count";
          # });
        };
        devShells =
          pkgs.lib.attrsets.genAttrs (builtins.attrNames boards) (board: boards.${board}.devShell)
          // {
            default = pkgs.mkShell {
              nativeBuildInputs =
                commonNativeBuildInputs
                ++ [
                  treefmtEval.config.build.wrapper
                  # Make formatters available for IDE's.
                  (builtins.attrValues treefmtEval.config.build.programs)
                ]
                ++ pre-commit.enabledPackages;
              inherit (pre-commit) shellHook;
            };
          };
        formatter = treefmtEval.config.build.wrapper;
        packages =
          pkgs.lib.attrsets.genAttrs (builtins.attrNames boards) (
            board: boards.${board}.packages.pwm-fan-controller
          )
          // {
            default = self.packages.${system}.${defaultBoard};
            # attiny85-llvm-coverage = craneLibLLvmTools.cargoLlvmCov (boards.attiny85.commonArgs // {
            #   cargoArtifacts = boards.attiny85.cargoArtifacts;
            # });
          };
      }
    );
}
