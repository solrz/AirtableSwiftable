// swift-tools-version:5.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AirtableSwiftable",
    platforms: [
        .iOS(.v10),
        .macOS(.v10_12),
        .tvOS(.v10),
        .watchOS(.v3)
    ],
    
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "AirtableSwiftable",
            targets: ["AirtableSwiftable"]),
    ],
    dependencies: [
        .package(url: "https://github.com/Alamofire/Alamofire.git", .exact("5.2.1")),
        .package(url: "https://github.com/SwiftyJSON/SwiftyJSON.git", .exact("5.0.0"))
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "AirtableSwiftable",
            dependencies: ["Alamofire","SwiftyJSON"],
            path:"Sources"
        ),
        .testTarget(
            name: "AirtableSwiftableTests",
            dependencies: ["AirtableSwiftable"],
            path:"Tests"
        ),
    ]
)
