{
  inputs = {
    cuda-packages.url = "github:ConnorBaker/cuda-packages";
    flake-parts.follows = "cuda-packages/flake-parts";
    nixpkgs.follows = "cuda-packages/nixpkgs";
    git-hooks-nix.follows = "cuda-packages/git-hooks-nix";
    treefmt-nix.follows = "cuda-packages/treefmt-nix";
  };

  outputs =
    inputs:
    let
      inherit (inputs.nixpkgs.lib.attrsets) genAttrs recurseIntoAttrs;
      inherit (inputs.nixpkgs.lib.lists) optionals;
      inherit (inputs.flake-parts.lib) mkFlake;
      inherit (inputs.cuda-packages.cuda-lib.utils) flattenDrvTree;
    in
    mkFlake { inherit inputs; } {
      systems = [
        "aarch64-linux"
        "x86_64-linux"
      ];

      imports = [
        inputs.git-hooks-nix.flakeModule
        inputs.treefmt-nix.flakeModule
      ];

      flake.overlays.default = import ./overlay.nix;

      perSystem =
        {
          config,
          pkgs,
          system,
          ...
        }:
        {
          _module.args.pkgs = import inputs.nixpkgs {
            inherit system;
            # TODO: Due to the way Nixpkgs is built in stages, the config attribute set is not re-evaluated.
            # This is problematic for us because we use it to signal the CUDA capabilities to the overlay.
            # The only way I've found to combat this is to use pkgs.extend, which is not ideal.
            # TODO: This also means that Nixpkgs needs to be imported *with* the correct config attribute set
            # from the start, unless they're willing to re-import Nixpkgs with the correct config.
            config = {
              allowUnfree = true;
              cudaSupport = true;
            };
            overlays = [
              inputs.cuda-packages.overlays.default
              inputs.self.overlays.default
            ];
          };

          legacyPackages = pkgs;

          checks =
            let
              collectSamples =
                pkgsCuda: realArch:
                recurseIntoAttrs {
                  cudaPackages = recurseIntoAttrs {
                    tests = recurseIntoAttrs {
                      inherit (pkgsCuda.${realArch}.cudaPackages.tests) cuda-library-samples;
                    };
                  };
                };
              tree = recurseIntoAttrs {
                pkgsCuda = recurseIntoAttrs (
                  genAttrs (
                    [
                      "sm_89"
                    ]
                    ++ optionals (pkgs.stdenv.hostPlatform.system == "aarch64-linux") [
                      "sm_87"
                    ]
                  ) (collectSamples pkgs.pkgsCuda)
                );
              };
            in
            flattenDrvTree tree;

          pre-commit.settings.hooks = {
            # Formatter checks
            treefmt = {
              enable = true;
              package = config.treefmt.build.wrapper;
            };

            # Nix checks
            deadnix.enable = true;
            nil.enable = true;
            statix.enable = true;
          };

          treefmt = {
            projectRootFile = "flake.nix";
            programs.nixfmt.enable = true;
          };
        };
    };
}
