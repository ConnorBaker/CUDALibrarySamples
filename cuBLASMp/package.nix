{
  autoAddDriverRunpath,
  autoPatchelfHook,
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
  pkg-config,
  runCommand,
}:
let
  inherit (builtins) readDir;
  inherit (lib.attrsets)
    attrNames
    genAttrs
    getDev
    getOutput
    ;
  inherit (lib.lists) concatMap optionals;
  inherit (lib.meta) getExe';
  inherit (lib.strings) cmakeOptionType hasSuffix removeSuffix;

  cmakePath = cmakeOptionType "PATH";
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
    autoAddDriverRunpath
    autoPatchelfHook
    cmake
    cuda_nvcc
    pkg-config
  ];

  # TODO: The exec path doesn't need to exist, it just uses it to find headers.
  # At least this forces mpi to come from pkgs rather than buildPackages.
  cmakeFlags = [
    (cmakePath "MPIEXEC_EXECUTABLE" "${getExe' (getDev mpi) "does-not-exist"}")
  ];

  buildInputs = [
    (getOutput "include" libcublas)
    cuda_cudart
    libcal
    libcublasmp
    mpi
  ];

  passthru.tests = genAttrs sampleNames (
    sampleName:
    runCommand "cuBLASMp-${sampleName}"
      {
        __structuredAttrs = true;
        strictDeps = true;
        nativeBuildInputs = [
          cuBLASMp
          mpi
          libcal.out # With setup hook, equivalent to env.UCC_CONFIG_FILE = "${libcal.out}/share/ucc.conf";
        ];
        requiredSystemFeatures = [ "cuda" ];
      }
      (
        # Make a temporary directory for the tests and error out if anything fails.
        # TODO: Requires access to network and sys.
        ''
          set -euo pipefail
          export HOME="$(mktemp --directory)"
          trap 'rm -rf -- "''${HOME@Q}"' EXIT
        ''
        # Run the tests.
        + ''
          echo "Running cuBLASMp.${sampleName}..."
          if "${getExe' mpi "mpirun"}" -n 2 "${getExe' cuBLASMp sampleName}"
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
