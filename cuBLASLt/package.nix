{
  cudaStdenv,
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
  inherit (lib.lists) filter optionals;
  inherit (lib.strings) hasPrefix;

  sampleNames =
    let
      files = readDir ./.;
      matchingDirNames = filter (filename: hasPrefix "Lt" filename && files.${filename} == "directory") (
        attrNames files
      );
    in
    matchingDirNames;

  buildSample =
    sampleName:
    cudaStdenv.mkDerivation {
      pname = "cuda-library-samples-cuBLASLt-${sampleName}";
      version = "0-unstable-2024-12-22";

      src = toSource {
        root = ./.;
        fileset = unions [
          ./cmake
          ./Common
          (./. + "/${sampleName}")
        ];
      };

      # cmakeDir is relative to cmakeBuildDir, which is by default `build`, so we need to go up one directory.
      cmakeBuildDir = "build";
      cmakeDir = "../${sampleName}";

      # /build/cuBLASLt/LtIgemmTensor/main.cpp:38:45: error: narrowing conversion of '0.0f' from 'float' to 'int'
      #     38 |     TestBench<int8_t, int32_t> props(4, 4, 4);
      # NOTE: Error happens regardless of CUDA 11/12.
      env.NIX_CFLAGS_COMPILE = toString (optionals (sampleName == "LtIgemmTensor") [ "-Wno-narrowing" ]);

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
        mainProgram = "sample_cublasLt_${sampleName}";
        broken = sampleName == "LtFp8Matmul" && cudaOlder "12";
        license = lib.licenses.bsd3;
        maintainers = with lib.maintainers; [ obsidian-systems-maintenance ] ++ lib.teams.cuda.members;
      };
    };
in
recurseIntoAttrs (genAttrs sampleNames buildSample)
