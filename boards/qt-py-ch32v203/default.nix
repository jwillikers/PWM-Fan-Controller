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
}
