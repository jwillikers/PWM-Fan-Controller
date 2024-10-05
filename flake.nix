{
  inputs = {
    # nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs.url = "github:NixOS/nixpkgs/master";
    crane.url = "github:ipetkov/crane";
    flake-utils.url = "github:numtide/flake-utils";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs = {
        nixpkgs.follows = "nixpkgs";
      };
    };
  };
  outputs = { self, nixpkgs, crane, flake-utils, rust-overlay }:
    flake-utils.lib.eachDefaultSystem
      (system:
         let
          overlays = [ (import rust-overlay) ];
          pkgs = import nixpkgs {
            inherit overlays system;
          };
          commonNativeBuildInputs = with pkgs; [
            clippy
            fish
            imagemagick_light # To strip metadata from images.
            just
            nushell
            pre-commit
            rustfmt
            yamllint
          ];
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
                  # Perhaps once AVR is stabalized for Rust this will be possible?
                  # rust.rustcTarget = "avr-unknown-none-attiny85";
                  # rust.platform = nixpkgs.lib.importJSON "${./boards/attiny85/avr-unknown-none-attiny85.json}";
                  # rustc = {
                    # config = "avr-unknown-none-attiny85";
                    # platform = nixpkgs.lib.importJSON "${./boards/attiny85/avr-unknown-none-attiny85.json}";
                  # };
                };
              };
              rustToolchainFor = p: (p.rust-bin.fromRustupToolchainFile ./boards/attiny85/rust-toolchain.toml).override {
                # Remove the avr-unknown-none-attiny85.json file from the list of targets for the Rust toolchain.
                # Nix doesn't really support target JSON files specified in the toolchain and even if it did, it won't be ablet to build a toolchain for AVR.
                # The AVR toolchain is unstable and does not include std.
                targets = [ p.stdenv.hostPlatform.rust.rustcTarget ];
              };
              rustToolchain = boards.attiny85.rustToolchainFor pkgs;

              craneLib = (crane.mkLib pkgs).overrideToolchain boards.attiny85.rustToolchainFor;
              nativeBuildInputs = with pkgs; [
                avrdude
                boards.attiny85.avrCrossPkgs.avrlibc
                boards.attiny85.avrCrossPkgs.buildPackages.binutils
                boards.attiny85.avrCrossPkgs.buildPackages.gcc
                cargo-binutils
                # ravedude
              ] ++ commonNativeBuildInputs;

              # Common arguments can be set here to avoid repeating them later
              commonArgs = {
                pname = "pwm-fan-controller-attiny85";
                strictDeps = true;
                doCheck = false;

                src = pkgs.lib.cleanSourceWith {
                  src = ./boards/attiny85;
                  # Don't remove the avr-unknown-none-attiny85.json file from the sources.
                  # See https://github.com/ipetkov/crane/issues/444
                  filter = path: type: (boards.attiny85.craneLib.filterCargoSources path type) || (builtins.baseNameOf path == "avr-unknown-none-attiny85.json");
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
                nativeBuildInputs = boards.attiny85.nativeBuildInputs;

                extraDummyScript = ''
                  cp --archive ${./boards/attiny85/avr-unknown-none-attiny85.json} $out/avr-unknown-none-attiny85.json
                  rm --force --recursive $out/src/bin/crane-dummy-*
                '';
              };

              cargoArtifacts = boards.attiny85.craneLib.buildDepsOnly boards.attiny85.commonArgs;

              pwm-fan-controller = pkgs.callPackage ./boards/attiny85/default.nix {
                cargoArtifacts = boards.attiny85.cargoArtifacts;
                commonArgs = boards.attiny85.commonArgs;
                craneLib = boards.attiny85.craneLib;
                stdenv = boards.attiny85.avrCrossPkgs.stdenv;
              };
              devShell = with boards.attiny85; craneLib.devShell {
                env = {
                  # Required by rust-analyzer
                  # todo Check if I actually need this.
                  RUST_SRC_PATH = "${boards.attiny85.rustToolchain.passthru.availableComponents.rust-src}/lib/rustlib/src/rust/library";
                };
                checks = self.checks.${system};
                packages = boards.attiny85.nativeBuildInputs;
              };
              apps = {
                flash = {
                  avrdude = let
                    script = pkgs.writeShellApplication {
                      name = "flash-avrdude";
                      runtimeInputs = with pkgs; [avrdude];
                      text = ''
                        ${pkgs.avrdude}/bin/avrdude -c USBtiny -B 4 -p attiny85 -U flash:w:${self.packages.${system}.pwm-fan-controller-attiny85}/bin/pwm-fan-controller-attiny85.hex:i
                      '';
                    };
                  in {
                    type = "app";
                    program = "${script}/bin/flash-avrdude";
                  };
                };
              };
            };
            pico = {
              nativeBuildInputs = with pkgs; [
                elf2uf2-rs
                flip-link
                probe-rs
              ] ++ commonNativeBuildInputs;
              buildInputs = with pkgs; [];
              craneLib = (crane.mkLib pkgs).overrideToolchain (p: p.rust-bin.fromRustupToolchainFile ./boards/pico/rust-toolchain.toml);
              pwm-fan-controller = pkgs.callPackage ./boards/pico/default.nix {
                craneLib = boards.pico.craneLib;
              };
              devShell = boards.pico.craneLib.devShell {
                checks = self.checks.${system};
                packages = boards.pico.nativeBuildInputs;
              };
              apps = {
                flash = {
                  elf2uf2-rs = let
                    script = pkgs.writeShellApplication {
                      name = "flash-elf2uf2-rs";
                      runtimeInputs = with pkgs; [elf2uf2-rs];
                      text = ''
                        ${pkgs.elf2uf2-rs}/bin/elf2uf2-rs --deploy ${self.packages.${system}.pwm-fan-controller-pico}/bin/pwm-fan-controller-pico
                      '';
                    };
                  in {
                    type = "app";
                    program = "${script}/bin/flash-elf2uf2-rs";
                  };
                };
                run = {
                  probe-rs = let
                    script = pkgs.writeShellApplication {
                      name = "run-probe-rs";
                      runtimeInputs = with pkgs; [probe-rs];
                      text = ''
                        ${pkgs.probe-rs}/bin/probe-rs run --chip RP2040 --protocol swd ${self.packages.${system}.pwm-fan-controller-pico}/bin/pwm-fan-controller-pico
                      '';
                    };
                  in {
                    type = "app";
                    program = "${script}/bin/run-probe-rs";
                  };
                };
              };
            };
            qt-py-ch32v203 = {
              nativeBuildInputs = with pkgs; [
                wchisp
                # probe-rs
              ] ++ commonNativeBuildInputs;
              buildInputs = with pkgs; [];
              craneLib = (crane.mkLib pkgs).overrideToolchain (p: p.rust-bin.fromRustupToolchainFile ./boards/qt-py-ch32v203/rust-toolchain.toml);
              pwm-fan-controller = pkgs.callPackage ./boards/qt-py-ch32v203/default.nix {
                craneLib = boards.qt-py-ch32v203.craneLib;
              };
              devShell = boards.qt-py-ch32v203.craneLib.devShell {
                packages = boards.qt-py-ch32v203.nativeBuildInputs;
              };
              apps = {
                flash = {
                  wchisp = let
                    script = pkgs.writeShellApplication {
                      name = "flash-wchisp";
                      runtimeInputs = with pkgs; [wchisp];
                      text = ''
                        ${pkgs.wchisp}/bin/wchisp flash ${self.packages.${system}.pwm-fan-controller-qt-py-ch32v203}/bin/pwm-fan-controller-qt-py-ch32v203
                      '';
                    };
                  in {
                    type = "app";
                    program = "${script}/bin/flash-wchisp";
                  };
                };
              };
            };
          };
        in
        {
          checks = {
            inherit (boards.qt-py-ch32v203.pwm-fan-controller);
          };
          packages = {
            default = boards.attiny85.pwm-fan-controller;
            pwm-fan-controller-attiny85 = boards.attiny85.pwm-fan-controller;
            # todo Why can't it be pwm-fan-controller.pico?
            pwm-fan-controller-pico = boards.pico.pwm-fan-controller;
            pwm-fan-controller-qt-py-ch32v203 = boards.qt-py-ch32v203.pwm-fan-controller;
          };
          devShells = {
            attiny85 = boards.attiny85.devShell;
            default = boards.attiny85.devShell;
            pico = boards.pico.devShell;
            qt-py-ch32v203 = boards.qt-py-ch32v203.devShell;
          };
          apps = {
            attiny85.flash.avrdude = boards.attiny85.apps.flash.avrdude;
            default = boards.attiny85.apps.flash.avrdude;
            pico.flash.elf2uf2-rs = boards.pico.apps.flash.elf2uf2-rs;
            pico.run.probe-rs = boards.pico.apps.run.probe-rs;
            qt-py-ch32v203.flash.wchisp = boards.qt-py-ch32v203.apps.flash.wchisp;
          };
        }
      );
}
