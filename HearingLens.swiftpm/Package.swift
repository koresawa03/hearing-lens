// swift-tools-version: 5.9

// F-08 / 全体: Swift Playgrounds App パッケージ定義（マイク権限・対応端末などを宣言）
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
                .microphone(purposeString: "周囲の音や声に聞こえ方のフィルタをかけてヘッドホンで体験するためにマイクを使います。音声は録音・保存・送信しません。")
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
