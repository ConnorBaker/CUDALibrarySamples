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
      inherit (inputs.nixpkgs.lib) optionalAttrs;
      inherit (inputs.nixpkgs.lib.attrsets)
        attrNames
        cartesianProduct
        filterAttrs
        getAttr
        mergeAttrsList
        recurseIntoAttrs
        ;
      inherit (inputs.nixpkgs.lib.customisation) makeScope;
      inherit (inputs.nixpkgs.lib.lists) concatMap map optionals;
      inherit (inputs.nixpkgs.lib.filesystem) packagesFromDirectoryRecursive;
      inherit (inputs.nixpkgs.lib.fileset) unions toSource;
      inherit (inputs.nixpkgs.lib.strings) hasSuffix;
      inherit (inputs.flake-parts.lib) mkFlake;
      inherit (inputs.cuda-packages) mkOverlay;
      inherit (inputs.cuda-packages.cuda-lib.utils) flattenDrvTree;

      overlay =
        _: prev:
        let
          overrideScopeFn = cudaFinal: _: {
            cuda-library-samples = makeScope cudaFinal.newScope (
              cudaLibrarySamplesFinal:
              packagesFromDirectoryRecursive {
                inherit (cudaLibrarySamplesFinal) callPackage;
                directory =
                  let
                    files = builtins.readDir ./.;
                    dirs = concatMap (
                      filename: optionals (getAttr filename files == "directory") [ (./. + "/${filename}") ]
                    ) (attrNames files);
                    src = toSource {
                      root = ./.;
                      fileset = unions dirs;
                    };
                  in
                  src;
              }
            );
          };
        in
        {
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
        inputs.treefmt-nix.flakeModule
        inputs.git-hooks-nix.flakeModule
      ];

      flake.overlays.default = overlay;

      perSystem =
        { config, system, ... }:
        let
          # TODO: Are config attributes not re-evaluated when the overlay changes? Or is it just the Nix flake's CLI
          # which warns when an overlay enables allowUnfree and the first pkgs instantiation doesn't?
          # Unfree needs to be set in the initial config attribute set, even though we override it in our overlay.
          configurations = cartesianProduct {
            device = [
              {
                name = "ada";
                capabilities = [ "8.9" ];
              }
              {
                name = "orin";
                capabilities = [ "8.7" ];
              }
              {
                name = "xavier";
                capabilities = [ "7.2" ];
              }
            ];
            cudaMajorVersion = [
              "11"
              "12"
            ];
            test = [
              true
              false
            ];
          };

          mkExposedTree =
            {
              device,
              cudaMajorVersion,
              test,
            }:
            let
              pkgs = import inputs.nixpkgs {
                inherit system;
                config = {
                  allowUnfree = true;
                  cudaSupport = true;
                  cudaCapabilities = device.capabilities;
                };
                overlays = [
                  (mkOverlay { inherit (device) capabilities; })
                  overlay
                ];
              };

              inherit (pkgs) linkFarm;

              attrName = "${device.name}Cuda${cudaMajorVersion}LibrarySamples${if test then "Tests" else ""}Drvs";
            in
            optionalAttrs (device.name != "ada" -> system == "aarch64-linux") {
              "${device.name}Pkgs" = pkgs;
              "${attrName}" = linkFarm attrName (flattenDrvTree {
                attrs = pkgs."cudaPackages_${cudaMajorVersion}".cuda-library-samples;
                doTrace = false;
                includeFunc =
                  if test then
                    name: drv:
                    drv.passthru.test or (
                      if drv ? passthru.tests then
                        linkFarm "${name}-tests" (flattenDrvTree {
                          attrs = recurseIntoAttrs drv.passthru.tests;
                        })
                      else
                        drv
                    )
                  else
                    _: drv: drv;
              });
            };

          all = mergeAttrsList (map mkExposedTree configurations);
        in
        {
          # Make upstream's cudaPackages the default.
          _module.args.pkgs = all.adaPkgs;

          legacyPackages = all;

          packages = filterAttrs (name: _: !(hasSuffix "Pkgs" name)) config.legacyPackages;

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
