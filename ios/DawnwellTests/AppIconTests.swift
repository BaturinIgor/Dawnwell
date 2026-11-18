import XCTest
import UIKit

final class AppIconTests: XCTestCase {
    private var iconSet: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Dawnwell/Resources/Assets.xcassets/AppIcon.appiconset")
    }

    func testAppIconIsCompiledIntoTheApp() throws {
        let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any]
        let primary = icons?["CFBundlePrimaryIcon"] as? [String: Any]
        XCTAssertEqual(primary?["CFBundleIconName"] as? String, "AppIcon")
    }

    func testEveryIconFileIsListedAndIsAnOpaque1024Square() throws {
        guard let data = try? Data(contentsOf: iconSet.appendingPathComponent("Contents.json")) else {
            throw XCTSkip("Icon set not reachable from the simulator")
        }
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let images = try XCTUnwrap(json["images"] as? [[String: Any]])
        let files = images.compactMap { $0["filename"] as? String }
        XCTAssertEqual(files.count, images.count, "Every slot needs a picture")
        XCTAssertTrue(files.contains("AppIcon.png"))
        for name in files {
            let image = try XCTUnwrap(UIImage(contentsOfFile: iconSet.appendingPathComponent(name).path), name)
            let cg = try XCTUnwrap(image.cgImage)
            XCTAssertEqual(cg.width, 1024, name)
            XCTAssertEqual(cg.height, 1024, name)
            // The App Store rejects an icon with an alpha channel.
            let alpha = cg.alphaInfo
            XCTAssertTrue([.none, .noneSkipFirst, .noneSkipLast].contains(alpha), "\(name) has transparency")
        }
    }
}
