# https://github.com/NixOS/nixpkgs/blob/master/doc/languages-frameworks/rust.section.md
# https://github.com/oxalica/rust-overlay
# https://github.com/oxalica/rust-overlay/blob/660018f3a78e1f83e4e4aa569d9c6e2a31b0222c/docs/cross_compilation.md
# https://github.com/oxalica/rust-overlay/issues?q=is%3Aissue+callPackage+is%3Aclosed
# https://github.com/ipetkov/crane/blob/master/examples/cross-rust-overlay/flake.nix
# https://github.com/alekseysidorov/nixpkgs-rust-service-example/blob/main/flake.nix
# https://github.com/nix-community/naersk/blob/ee7edec50b49ab6d69b06d62f1de554efccb1ccd/examples/static-musl/flake.nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
      };
    };
  };
  outputs = { self, nixpkgs, flake-utils, rust-overlay }:
    flake-utils.lib.eachDefaultSystem
      (system:
         let
          overlays = [
            (import rust-overlay)
            # (self: super: {
            #   pkg = super.pkg.overrideAttrs (old: {
            #     doCheck = false;
            #   });
            # })
          ];
          pkgs = import nixpkgs {
            inherit system overlays;
          };
          # todo Try creating toolchain from avrCrossPkgs.
          rustToolchain = pkgs.pkgsBuildHost.rust-bin.fromRustupToolchainFile ./rust-toolchain.toml;

          avrCrossPkgs = import nixpkgs {
            inherit system overlays;
            crossSystem = {
              inherit overlays;
              config = "avr";
              # rust.rustcTarget = "${./avr-specs/avr-attiny85.json}";

              # todo I can try this one next.
              # rust.rustcTarget = "avr-unknown-none-attiny85";
              # rust.rustcTargetSpec = "avr-unknown-none-attiny85.json";
              # rust.rustcTarget = "avr-unknown-gnu-atmega328";
              # rust.rustcTargetSpec = "${./avr-unknown-none-attiny85.json}";
              # rust.platform = nixpkgs.lib.importJSON "${./avr-specs/avr-unknown-none-attiny85.json}";
              # rust.cargoShortTarget
              # rust.cargoEnvVarTarget
              rust.isNoStdTarget = true;

              # rust.rustcTargetSpec = nixpkgs.lib.importJSON "${./avr-specs/avr-attiny85.json}";

              # todo And maybe I need to try this too?
              # rustc = {
              #   config = "${./avr-unknown-none-attiny85.json}";
              # };

              # rust.rustcTarget = "avr-unknown-none";

            #   rust.platform = {
            #     arch = "avr";
            #     atomic-cas = false;
            #     cpu = "attiny85";
            #     crt-objects-fallback = false;
            #     data-layout = "e-P1-p:16:8-i8:8-i16:8-i32:8-i64:8-f32:8-f64:8-n8-a:8";
            #     eh-frame-header = false;
            #     exe-suffix = ".elf";
            #     late-link-args = {
            #       gnu-cc = [
            #         "-lgcc"
            #       ];
            #       gnu-lld-cc = [
            #         "-lgcc"
            #       ];
            #     };
            #     linker = "avr-gcc";
            #     linker-flavor = "gnu-cc";
            #     llvm-target = "avr-unknown-unknown";
            #     max-atomic-width = 8;
            #     metadata = {
            #       description = null;
            #       host_tools = null;
            #       std = null;
            #       tier = null;
            #     };
            #     no-default-libraries = false;
            #     pre-link-args = {
            #       gnu-cc = [
            #         "-mmcu=attiny85"
            #         "-Wl,--as-needed,--print-memory-usage"
            #       ];
            #       gnu-lld-cc = [
            #         "-mmcu=attiny85"
            #         "-Wl,--as-needed,--print-memory-usage"
            #       ];
            #     };
            #     relocation-model = "static";
            #     target-c-int-width = 16;
            #     target-pointer-width = 16;
            #     target-family = "avr";
            #     vendor = "unknown";
            #     os = "none";
            #   };
            };
            config.allowUnsupportedSystem = true;
          };
          # todo This should be using avrCrossPkgs for the Rust toolchain, right?
          # rust-bin = rust-overlay.lib.mkRustBin { } avrCrossPkgs.buildPackages;
          # rustToolchain = avrCrossPkgs.pkgsBuildHost.rust-bin.fromRustupToolchainFile ./rust-toolchain.toml;
          # rustToolchain = rust-bin.fromRustupToolchainFile ./rust-toolchain.toml;
          nativeBuildInputs = with pkgs; [
            avrdude
            cargo-binutils
            clippy
            # ravedude
            rustfmt
            rustToolchain
            fish
            just
            nushell
            pkgconf
            pre-commit
            yamllint
          ];
          buildInputs = with pkgs; [];
        in
        {
          packages.default = avrCrossPkgs.callPackage ./default.nix {
            inherit rustToolchain;
            # inherit rust-bin;
          };
          devShells.default = avrCrossPkgs.mkShell {
            inherit nativeBuildInputs buildInputs;
          };
          apps.default = let
            flash = pkgs.writeShellApplication {
              name = "flash-attiny85-pwm-fan-controller";
              runtimeInputs = [pkgs.avrdude];
              text = ''
                avrdude -c USBtiny -B 4 -p attiny85 -U flash:w:${self.packages.default}/bin/attiny85-pwm-fan-controller.hex:i
              '';
            };
          in {
            type = "app";
            program = "${flash}/bin/flash-attiny85-pwm-fan-controller";
          };
        }
      );
}
