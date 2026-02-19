// swift-tools-version: 5.9
// OpenNotch macOS app - SwiftUI host for Rust core

import PackageDescription

let package = Package(
    name: "OpenNotch",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(name: "OpenNotch", targets: ["OpenNotch"]),
    ],
    targets: [
        .systemLibrary(
            name: "opennotch_ffiFFI",
            path: "Sources/Generated"
        ),
        .executableTarget(
            name: "OpenNotch",
            dependencies: ["opennotch_ffiFFI"],
            path: "Sources",
            exclude: ["Resources"],
            resources: [.process("Resources")],
            linkerSettings: [
                .linkedLibrary("opennotch_ffi", .when(platforms: [.macOS])),
                .unsafeFlags(["-L", "../../target/release"], .when(platforms: [.macOS])),
            ]
        ),
    ]
)
