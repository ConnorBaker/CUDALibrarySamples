{
  backendStdenv,
  cmake,
  cuda_cudart,
  cuda_nvcc,
  cudaOlder,
  lib,
  libcal ? null,
  libcublas,
  libcublasmp ? null,
  mpi,
  pkg-config,
}:
let
  inherit (builtins) readDir;
  inherit (lib.attrsets)
    attrNames
    genAttrs
    getOutput
    recurseIntoAttrs
    ;
  inherit (lib.lists) concatMap optionals;
  inherit (lib.strings) hasSuffix removeSuffix;
  inherit (lib.fileset) toSource unions;

  sampleNames =
    let
      files = readDir ./.;
      matchingDirNames = concatMap (
        filename:
        optionals (hasSuffix ".cu" filename && files.${filename} == "regular") [
          (removeSuffix ".cu" filename)
        ]
      ) (attrNames files);
    in
    matchingDirNames;

  buildSample =
    sampleName:
    backendStdenv.mkDerivation {
      pname = "cuda-library-samples-cuBLASMp-${sampleName}";
      version = "0-unstable-2024-10-15";

      src = toSource {
        root = ./.;
        fileset = unions [
          ./CMakeLists.txt
          ./helpers.h
          ./matrix_generator.hxx
          (./. + "/${sampleName}.cu")
        ];
      };

      # To ensure we only build one sample at a time, remove lines from CMakeLists.txt which include build_sample
      # and append a single line for our sample at the end.
      postPatch = ''
        sed -i ./CMakeLists.txt -e 's/^build_sample(".*")$//g'
        echo 'build_sample("${sampleName}")' >> ./CMakeLists.txt
      '';

      nativeBuildInputs = [
        cmake
        cuda_nvcc
        pkg-config
      ];

      buildInputs = [
        (getOutput "include" libcublas)
        cuda_cudart
        libcal
        libcublasmp
        mpi
      ];

      propagatedBuildInputs = [
        libcal.out # With setup hook, equivalent to env.UCC_CONFIG_FILE = "${libcal.out}/share/ucc.conf";
      ];

      meta = {
        description = "examples of using libraries using CUDA";
        longDescription = ''
          CUDA Library Samples contains examples demonstrating the use of
          features in the math and image processing libraries cuBLAS, cuTENSOR,
          cuSPARSE, cuSOLVER, cuFFT, cuRAND, NPP and nvJPEG.
        '';
        mainProgram = "sample_cublasLt_${sampleName}";
        broken = cudaOlder "12" || libcal == null || libcublasmp == null;
        license = lib.licenses.bsd3;
        maintainers = with lib.maintainers; [ obsidian-systems-maintenance ] ++ lib.teams.cuda.members;
      };
    };
in
recurseIntoAttrs (genAttrs sampleNames buildSample)
