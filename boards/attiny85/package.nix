{
  cargoArtifacts,
  commonArgs,
  craneLib,
  # deadnix: skip
  stdenv,
}:
craneLib.buildPackage (
  commonArgs
  // {
    inherit cargoArtifacts;
    version = "0.0.1";

    postInstall = ''
      avr-objcopy -O ihex $out/bin/pwm-fan-controller-attiny85.elf $out/bin/pwm-fan-controller-attiny85.hex
    '';
  }
)
