cmake_minimum_required(VERSION 3.10)
project(FPGA_Encryption)

set(CMAKE_CXX_STANDARD 11)

find_package(OpenSSL REQUIRED)

# Local encryption tool
add_executable(encrypt_local encrypt_local.cpp)
target_link_libraries(encrypt_local OpenSSL::Crypto)

# FPGA sender (runs on Raspberry Pi)
add_executable(fpga_sender piApp/main.cpp)
