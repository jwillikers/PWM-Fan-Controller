{
  inputs = {
    advisory-db = {
      flake = false;
      url = "github:rustsec/advisory-db";
    };
    crane.url = "github:ipetkov/crane";
    flake-utils.url = "github:numtide/flake-utils";
    nix-update-scripts.url = "github:jwillikers/nix-update-scripts";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    pre-commit-hooks = {
      url = "github:cachix/pre-commit-hooks.nix";
      inputs = {
        nixpkgs.follows = "nixpkgs";
      };
    };
    rust-overlay = {
      inputs = {
        nixpkgs.follows = "nixpkgs";
      };
      url = "github:oxalica/rust-overlay";
    };
    treefmt-nix.url = "github:numtide/treefmt-nix";
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
        treefmt.config = {
          programs = {
            actionlint.enable = true;
            jsonfmt.enable = true;
            just.enable = true;
            nixfmt.enable = true;
            rustfmt.enable = true;
            statix.enable = true;
            taplo.enable = true;
            typos.enable = true;
            yamlfmt.enable = true;
          };
          projectRootFile = "flake.nix";
          settings.formatter.typos.excludes = [
            "*.avif"
            "*.bmp"
            "*.gif"
            "*.jpeg"
            "*.jpg"
            "*.png"
            "*.svg"
            "*.tiff"
            "*.webp"
            ".vscode/settings.json"
          ];
        };
        treefmtEval = treefmt-nix.lib.evalModule pkgs treefmt.config;
        pre-commit = pre-commit-hooks.lib.${system}.run {
          src = ./.;
          hooks = {
            check-added-large-files.enable = true;
            check-builtin-literals.enable = true;
            check-case-conflicts.enable = true;
            check-executables-have-shebangs.enable = true;

            # todo Not integrated with Nix?
            check-format = {
              enable = true;
              entry = "${treefmtEval.config.build.wrapper}/bin/treefmt --fail-on-change";
            };

            check-json.enable = true;
            check-shebang-scripts-are-executable.enable = true;
            check-toml.enable = true;
            check-yaml.enable = true;
            # todo Is it possible to support clippy as a pre-commit hook for a workspace project like this?
            # clippy.enable = true;
            deadnix.enable = true;
            detect-private-keys.enable = true;
            editorconfig-checker.enable = true;
            end-of-file-fixer.enable = true;
            fix-byte-order-marker.enable = true;
            flake-checker.enable = true;
            forbid-new-submodules.enable = true;
            # todo Enable lychee when asciidoc is supported.
            # See https://github.com/lycheeverse/lychee/issues/291
            # lychee.enable = true;
            mixed-line-endings.enable = true;
            nil.enable = true;

            strip-location-metadata = {
              name = "Strip location metadata";
              description = "Strip geolocation metadata from image files";
              enable = true;
              entry = "${pkgs.exiftool}/bin/exiftool -duplicates -overwrite_original '-gps*='";
              package = pkgs.exiftool;
              types = [ "image" ];
            };
            trim-trailing-whitespace.enable = true;
            yamllint.enable = true;
          };
        };
        boards = {
          attiny85 = {
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
                # Nix doesn't really support target JSON files specified in the toolchain and even if it did, it won't be ablet to build a toolchain for AVR.
                # The AVR toolchain is unstable and does not include std.
                targets = [ p.stdenv.hostPlatform.rust.rustcTarget ];
              };
            rustToolchain = boards.attiny85.rustToolchainFor pkgs;

            craneLib = (crane.mkLib pkgs).overrideToolchain boards.attiny85.rustToolchainFor;
            nativeBuildInputs =
              with pkgs;
              [
                avrdude
                boards.attiny85.avrCrossPkgs.avrlibc
                boards.attiny85.avrCrossPkgs.buildPackages.binutils
                boards.attiny85.avrCrossPkgs.buildPackages.gcc
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
                  (boards.attiny85.craneLib.filterCargoSources path type)
                  || (builtins.baseNameOf path == "avr-unknown-none-attiny85.json");
              };

              cargoVendorDir = boards.attiny85.craneLib.vendorMultipleCargoDeps {
                inherit (boards.attiny85.craneLib.findCargoFiles boards.attiny85.commonArgs.src) cargoConfigs;
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
                  "${boards.attiny85.rustToolchain.passthru.availableComponents.rust-src}/lib/rustlib/src/rust/Cargo.lock"
                ];
              };
              cargoExtraArgs = "--target avr-unknown-none-attiny85.json -Z build-std=core";
              inherit (boards.attiny85) nativeBuildInputs;

              extraDummyScript = ''
                cp --archive ${./boards/attiny85/avr-unknown-none-attiny85.json} $out/avr-unknown-none-attiny85.json
                rm --force --recursive $out/src/bin/crane-dummy-*
              '';
            };

            cargoArtifacts = boards.attiny85.craneLib.buildDepsOnly boards.attiny85.commonArgs;

            packages.pwm-fan-controller = pkgs.callPackage ./boards/attiny85/default.nix {
              inherit (boards.attiny85) cargoArtifacts;
              inherit (boards.attiny85) commonArgs;
              inherit (boards.attiny85) craneLib;
              inherit (boards.attiny85.avrCrossPkgs) stdenv;
            };
            apps = {
              flash = {
                avrdude =
                  let
                    script = pkgs.writeShellApplication {
                      name = "flash-avrdude";
                      runtimeInputs = with pkgs; [ avrdude ];
                      text = ''
                        ${pkgs.avrdude}/bin/avrdude -c USBtiny -B 4 -p attiny85 -U flash:w:${
                          self.packages.${system}.pwm-fan-controller-attiny85
                        }/bin/pwm-fan-controller-attiny85.hex:i
                      '';
                    };
                  in
                  {
                    type = "app";
                    program = "${script}/bin/flash-avrdude";
                  };
              };
            };
            devShell =
              with boards.attiny85;
              craneLib.devShell {
                env = {
                  # Required by rust-analyzer
                  # todo Check if I actually need this.
                  RUST_SRC_PATH = "${boards.attiny85.rustToolchain.passthru.availableComponents.rust-src}/lib/rustlib/src/rust/library";
                };
                packages =
                  boards.attiny85.nativeBuildInputs
                  ++ [
                    treefmtEval.config.build.wrapper
                    # Make formatters available for IDE's.
                    (pkgs.lib.attrValues treefmtEval.config.build.programs)
                  ]
                  ++ pre-commit.enabledPackages;
                inherit (pre-commit) shellHook;
              };
          };
          pico = {
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
                  path: type:
                  (boards.pico.craneLib.filterCargoSources path type) || (builtins.baseNameOf path == "memory.x");
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

            cargoArtifacts = boards.pico.craneLib.buildDepsOnly boards.pico.commonArgs;

            apps = {
              flash = {
                elf2uf2-rs =
                  let
                    script = pkgs.writeShellApplication {
                      name = "flash-elf2uf2-rs";
                      runtimeInputs = with pkgs; [ elf2uf2-rs ];
                      text = ''
                        ${pkgs.elf2uf2-rs}/bin/elf2uf2-rs --deploy ${
                          self.packages.${system}.pwm-fan-controller-pico
                        }/bin/pwm-fan-controller-pico
                      '';
                    };
                  in
                  {
                    type = "app";
                    program = "${script}/bin/flash-elf2uf2-rs";
                  };
              };
              run = {
                probe-rs =
                  let
                    script = pkgs.writeShellApplication {
                      name = "run-probe-rs";
                      runtimeInputs = with pkgs; [ probe-rs ];
                      text = ''
                        ${pkgs.probe-rs}/bin/probe-rs run --chip RP2040 --protocol swd ${
                          self.packages.${system}.pwm-fan-controller-pico
                        }/bin/pwm-fan-controller-pico
                      '';
                    };
                  in
                  {
                    type = "app";
                    program = "${script}/bin/run-probe-rs";
                  };
              };
            };
            devShell = boards.pico.craneLib.devShell {
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
            packages.pwm-fan-controller = pkgs.callPackage ./boards/pico/default.nix {
              inherit (boards.pico) commonArgs;
              inherit (boards.pico) cargoArtifacts;
              inherit (boards.pico) craneLib;
            };
          };
          qt-py-ch32v203 = {
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
                  path: type:
                  (boards.qt-py-ch32v203.craneLib.filterCargoSources path type)
                  || (builtins.baseNameOf path == "memory.x");
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

            cargoArtifacts = boards.qt-py-ch32v203.craneLib.buildDepsOnly boards.qt-py-ch32v203.commonArgs;
            apps = {
              flash = {
                wchisp =
                  let
                    script = pkgs.writeShellApplication {
                      name = "flash-wchisp";
                      runtimeInputs = with pkgs; [ wchisp ];
                      text = ''
                        ${pkgs.wchisp}/bin/wchisp flash ${
                          self.packages.${system}.pwm-fan-controller-qt-py-ch32v203
                        }/bin/pwm-fan-controller-qt-py-ch32v203
                      '';
                    };
                  in
                  {
                    type = "app";
                    program = "${script}/bin/flash-wchisp";
                  };
              };
            };
            devShell = boards.qt-py-ch32v203.craneLib.devShell {
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
            packages.pwm-fan-controller = pkgs.callPackage ./boards/qt-py-ch32v203/default.nix {
              inherit (boards.qt-py-ch32v203) cargoArtifacts;
              inherit (boards.qt-py-ch32v203) commonArgs;
              inherit (boards.qt-py-ch32v203) craneLib;
            };
          };
        };
      in
      {
        apps = {
          inherit (nix-update-scripts.apps.${system}) update-nix-direnv;
          attiny85.flash.avrdude = boards.attiny85.apps.flash.avrdude;
          default = self.apps.${system}.attiny85.flash.avrdude;
          pico.flash.elf2uf2-rs = boards.pico.apps.flash.elf2uf2-rs;
          pico.run.probe-rs = boards.pico.apps.run.probe-rs;
          qt-py-ch32v203.flash.wchisp = boards.qt-py-ch32v203.apps.flash.wchisp;
        };
        checks = {
          attiny85-pwm-fan-controller = boards.attiny85.pwm-fan-controller;
          pico-pwm-fan-controller = boards.pico.pwm-fan-controller;
          qt-py-ch32v203-pwm-fan-controller = boards.qt-py-ch32v203.pwm-fan-controller;

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
        devShells = {
          attiny85 = boards.attiny85.devShell;
          default = pkgs.mkShell {
            nativeBuildInputs =
              commonNativeBuildInputs
              ++ [
                treefmtEval.config.build.wrapper
                # Make formatters available for IDE's.
                (pkgs.lib.attrValues treefmtEval.config.build.programs)
              ]
              ++ pre-commit.enabledPackages;
            inherit (pre-commit) shellHook;
          };
          pico = boards.pico.devShell;
          qt-py-ch32v203 = boards.qt-py-ch32v203.devShell;
        };
        formatter = treefmtEval.config.build.wrapper;
        packages = {
          default = self.packages.${system}.pwm-fan-controller-attiny85;
          pwm-fan-controller-attiny85 = boards.attiny85.packages.pwm-fan-controller;
          # todo Why can't it be pwm-fan-controller.pico?
          pwm-fan-controller-pico = boards.pico.packages.pwm-fan-controller;
          pwm-fan-controller-qt-py-ch32v203 = boards.qt-py-ch32v203.packages.pwm-fan-controller;

          # attiny85-llvm-coverage = craneLibLLvmTools.cargoLlvmCov (boards.attiny85.commonArgs // {
          #   cargoArtifacts = boards.attiny85.cargoArtifacts;
          # });
        };
      }
    );
}
