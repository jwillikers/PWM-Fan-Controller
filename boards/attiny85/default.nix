{
craneLib
, cargoArtifacts
, commonArgs
, pkgs
, lib
, stdenv
}:
craneLib.buildPackage (commonArgs // {
  inherit cargoArtifacts;

  postBuild = ''
    cargo objcopy -- -O ihex pwm-fan-controller-attiny85.hex
  '';

  postInstall = ''
    mv pwm-fan-controller-attiny85.hex $out/bin/
  '';
})
