final:
let
  inherit (final) writeShellApplication;
  inherit (final.lib.attrsets)
    attrValues
    isAttrs
    mapAttrs
    recurseIntoAttrs
    ;
  inherit (final.lib.customisation) makeScope;
  inherit (final.lib.fileset) toSource unions;
  inherit (final.lib.filesystem) packagesFromDirectoryRecursive;
  inherit (final.lib.lists) optionals;
  inherit (final.lib.meta) getExe getExe';
  inherit (final.lib.strings) concatMapStringsSep;

  cudaExtension =
    finalCudaPackages: prevCudaPackages:
    let
      inherit (finalCudaPackages.cuda-lib.utils) flattenDrvTree;

      mkTestSuite =
        sampleSuiteName: attrs:
        let
          drvs = attrValues (flattenDrvTree attrs);

          mkTestRunner =
            drv:
            let
              runCommand =
                if sampleSuiteName == "cuBLASMp" then
                  ''"${getExe' final.mpi "mpirun"}" -n 2 "${getExe drv}" -m 100 -n 100 -k 100 -verbose 1''
                else
                  getExe drv;
            in
            if drv.meta.broken then
              ''
                echo "Skipping ${drv.name} because it is marked broken"
                skippedTests+=( "${drv.name}" )
              ''
            else if !drv.meta.available then
              ''
                echo "Skipping ${drv.name} because it is not available"
                skippedTests+=( "${drv.name}" )
              ''
            else
              ''
                echo "Running ${drv.name}"
                if "${runCommand}"
                then
                  echo "${drv.name} passed"
                  passedTests+=( "${drv.name}" )
                else
                  echo "${drv.name} failed"
                  failedTests+=( "${drv.name}" )
                fi
              '';
        in
        writeShellApplication {
          # We do not set nounset to avoid errors caused by arrays being empty.
          bashOptions = [
            "errexit"
            "pipefail"
          ];
          derivationArgs = {
            strictDeps = true;
            __structuredAttrs = true;
          };
          name = "cuda${finalCudaPackages.cudaMajorMinorVersion}-tests-cuda-library-samples-${sampleSuiteName}";
          runtimeInputs =
            drvs
            ++ optionals (sampleSuiteName == "cuBLASMp") [
              final.mpi
              finalCudaPackages.nccl
            ];
          text =
            # Setup
            ''
              # shellcheck disable=SC2155
              export HOME="$(mktemp --directory)"
              trap 'rm -rf -- "''${HOME@Q}"' EXIT
              declare -a passedTests
              declare -a failedTests
              declare -a skippedTests
            ''
            # Tests
            # NOTE: Leading and trailing whitespace to ensure clean concatenation
            + "\n"
            + concatMapStringsSep "\n" mkTestRunner drvs
            + "\n"
            # Information
            + ''
              declare -i numPassedTests=''${#passedTests[@]}
              declare -i numFailedTests=''${#failedTests[@]}
              declare -i numSkippedTests=''${#skippedTests[@]}
              declare -i numRunTests=$(( numPassedTests + numFailedTests ))
              declare -i numTotalTests=$(( numRunTests + numSkippedTests ))

              echo "Test summary for sample suite ${sampleSuiteName}:"
              echo "- Number of tests: ''${numTotalTests}"
              echo "- Number of tests run: ''${numRunTests}"
              echo "- Number of tests skipped: ''${numSkippedTests}"
              echo "- Number of tests passed: ''${numPassedTests}"
              echo "- Number of tests failed: ''${numFailedTests}"
              echo ""

              if (( numSkippedTests > 0 ))
              then
                echo "Skipped tests:"
                for skippedTest in "''${skippedTests[@]}"
                do
                  echo "- ''${skippedTest}"
                done
              else
                echo "No skipped tests."
              fi
              echo ""

              if (( numPassedTests > 0 ))
              then
                echo "Passed tests:"
                for passedTest in "''${passedTests[@]}"
                do
                  echo "- ''${passedTest}"
                done
              else
                echo "No passed tests."
              fi
              echo ""

              if (( numFailedTests > 0 ))
              then
                echo "Failed tests:"
                for failedTest in "''${failedTests[@]}"
                do
                  echo "- ''${failedTest}"
                done
              else
                echo "No failed tests."
              fi
              echo ""
            '';
        };
    in
    {
      cuda-library-samples = recurseIntoAttrs (
        makeScope finalCudaPackages.newScope (
          cudaLibrarySamplesFinal:
          packagesFromDirectoryRecursive {
            inherit (cudaLibrarySamplesFinal) callPackage;
            directory = toSource {
              root = ./.;
              fileset = unions [
                ./cuBLAS
                ./cuBLASLt
                ./cuBLASMp
                ./cuDSS
                ./cuFFT
                ./NPP
              ];
            };
          }
        )
      );

      tests = recurseIntoAttrs (prevCudaPackages.tests or { }) // {
        cuda-library-samples = recurseIntoAttrs (
          mapAttrs (
            sampleSuiteName: maybeAttrs:
            if (!isAttrs maybeAttrs) then maybeAttrs else mkTestSuite sampleSuiteName maybeAttrs
          ) finalCudaPackages.cuda-library-samples
        );
      };
    };
in
prev: {
  cudaPackagesExtensions = prev.cudaPackagesExtensions or [ ] ++ [
    cudaExtension
  ];
}
