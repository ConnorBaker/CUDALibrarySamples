{
  cudaStdenv,
  cmake,
  cuda_cudart,
  cuda_nvcc,
  lib,
  libnpp,
}:
let
  inherit (builtins) readDir;
  inherit (lib.attrsets)
    attrNames
    genAttrs
    recurseIntoAttrs
    ;
  inherit (lib.lists) filter;
  inherit (lib.strings) optionalString;

  sampleNames =
    let
      files = readDir ./.;
      matchingDirNames = filter (filename: files.${filename} == "directory") (attrNames files);
    in
    matchingDirNames;

  buildSample =
    sampleName:
    cudaStdenv.mkDerivation {
      pname = "cuda-library-samples-NPP-${sampleName}";
      version = "0-unstable-2024-12-22";

      src = ./. + "/${sampleName}";

      nativeBuildInputs = [
        cmake
        cuda_nvcc
      ];

      postPatch = optionalString (sampleName == "batchedLabelMarkersAndCompression") ''
        substituteInPlace ./batchedLabelMarkersAndCompression.cpp \
          --replace-fail \
            'const std::string & InputPath = std::string("../images/");' \
            'const std::string & InputPath = std::string("${builtins.placeholder "out"}/share/images/");'
      '';

      buildInputs = [
        cuda_cudart
        libnpp
      ];

      meta = {
        description = "examples of using libraries using CUDA";
        longDescription = ''
          CUDA Library Samples contains examples demonstrating the use of
          features in the math and image processing libraries cuBLAS, cuTENSOR,
          cuSPARSE, cuSOLVER, cuFFT, cuRAND, NPP and nvJPEG.
        '';
        mainProgram = sampleName;
        license = lib.licenses.bsd3;
        broken = sampleName != "batchedLabelMarkersAndCompression";
        maintainers = with lib.maintainers; [ obsidian-systems-maintenance ] ++ lib.teams.cuda.members;
      };
    };
in
recurseIntoAttrs (genAttrs sampleNames buildSample)
