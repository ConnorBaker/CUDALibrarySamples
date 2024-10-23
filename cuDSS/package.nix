{
  backendStdenv,
  cmake,
  cuDSS,
  cudaOlder,
  cuda_cudart,
  cuda_nvcc,
  lib,
  libcudss ? null,
  mpi,
  nccl,
  pkg-config,
  runCommand,
}:
let
  inherit (builtins) readDir;
  inherit (lib.attrsets)
    attrNames
    genAttrs
    recurseIntoAttrs
    ;
  inherit (lib.fileset) toSource unions;
  inherit (lib.lists) filter optionals;
  inherit (lib.meta) getExe;

  sampleNames =
    let
      files = readDir ./.;
      matchingDirNames = filter (filename: files.${filename} == "directory" && filename != "cmake") (
        attrNames files
      );
    in
    matchingDirNames;

  buildSample =
    sampleName:
    backendStdenv.mkDerivation {
      pname = "cuda-library-samples-cuDSS-${sampleName}";
      version = "0-unstable-2024-10-15";

      src = toSource {
        root = ./.;
        fileset = unions [
          ./cmake
          (./. + "/${sampleName}")
        ];
      };

      # cmakeDir is relative to cmakeBuildDir, which is by default `build`, so we need to go up one directory.
      cmakeBuildDir = "build";
      cmakeDir = "../${sampleName}";

      # TODO: get_set doesn't link against cudart, so we need to patch it with autoAddDriverRunpath.
      # TODO: Rewrite the CMakeLists.txt file to link against cudart and document that this is one use case of autoAddDriverRunpath.
      nativeBuildInputs =
        [
          cmake
          cuda_nvcc
        ]
        ++ optionals (sampleName == "simple_mgmn_mode") [
          pkg-config
        ];

      buildInputs =
        [
          cuda_cudart
          libcudss
        ]
        ++ optionals (sampleName == "simple_mgmn_mode") [
          mpi
          nccl
        ];

      passthru.tests.test =
        runCommand "cuDSS-${sampleName}"
          {
            __structuredAttrs = true;
            strictDeps = true;
            nativeBuildInputs = [ cuDSS.${sampleName} ];
            requiredSystemFeatures = [ "cuda" ];
          }
          (
            # Make a temporary directory for the tests and error out if anything fails.
            ''
              set -euo pipefail
              export HOME="$(mktemp --directory)"
              trap 'rm -rf -- "''${HOME@Q}"' EXIT
            ''
            # Run the tests.
            + ''
              echo "Running cuDSS.${sampleName}..."
              if "${getExe cuDSS.${sampleName}}"
              then
                echo "cuDSS.${sampleName} passed"
                touch "$out"
              else
                echo "cuDSS.${sampleName} failed"
                exit 1
              fi
            ''
          );

      meta = {
        description = "examples of using libraries using CUDA";
        longDescription = ''
          CUDA Library Samples contains examples demonstrating the use of
          features in the math and image processing libraries cuBLAS, cuTENSOR,
          cuSPARSE, cuSOLVER, cuFFT, cuRAND, NPP and nvJPEG.
        '';
        mainProgram = "${sampleName}_example";

        broken =
          # libcudss is required and only available from CUDA 12.0
          cudaOlder "12"
          # Requires switching to use the MPI compiler, which I don't want to deal with.
          || sampleName == "simple_mgmn_mode";
        license = lib.licenses.bsd3;
        maintainers = with lib.maintainers; [ obsidian-systems-maintenance ] ++ lib.teams.cuda.members;
      };
    };
in
recurseIntoAttrs (genAttrs sampleNames buildSample)
