cmake_minimum_required(VERSION 3.7)
project(SwiftDuktapeWrapper)

add_custom_target(SwiftDuktapeWrapper ALL
        COMMAND /Library/Developer/Toolchains/swift-latest.xctoolchain/usr/bin/swift build
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
        SOURCES Sources Package.swift)
