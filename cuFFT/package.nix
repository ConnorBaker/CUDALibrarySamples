{
  cudaStdenv,
  cmake,
  cuda_cudart,
  cuda_nvcc,
  cudaOlder,
  lib,
  libcufft,
}:
let
  inherit (builtins) readDir;
  inherit (lib.attrsets)
    attrNames
    genAttrs
    recurseIntoAttrs
    ;
  inherit (lib.fileset) toSource unions;
  inherit (lib.lists) elem filter;

  sampleNames =
    let
      files = readDir ./.;
      matchingDirNames = filter (
        filename:
        files.${filename} == "directory"
        && !(elem filename [
          "cmake"
          "utils"
        ])
      ) (attrNames files);
    in
    matchingDirNames;

  buildSample =
    sampleName:
    cudaStdenv.mkDerivation {
      pname = "cuda-library-samples-cuFFT-${sampleName}";
      version = "0-unstable-2024-12-22";

      src = toSource {
        root = ./.;
        fileset = unions [
          ./cmake
          ./utils
          (./. + "/${sampleName}")
        ];
      };

      # cmakeDir is relative to cmakeBuildDir, which is by default `build`, so we need to go up one directory.
      cmakeBuildDir = "build";
      cmakeDir = "../${sampleName}";

      # TODO: get_set doesn't link against cudart, so we need to patch it with autoAddDriverRunpath.
      # TODO: Rewrite the CMakeLists.txt file to link against cudart and document that this is one use case of autoAddDriverRunpath.
      nativeBuildInputs = [
        cmake
        cuda_nvcc
      ];

      buildInputs = [
        cuda_cudart
        libcufft
      ];

      meta = {
        description = "examples of using libraries using CUDA";
        longDescription = ''
          CUDA Library Samples contains examples demonstrating the use of
          features in the math and image processing libraries cuBLAS, cuTENSOR,
          cuSPARSE, cuSOLVER, cuFFT, cuRAND, NPP and nvJPEG.
        '';
        mainProgram = "${sampleName}_example";

        broken =
          # These two fail on CUDA 11.8
          (
            cudaOlder "12"
            && elem sampleName [
              "3d_mgpu_c2c"
              "3d_mgpu_r2c_c2r"
            ]
          )
          # Untested/unimplemented
          || elem sampleName [
            "lto_callback_window_1d"
            "lto_ea"
          ];
        license = lib.licenses.bsd3;
        maintainers = with lib.maintainers; [ obsidian-systems-maintenance ] ++ lib.teams.cuda.members;
      };
    };
in
recurseIntoAttrs (genAttrs sampleNames buildSample)
