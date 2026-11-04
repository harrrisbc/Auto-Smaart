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
        .target(name: "AutoSmaartPass", dependencies: ["AutoSmaartCore", "ConsoleOSC", "SmaartAPI"]),
        .executableTarget(
            name: "AutoSmaartApp",
            dependencies: ["AutoSmaartCore", "SmaartAPI", "ConsoleOSC"],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "AutoSmaartCoreTests",
            dependencies: ["AutoSmaartCore"],
            path: "Tests",
            exclude: ["SmaartAPITests", "ConsoleOSCTests", "HardwareTests", "AutoSmaartPassTests"],
            sources: ["AutoSmaartCoreTests"],
            resources: [.process("Fixtures")]
        ),
        .testTarget(name: "SmaartAPITests", dependencies: ["SmaartAPI", "AutoSmaartCore"]),
        .testTarget(name: "ConsoleOSCTests", dependencies: ["ConsoleOSC", "AutoSmaartCore"]),
        .testTarget(
            name: "AutoSmaartPassTests",
            dependencies: ["AutoSmaartPass", "AutoSmaartCore", "ConsoleOSC", "SmaartAPI"],
            path: "Tests",
            exclude: ["AutoSmaartCoreTests", "SmaartAPITests", "ConsoleOSCTests", "HardwareTests"],
            sources: ["AutoSmaartPassTests"],
            resources: [.process("Fixtures")]
        ),
        .testTarget(name: "HardwareTests", dependencies: ["AutoSmaartCore", "SmaartAPI", "ConsoleOSC"])
    ]
)
