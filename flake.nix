# https://github.com/NixOS/nixpkgs/blob/master/doc/languages-frameworks/rust.section.md
# https://github.com/oxalica/rust-overlay
# https://github.com/oxalica/rust-overlay/blob/660018f3a78e1f83e4e4aa569d9c6e2a31b0222c/docs/cross_compilation.md
# https://github.com/oxalica/rust-overlay/issues?q=is%3Aissue+callPackage+is%3Aclosed
# https://github.com/ipetkov/crane/blob/master/examples/cross-rust-overlay/flake.nix
# https://github.com/alekseysidorov/nixpkgs-rust-service-example/blob/main/flake.nix
# https://github.com/nix-community/naersk/blob/ee7edec50b49ab6d69b06d62f1de554efccb1ccd/examples/static-musl/flake.nix
# https://github.com/ipetkov/crane/blob/master/examples/cross-rust-overlay/flake.nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    crane.url = "github:ipetkov/crane";
    flake-utils.url = "github:numtide/flake-utils";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
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
              devShell = pkgs.mkShell {
                nativeBuildInputs = boards.pico.nativeBuildInputs;
              };
              # todo Figure out why this somehow activates the ATtiny85 shell.
              # devShell = boards.pico.craneLib.devShell {
              #   checks = self.checks.${system};
              #   nativeBuildInputs = boards.pico.nativeBuildInputs;
              # };
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
          };
        in
        {
          checks = {
            inherit (boards.attiny85.pwm-fan-controller);
          };
          packages = {
            # default = boards.attiny85.pwm-fan-controller;
            default = boards.pico.pwm-fan-controller;
            # pwm-fan-controller-attiny85 = boards.attiny85.pwm-fan-controller;
            # todo Why can't it be pwm-fan-controller.pico?
            pwm-fan-controller-pico = boards.pico.pwm-fan-controller;
          };
          devShells = {
            attiny85 = boards.attiny85.devShell;
            default = boards.attiny85.devShell;
            pico = boards.pico.devShell;
          };
          apps = {
            attiny85.flash.avrdude = boards.attiny85.apps.flash.avrdude;
            # default = boards.attiny85.apps.flash.avrdude;
            default = boards.pico.apps.flash.elf2uf2-rs;
            pico.flash.elf2uf2-rs = boards.pico.apps.flash.elf2uf2-rs;
            pico.run.probe-rs = boards.pico.apps.run.probe-rs;
          };
        }
      );
}
