# 
# Copyright (c) 2020, NVIDIA CORPORATION.  All rights reserved.
# 
# NVIDIA CORPORATION and its licensors retain all intellectual property
# and proprietary rights in and to this software, related documentation
# and any modifications thereto. Any use, reproduction, disclosure or
# distribution of this software and related documentation without an express
# license agreement from NVIDIA CORPORATION is strictly prohibited.
# 

cmake_minimum_required(VERSION 3.18.0 FATAL_ERROR)

set(path "${CMAKE_CURRENT_SOURCE_DIR}")
cmake_path(GET path FILENAME PROJECT_NAME)

project("${PROJECT_NAME}" LANGUAGES CXX CUDA)

add_subdirectory(LtDgemmPresetAlgo)
add_subdirectory(LtFp8Matmul)
add_subdirectory(LtHSHgemmStridedBatchSimple)
add_subdirectory(LtIgemmTensor)
add_subdirectory(LtPlanarComplex)
add_subdirectory(LtSgemm)
add_subdirectory(LtSgemmCustomFind)
add_subdirectory(LtSgemmSimpleAutoTuning)
