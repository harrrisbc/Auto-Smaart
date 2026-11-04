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
        .target(
            name: "AutoSmaartUI",
            dependencies: ["AutoSmaartPass", "AutoSmaartCore"],
            resources: [.process("Resources")]
        ),
        .executableTarget(
            name: "AutoSmaartApp",
            dependencies: ["AutoSmaartUI", "AutoSmaartPass", "AutoSmaartCore", "ConsoleOSC", "SmaartAPI"]
        ),
        .testTarget(
            name: "AutoSmaartCoreTests",
            dependencies: ["AutoSmaartCore"],
            path: "Tests",
            exclude: ["SmaartAPITests", "ConsoleOSCTests", "HardwareTests", "AutoSmaartPassTests", "AutoSmaartUITests"],
            sources: ["AutoSmaartCoreTests"],
            resources: [.process("Fixtures")]
        ),
        .testTarget(name: "SmaartAPITests", dependencies: ["SmaartAPI", "AutoSmaartCore"]),
        .testTarget(name: "ConsoleOSCTests", dependencies: ["ConsoleOSC", "AutoSmaartCore"]),
        .testTarget(
            name: "AutoSmaartPassTests",
            dependencies: ["AutoSmaartPass", "AutoSmaartCore", "ConsoleOSC", "SmaartAPI"],
            path: "Tests",
            exclude: ["AutoSmaartCoreTests", "SmaartAPITests", "ConsoleOSCTests", "HardwareTests", "AutoSmaartUITests"],
            sources: ["AutoSmaartPassTests"],
            resources: [.process("Fixtures")]
        ),
        .testTarget(
            name: "AutoSmaartUITests",
            dependencies: ["AutoSmaartUI", "AutoSmaartPass", "AutoSmaartCore", "ConsoleOSC", "SmaartAPI"]
        ),
        .testTarget(name: "HardwareTests", dependencies: ["AutoSmaartCore", "SmaartAPI", "ConsoleOSC"])
    ]
)
