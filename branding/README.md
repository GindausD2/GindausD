# Max brand artwork

The owner approved the glacier-blue glass logo on 28 October 2026. Its ring opening and detached lower-right curve are intentional.

- `Max_Logo_Glacier.png`: transparent glass-blue master used inside the native iPhone app.
- `Max_Logo_Profile.png`: square, transparent export with extra space for a circular social profile crop.
- `Max_App_Icon.png`: opaque 1024 × 1024 export for the iPhone Home Screen icon. iOS supplies its rounded mask.

`ios-swift/Sources/SharedBrand/BrandAssets.xcassets` contains the in-app artwork. The app, widget and Live Activity targets all include this catalog and the shared `MaxLogoView`; render it in original colors rather than applying a monochrome tint. The launch storyboard references this same asset.

The original black/white references, SVG and path data remain archival sources. `import_logo.py` regenerates only those monochrome exports. It deliberately does not overwrite the approved blue artwork, native view or app icon.

Asset installation and an unsigned build do not establish a signed iPhone install, TestFlight availability or physical-device behavior.
