// swift-tools-version: 6.2

import PackageDescription
import CompilerPluginSupport

let package = Package(
  name: "ManagedNavigation",
  platforms: [.iOS(.v17), .macOS(.v14), .macCatalyst(.v17), .tvOS(.v17), .visionOS(.v1)],
  products: [
    .library(
      name: "ManagedNavigation",
      targets: ["ManagedNavigation"]
    ),
  ],
  targets: [
    .target(
      name: "ManagedNavigation",
    ),
    .testTarget(
      name: "ManagedNavigationTests",
      dependencies: ["ManagedNavigation"]
    ),
  ]
)
