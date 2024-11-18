{ pkgs, treefmtEval, ... }:
{
  src = ./.;
  hooks = {
    check-added-large-files.enable = true;
    check-builtin-literals.enable = true;
    check-case-conflicts.enable = true;
    check-executables-have-shebangs.enable = true;

    # todo Not integrated with Nix?
    check-format = {
      enable = true;
      entry = "${treefmtEval.config.build.wrapper}/bin/treefmt-nix --fail-on-change";
    };

    check-json.enable = true;
    check-shebang-scripts-are-executable.enable = true;
    check-toml.enable = true;
    check-yaml.enable = true;
    # todo Is it possible to support clippy as a pre-commit hook for a workspace project like this?
    # clippy.enable = true;
    deadnix.enable = true;
    detect-private-keys.enable = true;
    editorconfig-checker.enable = true;
    end-of-file-fixer.enable = true;
    fix-byte-order-marker.enable = true;
    # flake-checker.enable = true;
    forbid-new-submodules.enable = true;
    # todo Enable lychee when asciidoc is supported.
    # See https://github.com/lycheeverse/lychee/issues/291
    # lychee.enable = true;
    mixed-line-endings.enable = true;
    nil.enable = true;

    strip-location-metadata = {
      name = "Strip location metadata";
      description = "Strip geolocation metadata from image files";
      enable = true;
      entry = "${pkgs.exiftool}/bin/exiftool -duplicates -overwrite_original '-gps*='";
      package = pkgs.exiftool;
      types = [ "image" ];
    };
    trim-trailing-whitespace.enable = true;
    yamllint.enable = true;
  };
}
