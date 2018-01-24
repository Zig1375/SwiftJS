import PackageDescription

let package = Package(
    name:         "SwiftJS",
    targets:      [],
    dependencies: [
        .Package(url: "https://github.com/remko/swift-duktape.git", majorVersion: 0, minor: 2)
    ]
)