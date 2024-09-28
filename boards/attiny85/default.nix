# https://github.com/NixOS/nixpkgs/blob/master/pkgs/build-support/rust/build-rust-package/sysroot/default.nix
{ stdenv
, cargo-binutils
, pkgs
, rustToolchain
# , rust-bin
}:

let
  # rustToolchain = pkgs.pkgsBuildHost.rust-bin.fromRustupToolchainFile ./rust-toolchain.toml;
  rustPlatform = pkgs.makeRustPlatform {
    rustc = rustToolchain;
    cargo = rustToolchain;
    # rustc = rust-bin.stable.latest.minimal;
    # cargo = rust-bin.stable.latest.minimal;
  };
in
rustPlatform.buildRustPackage {
  pname = "pwm-fan-controller-attiny85";
  version = "0.0.1";
  src = ./.;
  cargoLock = {
    allowBuiltinFetchGit = true;
    lockFile = ./Cargo.lock;
  };
  __internal_dontAddSysroot = true;
  # useSysroot = false;
  # env.CARGO_BUILD_TARGET = "${./avr-specs/avr-attiny85.json}";
  # CARGO_BUILD_TARGET = "${./avr-specs/avr-attiny85.json}";
  doCheck = false;
  RUSTC_BOOTSTRAP = 1;
  cargoExtraArgs = "-Z build-std=core";
  # cargoExtraArgs = "--target avr-specs/avr-attiny85.json";
  # postPatch = ''
  #   ln -s ${./Cargo.lock} Cargo.lock
  # '';
  # buildPhase = ''
  #   cargoBuildHook
  # '';
  # ${rust.envVars.setEnv} cargo cbuild -j $NIX_BUILD_CORES --release --frozen --prefix=${placeholder "out"} --target avr-specs/avr-attiny85.json
  buildPhase = ''
    runHook preBuild
    cargo build -j $NIX_BUILD_CORES --release --frozen --target ${./avr-unknown-none-attiny85.json} -Z build-std=core
    cargo objcopy -- -O ihex pwm-fan-controller-attiny85.hex
    runHook postBuild
  '';
  postBuild = ''
    cargo objcopy -- -O ihex pwm-fan-controller-attiny85.hex
  '';
  installPhase = ''
    mkdir --parents $out/bin
    mv pwm-fan-controller-attiny85.hex $out/bin/
  '';
  buildInputs = [
  ];
  nativeBuildInputs = [
    # pkgs.buildPackages.stdenv.cc
    cargo-binutils
    # rust-bin.stable.latest.minimal
    rustToolchain
  ];
  # auditable = false;
}
