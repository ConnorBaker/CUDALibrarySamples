{
  backendStdenv,
  cmake,
  cuda_cudart,
  cuda_nvcc,
  cudaOlder,
  lib,
  libcublas,
}:
let
  inherit (builtins) readDir;
  inherit (lib.attrsets)
    attrNames
    genAttrs
    recurseIntoAttrs
    ;
  inherit (lib.fileset) toSource unions;
  inherit (lib.lists) filter;

  sampleNamesFor =
    groupName:
    let
      files = readDir (./. + "/${groupName}");
      dirs = filter (filename: files.${filename} == "directory") (attrNames files);
    in
    dirs;

  buildSample =
    groupName: sampleName:
    backendStdenv.mkDerivation {
      pname = "cuda-library-samples-cuBLAS-${groupName}-${sampleName}";
      version = "0-unstable-2024-10-15";

      src = toSource {
        root = ./.;
        fileset = unions [
          ./cmake
          ./utils
          (./. + "/${groupName}/${sampleName}")
        ];
      };

      # cmakeDir is relative to cmakeBuildDir, which is by default `build`, so we need to go up one directory.
      cmakeBuildDir = "build";
      cmakeDir = "../${groupName}/${sampleName}";

      nativeBuildInputs = [
        cmake
        cuda_nvcc
      ];

      buildInputs = [
        cuda_cudart
        libcublas
      ];

      meta = {
        description = "examples of using libraries using CUDA";
        longDescription = ''
          CUDA Library Samples contains examples demonstrating the use of
          features in the math and image processing libraries cuBLAS, cuTENSOR,
          cuSPARSE, cuSOLVER, cuFFT, cuRAND, NPP and nvJPEG.
        '';
        mainProgram = "cublas_${sampleName}_example";
        broken =
          (groupName == "Extensions" && sampleName == "GemmGroupedBatchedEx" && cudaOlder "12")
          || (groupName == "Level-3" && sampleName == "gemmGroupedBatched" && cudaOlder "12");
        license = lib.licenses.bsd3;
        maintainers = with lib.maintainers; [ obsidian-systems-maintenance ] ++ lib.teams.cuda.members;
      };
    };

  mkGroup =
    groupName:
    recurseIntoAttrs (
      genAttrs (sampleNamesFor groupName) (sampleName: buildSample groupName sampleName)
    );

  groupNames = [
    "Extensions"
    "Level-1"
    "Level-2"
    "Level-3"
  ];
in
recurseIntoAttrs (genAttrs groupNames mkGroup)
