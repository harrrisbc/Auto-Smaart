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
        .target(name: "AutoSmaartRingOut", dependencies: ["AutoSmaartCore", "ConsoleOSC", "SmaartAPI"]),
        .target(
            name: "AutoSmaartUI",
            dependencies: ["AutoSmaartPass", "AutoSmaartRingOut", "AutoSmaartCore", "SmaartAPI", "ConsoleOSC"],
            resources: [.process("Resources")]
        ),
        .executableTarget(
            name: "AutoSmaartApp",
            dependencies: ["AutoSmaartUI"],
            exclude: ["Info.plist"],
            // Embed Info.plist so a bare SPM binary can register with WindowServer
            // (without this, lsappinfo shows !cgsConnection and the process is culled).
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Sources/AutoSmaartApp/Info.plist"
                ])
            ]
        ),

        .testTarget(
            name: "AutoSmaartCoreTests",
            dependencies: ["AutoSmaartCore"],
            path: "Tests",
            exclude: [
                "SmaartAPITests", "ConsoleOSCTests", "HardwareTests",
                "AutoSmaartPassTests", "AutoSmaartUITests", "AutoSmaartRingOutTests"
            ],
            sources: ["AutoSmaartCoreTests"],
            resources: [.process("Fixtures")]
        ),
        .testTarget(name: "SmaartAPITests", dependencies: ["SmaartAPI", "AutoSmaartCore"]),
        .testTarget(name: "ConsoleOSCTests", dependencies: ["ConsoleOSC", "AutoSmaartCore"]),
        .testTarget(
            name: "AutoSmaartPassTests",
            dependencies: ["AutoSmaartPass", "AutoSmaartCore", "ConsoleOSC", "SmaartAPI"],
            path: "Tests",
            exclude: [
                "AutoSmaartCoreTests", "SmaartAPITests", "ConsoleOSCTests",
                "HardwareTests", "AutoSmaartUITests", "AutoSmaartRingOutTests"
            ],
            sources: ["AutoSmaartPassTests"],
            resources: [.process("Fixtures")]
        ),
        .testTarget(
            name: "AutoSmaartRingOutTests",
            dependencies: ["AutoSmaartRingOut", "AutoSmaartCore", "ConsoleOSC", "SmaartAPI"]
        ),
        .testTarget(
            name: "AutoSmaartUITests",
            dependencies: ["AutoSmaartUI", "AutoSmaartPass", "AutoSmaartRingOut", "AutoSmaartCore", "ConsoleOSC", "SmaartAPI"]
        ),
        .testTarget(
            name: "HardwareTests",
            dependencies: ["AutoSmaartCore", "SmaartAPI", "ConsoleOSC", "AutoSmaartPass", "AutoSmaartRingOut"]
        )
    ]
)
