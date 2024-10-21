{
  backendStdenv,
  cmake,
  cuBLASMp,
  cuda_cudart,
  cuda_nvcc,
  cudaMajorMinorVersion,
  lib,
  libcal ? null,
  libcublas,
  libcublasmp,
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
    getOutput
    ;
  inherit (lib.lists) concatMap optionals;
  inherit (lib.meta) getExe';
  inherit (lib.strings) hasSuffix removeSuffix;

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
in
backendStdenv.mkDerivation (finalAttrs: {
  __structuredAttrs = true;
  strictDeps = true;

  name = "cuda${cudaMajorMinorVersion}-${finalAttrs.pname}-${finalAttrs.version}";
  pname = "cuda-library-samples-cuBLASMp";
  version = "0-unstable-2024-10-15";

  src = ./.;

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

  passthru.tests = genAttrs sampleNames (
    sampleName:
    runCommand "cuBLASMp-${sampleName}"
      {
        # Requires access to network and sys.
        __structuredAttrs = true;
        strictDeps = true;
        nativeBuildInputs = [
          cuBLASMp
          mpi
          nccl
        ];
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
          echo "Running cuBLASMp.${sampleName}..."
          if "${getExe' mpi "mpirun"}" -n 2 "${getExe' cuBLASMp sampleName}" -m 100 -n 100 -k 100 -verbose 1
          then
            echo "cuBLASMp.${sampleName} passed"
            touch "$out"
          else
            echo "cuBLASMp.${sampleName} failed"
            exit 1
          fi
        ''
      )
  );

  meta = {
    description = "examples of using libraries using CUDA";
    longDescription = ''
      CUDA Library Samples contains examples demonstrating the use of
      features in the math and image processing libraries cuBLAS, cuTENSOR,
      cuSPARSE, cuSOLVER, cuFFT, cuRAND, NPP and nvJPEG.
    '';
    broken = libcal == null;
    license = lib.licenses.bsd3;
    maintainers = with lib.maintainers; [ obsidian-systems-maintenance ] ++ lib.teams.cuda.members;
  };
})
