cmake_minimum_required(VERSION 3.14)

project(griddb_python)

set(C_LIB E:/c_client-master/c_client-master/bin/x64/Release)
set(C_HEADER E:/c_client-master/c_client-master/client/c/include)
set(SOURCE_HEADER E:/cmake-fun/SourceCode/src)
set(PYTHON_RESOURCE C:/Users/griddb/AppData/Local/Programs/Python/Python36/)
set(SWIG_RESOURCE E:/swigwin-3.0.12)

set(PYTHON_LIBRARIES ${PYTHON_RESOURCE}/libs)
set(PYTHON_INCLUDE_DIRS ${PYTHON_RESOURCE}/include)
set(PYTHON_LIBRARY ${PYTHON_RESOURCE}/libs)
set(PYTHON_INCLUDE_DIR ${PYTHON_RESOURCE}/include)
find_package(PythonLibs 3 REQUIRED)
find_package(PythonInterp 3 REQUIRED)

set(SWIG_DIR ${SWIG_RESOURCE}/Lib)
set(SWIG_EXECUTABLE ${SWIG_RESOURCE}/swig.exe)
find_package(SWIG REQUIRED)
include(${SWIG_USE_FILE})

set(CMAKE_SWIG_FLAGS -c++)
set(CMAKE_CXX_FLAGS "/DLL /LD /D_USRDLL /D_WINDLL /MT /MD")

include_directories(${C_HEADER} ${PYTHON_RESOURCE}/include ${SOURCE_HEADER})
link_directories(${PYTHON_RESOURCE}/libs ${C_LIB})

set_property(SOURCE ${SOURCE_HEADER}/griddb.i PROPERTY CPLUSPLUS ON)
swig_add_library(griddb_python TYPE SHARED LANGUAGE python SOURCES ${SOURCE_HEADER}/griddb.i
${SOURCE_HEADER}/TimeSeriesProperties.cpp
${SOURCE_HEADER}/ContainerInfo.cpp
${SOURCE_HEADER}/AggregationResult.cpp
${SOURCE_HEADER}/Container.cpp
${SOURCE_HEADER}/Store.cpp
${SOURCE_HEADER}/StoreFactory.cpp
${SOURCE_HEADER}/PartitionController.cpp
${SOURCE_HEADER}/Query.cpp
${SOURCE_HEADER}/QueryAnalysisEntry.cpp
${SOURCE_HEADER}/RowKeyPredicate.cpp
${SOURCE_HEADER}/RowSet.cpp
${SOURCE_HEADER}/TimestampUtils.cpp
${SOURCE_HEADER}/Field.cpp
${SOURCE_HEADER}/Util.cpp)

target_link_libraries(griddb_python gridstore_c)
