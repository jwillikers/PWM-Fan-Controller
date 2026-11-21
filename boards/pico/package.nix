{
  cargoArtifacts,
  commonArgs,
  craneLib,
  elf2uf2-rs,
  # deadnix: skip
  stdenv,
}:
craneLib.buildPackage (
  commonArgs
  // {
    inherit cargoArtifacts;
    version = "0.0.1";

    nativeBuildInputs = commonArgs.nativeBuildInputs ++ [ elf2uf2-rs ];

    postInstall = ''
      elf2uf2-rs $out/bin/pwm-fan-controller-pico $out/bin/pwm-fan-controller-pico.uf2
    '';
  }
)
