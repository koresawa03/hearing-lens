// swift-tools-version: 5.9

// F-08 / overall: Swift Playgrounds App package definition (declares microphone permission, supported devices, etc.)
import PackageDescription
import AppleProductTypes

let package = Package(
    name: "HearingLens",
    platforms: [
        .iOS("17.0")
    ],
    products: [
        .iOSApplication(
            name: "HearingLens",
            targets: ["AppModule"],
            bundleIdentifier: "com.koresawa.HearingLens",
            teamIdentifier: "",
            displayVersion: "1.0",
            bundleVersion: "1",
            appIcon: .placeholder(icon: .mic),
            // Required by the placeholder icon (the build fails without it). Never shown: the UI overrides tint with Theme.foreground
            accentColor: .presetColor(.indigo),
            supportedDeviceFamilies: [
                .pad,
                .phone
            ],
            supportedInterfaceOrientations: [
                .portrait,
                .landscapeRight,
                .landscapeLeft,
                .portraitUpsideDown(.when(deviceFamilies: [.pad]))
            ],
            capabilities: [
                .microphone(purposeString: "HearingLens uses the microphone to apply hearing filters to nearby sounds and voices, played back through your headphones. Audio is never recorded, saved or sent.")
            ],
            appCategory: .education
        )
    ],
    targets: [
        .executableTarget(
            name: "AppModule",
            path: "."
        )
    ]
)
