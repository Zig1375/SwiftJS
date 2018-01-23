import PackageDescription

let package = Package(
    name:         "SwiftDuktapeWrapper",
    targets:      [],
    dependencies: [
        .Package(url: "https://github.com/remko/swift-duktape.git", majorVersion: 0, minor: 2)
    ]
)