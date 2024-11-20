{
  inputs = {
    cuda-packages = {
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-parts.follows = "flake-parts";
        git-hooks-nix.follows = "git-hooks-nix";
        treefmt-nix.follows = "treefmt-nix";
      };
      url = "path:///home/connorbaker/cuda-packages";
    };
    flake-parts = {
      inputs.nixpkgs-lib.follows = "nixpkgs";
      url = "github:hercules-ci/flake-parts";
    };
    nixpkgs.url = "github:nixos/nixpkgs";
    git-hooks-nix = {
      inputs = {
        nixpkgs-stable.follows = "nixpkgs";
        nixpkgs.follows = "nixpkgs";
      };
      url = "github:cachix/git-hooks.nix";
    };
    treefmt-nix = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:numtide/treefmt-nix";
    };
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
                recurseIntoAttrs (
                  genAttrs
                    [
                      "cudaPackages_11"
                      "cudaPackages_12"
                    ]
                    (
                      cudaPackagesName:
                      let
                        cudaPackages = pkgsCuda.${realArch}.${cudaPackagesName};
                      in
                      recurseIntoAttrs {
                        tests = recurseIntoAttrs {
                          inherit (cudaPackages.tests) cuda-library-samples;
                        };
                      }
                    )
                );
              tree = recurseIntoAttrs {
                pkgsCuda = recurseIntoAttrs (
                  genAttrs (
                    [
                      "sm_89"
                    ]
                    ++ optionals (pkgs.stdenv.hostPlatform.system == "aarch64-linux") [
                      "sm_72"
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
