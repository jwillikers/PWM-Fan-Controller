{
craneLib
, pkgs
, lib
, stdenv
}:
craneLib.buildPackage {
  pname = "pwm-fan-controller-qt-py-ch32v203";
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
  CARGO_TARGET_RISCV32IMAC_UNKNOWN_NONE_ELF_RUSTFLAGS = "-C link-arg=--library-path=.";
  extraDummyScript = ''
    cp --archive ${./memory.x} $out/memory.x
    rm --force --recursive $out/src/bin/crane-dummy-*
  '';

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
  cargoExtraArgs = "--target riscv32imac-unknown-none-elf";
  # CARGO_BUILD_TARGET = "riscv32imac-unknown-none-elf";

  # These environment variables may be necessary if any of your dependencies use a
  # build-script which invokes the `cc` crate to build some other code. The `cc` crate
  # should automatically pick up on our target-specific linker above, but this may be
  # necessary if the build script needs to compile and run some extra code on the build
  # system.
  # HOST_CC = "${stdenv.cc.nativePrefix}cc";
  # TARGET_CC = "${stdenv.cc.targetPrefix}cc";
}
