import ProjectDescription

let project = Project(
    name: "PixelOffice",
    options: .options(
        automaticSchemesOptions: .enabled()
    ),
    settings: .settings(
        base: [
            "DEVELOPMENT_TEAM": "QGAQ3AY3R3",
            "SWIFT_VERSION": "5.0"
        ],
        configurations: [
            .debug(name: "Debug"),
            .release(name: "Release")
        ]
    ),
    targets: [
        .target(
            name: "PixelOffice",
            destinations: .macOS,
            product: .app,
            bundleId: "com.leeo.PixelOffice",
            deploymentTargets: .macOS("14.0"),
            infoPlist: .extendingDefault(with: [
                "CFBundleDisplayName": "PixelOffice",
                "NSHumanReadableCopyright": "",
                "LSMinimumSystemVersion": "14.0"
            ]),
            sources: ["PixelOffice/**/*.swift"],
            resources: [
                "PixelOffice/Assets.xcassets"
            ],
            // entitlements: "PixelOffice/PixelOffice.entitlements",
            settings: .settings(
                base: [
                    "CODE_SIGN_STYLE": "Automatic",
                    "COMBINE_HIDPI_IMAGES": "YES",
                    "ENABLE_PREVIEWS": "YES",
                    "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
                    "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": "AccentColor"
                ]
            )
        )
    ]
)
