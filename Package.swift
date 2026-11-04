// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "AutoSmaart",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "AutoSmaart", targets: ["AutoSmaartApp"])
    ],
    targets: [
        .target(name: "AutoSmaartCore"),
        .target(name: "SmaartAPI", dependencies: ["AutoSmaartCore"]),
        .target(name: "ConsoleOSC", dependencies: ["AutoSmaartCore"]),
        .executableTarget(
            name: "AutoSmaartApp",
            dependencies: ["AutoSmaartCore", "SmaartAPI", "ConsoleOSC"],
            resources: [.process("Resources")]
        ),
        .testTarget(name: "AutoSmaartCoreTests", dependencies: ["AutoSmaartCore"], resources: [.process("../Fixtures")]),
        .testTarget(name: "SmaartAPITests", dependencies: ["SmaartAPI"]),
        .testTarget(name: "ConsoleOSCTests", dependencies: ["ConsoleOSC", "AutoSmaartCore"]),
        .testTarget(name: "HardwareTests", dependencies: ["AutoSmaartCore", "SmaartAPI", "ConsoleOSC"])
    ]
)
