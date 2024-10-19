# 
# Copyright (c) 2020, NVIDIA CORPORATION.  All rights reserved.
#
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are
# met:
#  - Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
#  - Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#  - Neither the name(s) of the copyright holder(s) nor the names of its
#    contributors may be used to endorse or promote products derived
#    from this software without specific prior written permission.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR 
# A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
# HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
# 

function(add_sample_cublas)

if(NOT DEFINED PROJECT_NAME OR "${PROJECT_NAME}" STREQUAL "")
    message(FATAL_ERROR "PROJECT_NAME is not defined or is empty")
endif()

find_package(CUDAToolkit REQUIRED)

set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(EXE_NAME "cublas_${PROJECT_NAME}_example")

add_executable(${EXE_NAME} "${CMAKE_CURRENT_SOURCE_DIR}/${EXE_NAME}.cu")

set_target_properties(${EXE_NAME} PROPERTIES LINK_WHAT_YOU_USE TRUE)

target_include_directories(${EXE_NAME}
    PRIVATE
        # utils directory is up two levels from the source directory
        "${CMAKE_CURRENT_SOURCE_DIR}/../../utils"
        ${CMAKE_CUDA_TOOLKIT_INCLUDE_DIRECTORIES}
)

target_link_libraries(${EXE_NAME}
    PUBLIC
        CUDA::cudart
        CUDA::cublas
)

install(
    TARGETS ${EXE_NAME}
    RUNTIME DESTINATION "${CMAKE_INSTALL_BINDIR}"
)

endfunction()
