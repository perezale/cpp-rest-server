cmake_minimum_required(VERSION 3.0)
project(opencvDemo)
#set(CMAKE_BUILD_TYPE Debug)
#set(CMAKE_CXX_FLAGS_DEBUG "${CMAKE_CXX_FLAGS_DEBUG} -Wall")


find_package(OpenCV REQUIRED)
find_package(cpprestsdk CONFIG REQUIRED)
find_package(Boost COMPONENTS system REQUIRED)

set(CMAKE_CXX_STANDARD 14)

#source/pdi.cpp header/pdi.h source/Server.cpp header/Server.h
add_executable(opencvDemo main.cpp)
add_compile_options(-lopencv_imgcodecs)
add_compile_options(OPENCV_ENABLE_NONFREE=ON)

include_directories(${OpenCV_INCLUDE_DIRS})
include_directories(${Boost_INCLUDE_DIRS} )
target_link_libraries(opencvDemo ${Boost_LIBRARIES} ${OpenCV_LIBS} curl ssl crypto cpprestsdk::cpprest)
