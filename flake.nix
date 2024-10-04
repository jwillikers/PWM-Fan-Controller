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
            just
            nushell
            pre-commit
            rustfmt
            yamllint
          ];
          boards = {
            attiny85 = {
              rustToolchain = pkgs.pkgsBuildHost.rust-bin.fromRustupToolchainFile ./boards/attiny85/rust-toolchain.toml;
              # craneLib = (crane.mkLib pkgs).overrideToolchain (p: p.rust-bin.fromRustupToolchainFile ./boards/attiny85/rust-toolchain.toml);
              nativeBuildInputs = with pkgs; [
                avrdude
                cargo-binutils
                # ravedude
                boards.attiny85.rustToolchain
              ] ++ commonNativeBuildInputs;

              # The development shell requires the GCC AVR toolchain to be available.
              # Thus, this cross-compilation configuration here does the trick.
              avrCrossPkgs = import nixpkgs {
                inherit overlays system;
                crossSystem = {
                  inherit overlays;
                  config = "avr";
                };
              };
              # todo This does not work yet.
              # pwm-fan-controller = avrCrossPkgs.callPackage "./boards/attiny85/default.nix" { };
              devShell = with boards.attiny85; avrCrossPkgs.mkShell {
                # checks = self.checks.${system};
                inherit nativeBuildInputs;
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
              craneLib = (crane.mkLib pkgs).overrideToolchain (p: p.rust-bin.stable.latest.default.override {
                extensions = [ "llvm-tools-preview" ];
                targets = [ "thumbv6m-none-eabi" ];
              });
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
              craneLib = (crane.mkLib pkgs).overrideToolchain (p: p.rust-bin.nightly.latest.default.override {
                targets = [ "riscv32imac-unknown-none-elf" ];
              });
              pwm-fan-controller = pkgs.callPackage ./boards/qt-py-ch32v203/default.nix {
                craneLib = boards.qt-py-ch32v203.craneLib;
              };
              devShell = boards.qt-py-ch32v203.craneLib.devShell {
                packages = boards.qt-py-ch32v203.nativeBuildInputs;
                nativeBuildInputs = boards.qt-py-ch32v203.nativeBuildInputs;
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
            # default = boards.attiny85.pwm-fan-controller;
            default = boards.pico.pwm-fan-controller;
            # pwm-fan-controller-attiny85 = boards.attiny85.pwm-fan-controller;
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
            # default = boards.attiny85.apps.flash.avrdude;
            default = boards.pico.apps.flash.elf2uf2-rs;
            pico.flash.elf2uf2-rs = boards.pico.apps.flash.elf2uf2-rs;
            pico.run.probe-rs = boards.pico.apps.run.probe-rs;
            qt-py-ch32v203.flash.wchisp = boards.qt-py-ch32v203.apps.flash.wchisp;
          };
        }
      );
}
