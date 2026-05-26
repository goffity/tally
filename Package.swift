// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Tally",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Tally", targets: ["Tally"])
    ],
    targets: [
        .executableTarget(
            name: "Tally",
            path: "Sources/Tally"
        )
    ]
)
