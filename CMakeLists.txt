cmake_minimum_required(VERSION 3.7)
project(SwiftJS)

add_custom_target(SwiftJS ALL
        COMMAND /Library/Developer/Toolchains/swift-latest.xctoolchain/usr/bin/swift build
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
        SOURCES Sources Package.swift)
