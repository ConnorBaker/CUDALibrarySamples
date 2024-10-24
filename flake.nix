{
  inputs = {
    cuda-packages = {
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-parts.follows = "flake-parts";
        git-hooks-nix.follows = "git-hooks-nix";
        treefmt-nix.follows = "treefmt-nix";
      };
      url = "github:ConnorBaker/cuda-packages";
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
      inherit (builtins) readDir;
      inherit (inputs.nixpkgs.lib.attrsets)
        attrNames
        getAttr
        mapAttrs
        optionalAttrs
        recurseIntoAttrs
        ;
      inherit (inputs.nixpkgs.lib.customisation) makeScope;
      inherit (inputs.nixpkgs.lib.lists) concatMap optionals;
      inherit (inputs.nixpkgs.lib.filesystem) packagesFromDirectoryRecursive;
      inherit (inputs.nixpkgs.lib.fileset) unions toSource;
      inherit (inputs.flake-parts.lib) mkFlake;
      inherit (inputs.cuda-packages) mkOverlay;
      inherit (inputs.cuda-packages.cuda-lib.utils) flattenDrvTree;

      overlay =
        let
          files = readDir ./.;
          dirs = concatMap (
            filename: optionals (getAttr filename files == "directory") [ (./. + "/${filename}") ]
          ) (attrNames files);
          src = toSource {
            root = ./.;
            fileset = unions dirs;
          };
          overrideScopeFn = cudaFinal: _: {
            cuda-library-samples = recurseIntoAttrs (
              makeScope cudaFinal.newScope (
                cudaLibrarySamplesFinal:
                packagesFromDirectoryRecursive {
                  inherit (cudaLibrarySamplesFinal) callPackage;
                  directory = src;
                }
              )
            );
          };
        in
        _: prev: {
          cudaPackages_11 = prev.cudaPackages_11.overrideScope overrideScopeFn;
          cudaPackages_12 = prev.cudaPackages_12.overrideScope overrideScopeFn;
        };
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

      flake.overlays.default = overlay;

      perSystem =
        { config, system, ... }:
        let
          configs =
            {
              ada = "8.9";
            }
            // optionalAttrs (system == "aarch64-linux") {
              orin = "8.7";
              xavier = "7.2";
            };

          ourPkgs = mapAttrs (
            _: capability:
            import inputs.nixpkgs {
              inherit system;
              config = {
                allowUnfree = true;
                cudaSupport = true;
                cudaCapabilities = [ capability ];
              };
              overlays = [
                (mkOverlay { capabilities = [ capability ]; })
                overlay
              ];
            }
          ) configs;

          ourCudaLibrarySamples = mapAttrs (name: _: {
            cuda11 = ourPkgs.${name}.cudaPackages_11.cuda-library-samples;
            cuda12 = ourPkgs.${name}.cudaPackages_12.cuda-library-samples;
          }) configs;
        in
        {
          _module.args.pkgs = ourPkgs.ada;

          checks = flattenDrvTree {
            attrs = recurseIntoAttrs (mapAttrs (_: recurseIntoAttrs) ourCudaLibrarySamples);
          };

          legacyPackages = ourPkgs;

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
