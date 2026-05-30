// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SyncFavoritosDaemon",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "syncfavoritosd", targets: ["SyncFavoritosDaemon"])
    ],
    targets: [
        .executableTarget(
            name: "SyncFavoritosDaemon",
            path: "Sources"
        )
    ]
)

