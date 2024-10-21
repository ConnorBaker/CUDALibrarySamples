#
# Copyright 2023-2024 NVIDIA Corporation.  All rights reserved.
#
# NOTICE TO LICENSEE:
#
# This source code and/or documentation ("Licensed Deliverables") are
# subject to NVIDIA intellectual property rights under U.S. and
# international Copyright laws.
#
# These Licensed Deliverables contained herein is PROPRIETARY and
# CONFIDENTIAL to NVIDIA and is being provided under the terms and
# conditions of a form of NVIDIA software license agreement by and
# between NVIDIA and Licensee ("License Agreement") or electronically
# accepted by Licensee.  Notwithstanding any terms or conditions to
# the contrary in the License Agreement, reproduction or disclosure
# of the Licensed Deliverables to any third party without the express
# written consent of NVIDIA is prohibited.
#
# NOTWITHSTANDING ANY TERMS OR CONDITIONS TO THE CONTRARY IN THE
# LICENSE AGREEMENT, NVIDIA MAKES NO REPRESENTATION ABOUT THE
# SUITABILITY OF THESE LICENSED DELIVERABLES FOR ANY PURPOSE.  IT IS
# PROVIDED "AS IS" WITHOUT EXPRESS OR IMPLIED WARRANTY OF ANY KIND.
# NVIDIA DISCLAIMS ALL WARRANTIES WITH REGARD TO THESE LICENSED
# DELIVERABLES, INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY,
# NONINFRINGEMENT, AND FITNESS FOR A PARTICULAR PURPOSE.
# NOTWITHSTANDING ANY TERMS OR CONDITIONS TO THE CONTRARY IN THE
# LICENSE AGREEMENT, IN NO EVENT SHALL NVIDIA BE LIABLE FOR ANY
# SPECIAL, INDIRECT, INCIDENTAL, OR CONSEQUENTIAL DAMAGES, OR ANY
# DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS,
# WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS
# ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE
# OF THESE LICENSED DELIVERABLES.
#
# U.S. Government End Users.  These Licensed Deliverables are a
# "commercial item" as that term is defined at 48 C.F.R. 2.101 (OCT
# 1995), consisting of "commercial computer software" and "commercial
# computer software documentation" as such terms are used in 48
# C.F.R. 12.212 (SEPT 1995) and is provided to the U.S. Government
# only as a commercial end item.  Consistent with 48 C.F.R.12.212 and
# 48 C.F.R. 227.7202-1 through 227.7202-4 (JUNE 1995), all
# U.S. Government End Users acquire the Licensed Deliverables with
# only those rights set forth herein.
#
# Any use of the Licensed Deliverables in individual and commercial
# software must include, in the user documentation and internal
# comments to the code, the above Disclaimer and U.S. Government End
# Users Notice.
#
cmake_minimum_required(VERSION 3.19)

set(path "${CMAKE_CURRENT_SOURCE_DIR}")
cmake_path(GET path FILENAME EXAMPLE_NAME)

project("cuDSS_${EXAMPLE_NAME}_example"
        DESCRIPTION  "cuDSS"
        HOMEPAGE_URL "https://docs.nvidia.com/cuda/cudss/index.html"
        LANGUAGES    CXX CUDA)

find_package(CUDAToolkit REQUIRED)
find_package(cudss 0.4.0 REQUIRED)

set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(CMAKE_CUDA_STANDARD          11)
set(CMAKE_CUDA_STANDARD_REQUIRED ON)
set(CMAKE_CUDA_EXTENSIONS        OFF)

set_source_files_properties("${CMAKE_CURRENT_SOURCE_DIR}/${EXAMPLE_NAME}.cpp" PROPERTIES LANGUAGE CUDA)

# MGMN-related CMake options
set(MGMN_NPROC 1 CACHE STRING  "Number of MPI processes the MGMN mode examples")
set(MPIRUN_EXECUTABLE "mpirun" CACHE STRING "MPI executable (mpirun) for launching example binaries")
set(MPIRUN_NUMPROC_FLAG "-np" CACHE STRING "MPI flag for setting the number of processes")
set(MPIRUN_EXTRA_FLAGS "--allow-run-as-root" CACHE STRING "Extra flags to be passed to the MPI executable")
option(BUILD_MGMN_WITH_OPENMPI "Enable OpenMPI backend for the MGMN mode examples" ON)
option(BUILD_MGMN_WITH_NCCL    "Enable NCCL backend for the MGMN mode examples" ON)

if (BUILD_MGMN_WITH_OPENMPI OR BUILD_MGMN_WITH_NCCL)
    set(CUDSS_USE_MPI 1)
else()
    set(CUDSS_USE_MPI 0)
endif()

# Determine which communication backend options are passed
# (can be openmpi, nccl or both based on the CMake flags)
include(FindPkgConfig)
set(CUDSS_MGMN_COMM_BACKENDS "")
if (BUILD_MGMN_WITH_OPENMPI)
    pkg_check_modules(MPI_CXX REQUIRED ompi-cxx)
    set(CUDSS_MGMN_COMM_BACKENDS ${CUDSS_MGMN_COMM_BACKENDS} "openmpi")

    if (NOT DEFINED MPI_CXX_INCLUDE_DIRS OR NOT DEFINED MPI_CXX_LIBRARY_DIRS)
        message(FATAL_ERROR "For building MGMN examples with OpenMPI, path to \
        MPI headers and libraries must be set in \
        MPI_CXX_INCLUDE_DIRS and MPI_CXX_LIBRARY_DIRS" )
    else()
        message(STATUS "MPI_CXX_INCLUDE_DIRS = ${MPI_CXX_INCLUDE_DIRS}")
        message(STATUS "MPI_CXX_LIBRARY_DIRS = ${MPI_CXX_LIBRARY_DIRS}")
        message(STATUS "MPI_CXX_LDFLAGS = ${MPI_CXX_LDFLAGS}")
        message(STATUS "MPI_CXX_LDFLAGS_OTHER = ${MPI_CXX_LDFLAGS_OTHER}")
        message(STATUS "MPI_CXX_CFLAGS = ${MPI_CXX_CFLAGS}")
        message(STATUS "MPI_CXX_CFLAGS_OTHER = ${MPI_CXX_CFLAGS_OTHER}")
    endif()
endif()
if (BUILD_MGMN_WITH_NCCL)
    pkg_check_modules(NCCL REQUIRED nccl)
    set(CUDSS_MGMN_COMM_BACKENDS ${CUDSS_MGMN_COMM_BACKENDS} "nccl")

    if (NOT DEFINED NCCL_INCLUDE_DIRS OR NOT DEFINED NCCL_LIBRARY_DIRS)
        message(FATAL_ERROR "For building MGMN examples with NCCL, path to \
        NCCL headers and libraries must be set in \
        NCCL_INCLUDE_DIRS and NCCL_LIBRARY_DIRS" )
    else()
        message(STATUS "NCCL_INCLUDE_DIRS = ${NCCL_INCLUDE_DIRS}")
        message(STATUS "NCCL_LIBRARY_DIRS = ${NCCL_LIBRARY_DIRS}")
    endif()
endif()
message(STATUS "CUDSS_MGMN_COMM_BACKENDS = ${CUDSS_MGMN_COMM_BACKENDS}")

# (optional: only if samples are run with ctest)
enable_testing()

# Helper to make crun launch examples with mpirun (optional: only if samples are run with ctest)
function(test_mpi_launcher target test Nproc)
    if(NOT (DEFINED MPIRUN_EXECUTABLE AND DEFINED MPIRUN_NUMPROC_FLAG))
        message(FATAL_ERROR "MPIRUN_EXECUTABLE and MPIRUN_NUMPROC_FLAG must be defined to use test_mpi_launcher")
    endif()

    if(NOT Nproc)
        message(FATAL_ERROR "Nproc must be defined to use test_mpi_launcher() function in cmake")
    endif()

    # This conversion is a workaround for the case when cmake passes multiple arguments to mpirin with extra ""
    string(REPLACE " " ";" MPIRUN_EXTRA_FLAGS_LIST ${MPIRUN_EXTRA_FLAGS})

    if(CMAKE_VERSION VERSION_GREATER_EQUAL 3.29)
        set_property(TARGET ${target} PROPERTY TEST_LAUNCHER ${MPIRUN_EXECUTABLE} ${MPIRUN_EXTRA_FLAGS_LIST} ${MPIRUN_NUMPROC_FLAG} ${Nproc})
    else()
        set_property(TARGET ${target} PROPERTY CROSSCOMPILING_EMULATOR ${MPIRUN_EXECUTABLE} ${MPIRUN_EXTRA_FLAGS_LIST} ${MPIRUN_NUMPROC_FLAG} ${Nproc})
    endif()

    set_property(TEST ${test} PROPERTY PROCESSORS ${Nproc})
endfunction()

foreach(backend ${CUDSS_MGMN_COMM_BACKENDS})
    set(EXE_NAME "${EXAMPLE_NAME}_example_${backend}")

    add_executable(${EXE_NAME} "${CMAKE_CURRENT_SOURCE_DIR}/${EXAMPLE_NAME}.cpp")

    set_target_properties(${EXE_NAME} PROPERTIES LINK_WHAT_YOU_USE TRUE)

    target_compile_options(${EXE_NAME}
        PRIVATE
            "$<$<CONFIG:Debug>:-lineinfo -g>"
            "$<$<CONFIG:RelWithDebInfo>:-lineinfo -g>"
    )

    target_link_libraries(${EXE_NAME}
        PUBLIC
            CUDA::cudart
            cudss
    )

    target_include_directories(${EXE_NAME} PUBLIC ${cudss_INCLUDE_DIR})

    if (CUDSS_USE_MPI)
        target_compile_options(${EXE_NAME} PRIVATE -DUSE_MPI)
    endif()

    if ("${backend}" STREQUAL "openmpi")
        target_compile_options(${EXE_NAME} PRIVATE -DUSE_OPENMPI ${MPI_CXX_CFLAGS})
        target_link_options(${EXE_NAME} PRIVATE ${MPI_CXX_LDFLAGS})
        target_include_directories(${EXE_NAME} PUBLIC ${MPI_CXX_INCLUDE_DIRS})
        target_link_directories(${EXE_NAME} PUBLIC ${MPI_CXX_LIBRARY_DIRS} ${MPI_CXX_LIBRARY_DIRS}/openmpi)
        target_link_libraries(${EXE_NAME} PUBLIC mpi)
    elseif ("${backend}" STREQUAL "nccl")
        # Note: for NCCL we still need the MPI header (for mpi.h) and library (for MPI_Init)
        target_compile_options(${EXE_NAME} PRIVATE -DUSE_NCCL ${NCCL_CFLAGS})
        target_link_options(${EXE_NAME} PRIVATE ${NCCL_LDFLAGS})
        target_include_directories(${EXE_NAME} PUBLIC ${NCCL_INCLUDE_DIRS})
        target_link_directories(${EXE_NAME} PUBLIC ${NCCL_LIBRARY_DIRS})
        target_link_libraries(${EXE_NAME} PUBLIC nccl)
    endif()

    # (optional: only if samples are run with ctest)
    add_test(NAME ${EXE_NAME} COMMAND ${EXE_NAME} ${backend} ${cudss_LIBRARY_DIR}/libcudss_commlayer_${backend}.so)
    test_mpi_launcher(${EXE_NAME} ${EXE_NAME} ${MGMN_NPROC})

    install(
        TARGETS ${EXE_NAME}
        RUNTIME DESTINATION "${CMAKE_INSTALL_BINDIR}"
    )
endforeach()
