{
  backendStdenv,
  cmake,
  NPP,
  cuda_cudart,
  cuda_nvcc,
  lib,
  libnpp,
  runCommand,
}:
let
  inherit (builtins) readDir;
  inherit (lib.attrsets)
    attrNames
    genAttrs
    recurseIntoAttrs
    ;
  inherit (lib.lists) filter;
  inherit (lib.meta) getExe;
  inherit (lib.strings) optionalString;

  sampleNames =
    let
      files = readDir ./.;
      matchingDirNames = filter (filename: files.${filename} == "directory") (
        attrNames files
      );
    in
    matchingDirNames;

  buildSample =
    sampleName:
    backendStdenv.mkDerivation {
      pname = "cuda-library-samples-NPP-${sampleName}";
      version = "0-unstable-2024-10-15";

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

      passthru.tests.test =
        runCommand "NPP-${sampleName}"
          {
            __structuredAttrs = true;
            strictDeps = true;
            nativeBuildInputs = [ NPP.${sampleName} ];
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
              echo "Running NPP.${sampleName}..."
              if "${getExe NPP.${sampleName}}"
              then
                echo "NPP.${sampleName} passed"
                touch "$out"
              else
                echo "NPP.${sampleName} failed"
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
        mainProgram = sampleName;
        license = lib.licenses.bsd3;
        maintainers = with lib.maintainers; [ obsidian-systems-maintenance ] ++ lib.teams.cuda.members;
      };
    };
in
recurseIntoAttrs (genAttrs sampleNames buildSample)
