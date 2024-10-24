{
  cargoArtifacts,
  commonArgs,
  craneLib,
  # deadnix: skip
  stdenv,
}:
craneLib.buildPackage commonArgs
// {
  inherit cargoArtifacts;

  version = "0.0.1";

  postBuild = ''
    cargo objcopy -- -O ihex pwm-fan-controller-attiny85.hex
  '';

  postInstall = ''
    mv pwm-fan-controller-attiny85.hex $out/bin/
  '';
}
