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
          nativePkgs = import nixpkgs {
            inherit overlays system;
          };
          # commonNativeBuildInputs = [
          #   clippy
          #   fish
          #   just
          #   nushell
          #   pre-commit
          #   rustfmt
          #   yamllint
          # ];
          boards = {
            attiny85 = {
              rustToolchain = nativePkgs.pkgsBuildHost.rust-bin.fromRustupToolchainFile ./boards/attiny85/rust-toolchain.toml;
              pkgs = import nixpkgs {
                inherit overlays system;
                # crossSystem = {
                  # config = "avr";
                  # rust.platform = "${./boards/attiny85/avr-unknown-none-attiny85.json}";
                  # rust.isNoStdTarget = true;
                # };
                # config.allowUnsupportedSystem = true;
              };
              commonNativeBuildInputs = with nativePkgs; [
                clippy
                fish
                just
                nushell
                pre-commit
                rustfmt
                yamllint
              ];
              nativeBuildInputs = with nativePkgs; [
                # unique
                avrdude
                cargo-binutils
                # ravedude
                boards.attiny85.rustToolchain
              ] ++ boards.attiny85.commonNativeBuildInputs;
              # todo This does not work yet.
              # pwm-fan-controller = pkgs.callPackage "./boards/attiny85/default.nix" { };
              devShell = with boards.attiny85; boards.attiny85.pkgs.mkShell {
                # checks = self.checks.${system};
                inherit nativeBuildInputs;
              };
              app = flake-utils.lib.mkApp {
                runtimeInputs = [boards.attiny85.nativeBuildInputs.avrdude];
                drv = nativePkgs.writeScriptBin "flash-pwm-fan-controller-attiny85" ''
                  ${boards.attiny85.nativeBuildInputs.avrdude} -c USBtiny -B 4 -p attiny85 -U flash:w:${self.packages.${system}.pwm-fan-controller.attiny85}/bin/attiny85-pwm-fan-controller.hex:i
                '';
              };
            };
            pico = {
              pkgs = import nixpkgs {
                inherit overlays system;
                # This causes all packages that depend on Rust to be rebuilt.
                # crossSystem = {
                #   config = "arm-none-eabi";
                #   rust.rustcTarget = "thumbv6m-none-eabi";
                # };
              };
              commonNativeBuildInputs = with boards.pico.pkgs; [
                clippy
                fish
                just
                nushell
                pre-commit
                rustfmt
                yamllint
              ];
              nativeBuildInputs = with boards.pico.pkgs; [
                elf2uf2-rs
                flip-link
                probe-run
              ] ++ boards.pico.commonNativeBuildInputs;
              buildInputs = with boards.pico.pkgs; [];
              craneLib = (crane.mkLib boards.pico.pkgs).overrideToolchain (p: p.rust-bin.stable.latest.default.override {
                extensions = [ "llvm-tools-preview" ];
                targets = [ "thumbv6m-none-eabi" ];
              });
              pwm-fan-controller = with boards.pico.pkgs; callPackage ./boards/pico/default.nix {
                craneLib = boards.pico.craneLib;
              };
              devShell = boards.pico.craneLib.devShell {
                checks = self.checks.${system};
                nativeBuildInputs = boards.pico.nativeBuildInputs;
              };
              app-elf2uf2-rs = flake-utils.lib.mkApp {
                runtimeInputs = [boards.pico.nativeBuildInputs.probe-run];
                drv = nativePkgs.writeScriptBin "flash-pwm-fan-controller-pico" ''
                  cd ./boards/pico
                  # ${boards.pico.nativeBuildInputs.cargo}/bin/cargo run --bin ${self.packages.${system}.pwm-fan-controller.pico}/bin/pwm-fan-controller-pico
                  # ${boards.pico.nativeBuildInputs.elf2uf2-rs}/bin/elf2uf2-rs
                '';
              };
              probe-run-rs = flake-utils.lib.mkApp {
                runtimeInputs = [boards.pico.nativeBuildInputs.probe-run];
                drv = nativePkgs.writeScriptBin "flash-pwm-fan-controller-pico" ''
                  cd ./boards/pico
                  ${boards.pico.nativeBuildInputs.cargo}/bin/cargo run --bin ${self.packages.${system}.pwm-fan-controller.pico}/bin/pwm-fan-controller-pico
                  # ${boards.pico.nativeBuildInputs.probe-run}/bin/probe-run --chip RP2040
                '';
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
            # pwm-fan-controller.attiny85 = boards.attiny85.pwm-fan-controller;
            pwm-fan-controller.pico = boards.pico.pwm-fan-controller;
          };
          devShells = {
            attiny85 = boards.attiny85.devShell;
            default = boards.attiny85.devShell;
            pico = boards.pico.devShell;
          };
          apps = {
            # attiny85 = boards.attiny85.app;
            # default = boards.attiny85.app;
            default = boards.pico.app-probe-run;
            pico.elf2uf2-rs = boards.pico.app-elf2uf2-rs;
            pico.probe-run = boards.pico.app-probe-run;
          };
        }
      );
}
