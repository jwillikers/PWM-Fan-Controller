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
          crossSystem.config = "avr";
          pkgs = import nixpkgs {
            inherit crossSystem system;
            config.allowUnsupportedSystem = true;
            overlays = [
              (import rust-overlay)
              # (self: super: {
              #   pkg = super.pkg.overrideAttrs (old: {
              #     doCheck = false;
              #   });
              # })
            ];
          };
          rustToolchainFor = p: p.rust-bin.selectLatestNightlyWith (toolchain: toolchain.default.override {
            extensions = [ "rust-src" ];
            targets = [ "x86_64-unknown-linux-gnu" ];
          });
          rustToolchain = rustToolchainFor pkgs;

          craneLib = (crane.mkLib pkgs).overrideToolchain (p: p.rust-bin.stable.latest.default);

          # craneLib = (crane.mkLib pkgs).overrideToolchain (p: p.rust-bin.stable.latest.default);
          # craneLib = (crane.mkLib pkgs).overrideToolchain (p: p.rust-bin.stable.latest.default.override {
          #   targets = [ "wasm32-wasi" ];
          # });

          crateExpression =
          {lib
          , cargo-binutils
          , stdenv
          }:
          craneLib.buildPackage {
            src = craneLib.cleanCargoSource ./.;
            strictDeps = true;

            # Build-time tools which are target agnostic. build = host = target = your-machine.
            # Emulators should essentially also go `nativeBuildInputs`. But with some packaging issue,
            # currently it would cause some rebuild.
            # We put them here just for a workaround.
            # See: https://github.com/NixOS/nixpkgs/pull/146583
            depsBuildBuild = [
            ];

            # Dependencies which need to be build for the current platform
            # on which we are doing the cross compilation. In this case,
            # pkg-config needs to run on the build platform so that the build
            # script can find the location of openssl. Note that we don't
            # need to specify the rustToolchain here since it was already
            # overridden above.
            nativeBuildInputs = [
              stdenv.cc
              cargo-binutils
            ];

            # Dependencies which need to be built for the platform on which
            # the binary will run. In this case, we need to compile openssl
            # so that it can be linked with our executable.
            # buildInputs = [
            #   # Add additional build inputs here
            #   openssl
            # ];

            # Tell cargo about the linker and an optional emulater. So they can be used in `cargo build`
            # and `cargo run`.
            # Environment variables are in format `CARGO_TARGET_<UPPERCASE_UNDERSCORE_RUST_TRIPLE>_LINKER`.
            # They are also be set in `.cargo/config.toml` instead.
            # See: https://doc.rust-lang.org/cargo/reference/config.html#target
            # CARGO_TARGET_AARCH64_UNKNOWN_LINUX_GNU_LINKER = "${stdenv.cc.targetPrefix}cc";
            # CARGO_TARGET_AARCH64_UNKNOWN_LINUX_GNU_RUNNER = "qemu-aarch64";

            # Tell cargo which target we want to build (so it doesn't default to the build system).
            # We can either set a cargo flag explicitly with a flag or with an environment variable.
            cargoExtraArgs = "--target avr-unknown-none-attiny85.json";
            # CARGO_BUILD_TARGET = "aarch64-unknown-linux-gnu";

            # These environment variables may be necessary if any of your dependencies use a
            # build-script which invokes the `cc` crate to build some other code. The `cc` crate
            # should automatically pick up on our target-specific linker above, but this may be
            # necessary if the build script needs to compile and run some extra code on the build
            # system.
            HOST_CC = "${stdenv.cc.nativePrefix}cc";
            TARGET_CC = "${stdenv.cc.targetPrefix}cc";
          };

          my-crate = pkgs.callPackage crateExpression { };

          # todo Try creating toolchain from avrCrossPkgs.
          # rustToolchain = pkgs.pkgsBuildHost.rust-bin.fromRustupToolchainFile ./rust-toolchain.toml;

          # avrCrossPkgs = import nixpkgs {
          #   inherit system overlays;
          #   crossSystem = {
          #     inherit overlays;
          #     config = "avr";
          #     # rust.rustcTarget = "${./avr-specs/avr-attiny85.json}";

          #     # todo I can try this one next.
          #     # rust.rustcTarget = "avr-unknown-none-attiny85";
          #     # rust.rustcTargetSpec = "avr-unknown-none-attiny85.json";
          #     # rust.rustcTarget = "avr-unknown-gnu-atmega328";
          #     # rust.rustcTargetSpec = "${./avr-unknown-none-attiny85.json}";
          #     # rust.platform = nixpkgs.lib.importJSON "${./avr-specs/avr-unknown-none-attiny85.json}";
          #     # rust.cargoShortTarget
          #     # rust.cargoEnvVarTarget
          #     rust.isNoStdTarget = true;

          #     # rust.rustcTargetSpec = nixpkgs.lib.importJSON "${./avr-specs/avr-attiny85.json}";

          #     # todo And maybe I need to try this too?
          #     # rustc = {
          #     #   config = "${./avr-unknown-none-attiny85.json}";
          #     # };

          #     # rust.rustcTarget = "avr-unknown-none";

          #   #   rust.platform = {
          #   #     arch = "avr";
          #   #     atomic-cas = false;
          #   #     cpu = "attiny85";
          #   #     crt-objects-fallback = false;
          #   #     data-layout = "e-P1-p:16:8-i8:8-i16:8-i32:8-i64:8-f32:8-f64:8-n8-a:8";
          #   #     eh-frame-header = false;
          #   #     exe-suffix = ".elf";
          #   #     late-link-args = {
          #   #       gnu-cc = [
          #   #         "-lgcc"
          #   #       ];
          #   #       gnu-lld-cc = [
          #   #         "-lgcc"
          #   #       ];
          #   #     };
          #   #     linker = "avr-gcc";
          #   #     linker-flavor = "gnu-cc";
          #   #     llvm-target = "avr-unknown-unknown";
          #   #     max-atomic-width = 8;
          #   #     metadata = {
          #   #       description = null;
          #   #       host_tools = null;
          #   #       std = null;
          #   #       tier = null;
          #   #     };
          #   #     no-default-libraries = false;
          #   #     pre-link-args = {
          #   #       gnu-cc = [
          #   #         "-mmcu=attiny85"
          #   #         "-Wl,--as-needed,--print-memory-usage"
          #   #       ];
          #   #       gnu-lld-cc = [
          #   #         "-mmcu=attiny85"
          #   #         "-Wl,--as-needed,--print-memory-usage"
          #   #       ];
          #   #     };
          #   #     relocation-model = "static";
          #   #     target-c-int-width = 16;
          #   #     target-pointer-width = 16;
          #   #     target-family = "avr";
          #   #     vendor = "unknown";
          #   #     os = "none";
          #   #   };
          #   };
          #   config.allowUnsupportedSystem = true;
          # };
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
          checks = {
            inherit my-crate;
          };

          packages.default = my-crate;

          # packages.default = avrCrossPkgs.callPackage ./default.nix {
          #   inherit rustToolchain;
          #   # inherit rust-bin;
          # };
          devShells.default = craneLib.devShell {
            checks = self.checks.${system};
            inherit nativeBuildInputs buildInputs;
          };
          apps.default = flake-utils.lib.mkApp {
            runtimeInputs = [pkgs.avrdude];
            drv = pkgs.writeScriptBin "flash-attiny85-pwm-fan-controller" ''
              # ${pkgs.pkgsBuildBuild.qemu}/bin/qemu-aarch64 ${my-crate}/bin/cross-rust-overlay
              avrdude -c USBtiny -B 4 -p attiny85 -U flash:w:${self.packages.default}/bin/attiny85-pwm-fan-controller.hex:i
            '';
          };
          # apps.default = let
          #   flash = pkgs.writeShellApplication {
          #     name = "flash-attiny85-pwm-fan-controller";
          #     text = ''
          #       avrdude -c USBtiny -B 4 -p attiny85 -U flash:w:${self.packages.default}/bin/attiny85-pwm-fan-controller.hex:i
          #     '';
          #   };
          # in {
          #   type = "app";
          #   program = "${flash}/bin/flash-attiny85-pwm-fan-controller";
          # };
        }
      );
}
