# The following lines of boilerplate have to be in your project's CMakeLists
# in this exact order for cmake to work correctly
cmake_minimum_required(VERSION 3.16)

include($ENV{IDF_PATH}/tools/cmake/project.cmake)
project(music_x_flute)

idf_build_set_property(COMPILE_OPTIONS "-Wall" APPEND)
idf_build_set_property(COMPILE_OPTIONS "-Wdouble-promotion" APPEND)
idf_build_set_property(COMPILE_OPTIONS "-Wfloat-conversion" APPEND)
# idf_build_set_property(COMPILE_OPTIONS "-Wundef" APPEND)
# idf_build_set_property(COMPILE_OPTIONS "-Wno-error=undef" APPEND)
