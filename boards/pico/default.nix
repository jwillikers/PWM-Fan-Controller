{
craneLib
, pkgs
, lib
, stdenv
}:
craneLib.buildPackage {
  pname = "pwm-fan-controller-pico";
  version = "0.0.1";

  src = lib.cleanSourceWith {
    src = ./.;
    # Don't remove the memory.x linker script file from the sources.
    filter = path: type: (craneLib.filterCargoSources path type) || (builtins.baseNameOf path == "memory.x");
  };

  strictDeps = true;
  doCheck = false;

  # Need to make the memory.x linker script available to the dummy crate.
  # See https://github.com/ipetkov/crane/issues/444
  # Should I symlink instead of copy?
  # ln --symbolic ${./memory.x} memory.x
  CARGO_TARGET_THUMBV6M_NONE_EABI_RUSTFLAGS = "-C link-arg=--library-path=.";
  extraDummyScript = ''
    cp --archive ${./memory.x} $out/memory.x
    rm --force --recursive $out/src/bin/crane-dummy-*
  '';

  nativeBuildInputs = [
    stdenv.cc
    pkgs.flip-link
  ];

  cargoExtraArgs = "--target thumbv6m-none-eabi";
}
