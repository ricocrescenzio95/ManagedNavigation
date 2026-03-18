// swift-tools-version: 6.2

import PackageDescription
import CompilerPluginSupport

let package = Package(
  name: "ManagedNavigation",
  platforms: [.iOS(.v16), .macOS(.v13), .macCatalyst(.v16), .tvOS(.v16), .visionOS(.v1)],
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
