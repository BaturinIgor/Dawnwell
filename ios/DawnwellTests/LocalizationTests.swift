import XCTest
@testable import Dawnwell

/// The app ships in 18 languages. These checks run against the built app, so they also catch
/// a language folder that did not make it into the bundle.
final class LocalizationTests: XCTestCase {
    static let languages = ["en", "de", "fr", "es", "it", "pt-BR", "pt-PT", "nl", "sv", "da", "nb", "fi",
                            "pl", "tr", "ja", "ko", "zh-Hans", "zh-Hant"]

    private func bundle(_ lang: String) throws -> Bundle {
        let path = try XCTUnwrap(Bundle.main.path(forResource: lang, ofType: "lproj"), "\(lang).lproj is not in the app")
        return try XCTUnwrap(Bundle(path: path))
    }

    private func table(_ lang: String, _ name: String = "Localizable", _ ext: String) throws -> [String: Any] {
        let url = try XCTUnwrap(bundle(lang).url(forResource: name, withExtension: ext), "\(lang): \(name).\(ext) missing")
        return try XCTUnwrap(NSDictionary(contentsOf: url) as? [String: Any], "\(lang): \(name).\(ext) unreadable")
    }

    private func keys(_ lang: String) throws -> Set<String> {
        Set(try table(lang, ext: "strings").keys).union(try table(lang, ext: "stringsdict").keys)
    }

    /// Format arguments in order, with positions ("%2$lld") put back in argument order.
    private func arguments(_ s: String) -> [String] {
        let text = s.replacingOccurrences(of: "%%", with: "")
        let regex = try! NSRegularExpression(pattern: #"%(?:(\d+)\$)?(lld|@)"#)
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        let found = matches.enumerated().map { i, m -> (Int, String) in
            let position = Range(m.range(at: 1), in: text).flatMap { Int(text[$0]) } ?? i + 1
            return (position, String(text[Range(m.range(at: 2), in: text)!]))
        }
        return found.sorted { $0.0 < $1.0 }.map(\.1)
    }

    private func format(_ lang: String, _ key: String, _ args: CVarArg...) throws -> String {
        let pattern = try bundle(lang).localizedString(forKey: key, value: nil, table: nil)
        return String(format: pattern, locale: Locale(identifier: lang), arguments: args)
    }

    func testEveryLanguageIsInTheApp() {
        for lang in Self.languages {
            XCTAssertNotNil(Bundle.main.path(forResource: lang, ofType: "lproj"), lang)
        }
    }

    func testEveryLanguageHasEveryKey() throws {
        let english = try keys("en")
        XCTAssertGreaterThan(english.count, 300)
        for lang in Self.languages where lang != "en" {
            let have = try keys(lang)
            XCTAssertEqual(english.subtracting(have).sorted(), [], "\(lang) is missing keys")
            XCTAssertEqual(have.subtracting(english).sorted(), [], "\(lang) has keys English does not")
        }
    }

    func testTranslationsTakeTheSameArgumentsAsTheirKey() throws {
        for lang in Self.languages {
            for (key, value) in try table(lang, ext: "strings") {
                let text = try XCTUnwrap(value as? String)
                XCTAssertFalse(text.trimmingCharacters(in: .whitespaces).isEmpty, "\(lang): \(key) is empty")
                XCTAssertEqual(arguments(text), arguments(key), "\(lang): \(key)")
            }
        }
    }

    func testPluralsPickTheRightForm() throws {
        let key = "%lld tablets left. Time to ask for a refill."
        XCTAssertEqual(try format("en", key, 1), "1 tablet left. Time to ask for a refill.")
        XCTAssertEqual(try format("en", key, 3), "3 tablets left. Time to ask for a refill.")
        XCTAssertEqual(try format("de", key, 1), "Noch 1 Tablette. Zeit für ein Folgerezept.")
        XCTAssertEqual(try format("pl", key, 1), "Została 1 tabletka. Czas na kolejną receptę.")
        XCTAssertEqual(try format("pl", key, 3), "Zostały 3 tabletki. Czas na kolejną receptę.")
        XCTAssertEqual(try format("pl", key, 5), "Zostało 5 tabletek. Czas na kolejną receptę.")
        XCTAssertEqual(try format("ja", key, 2), "残り2錠です。補充を依頼しましょう。")
    }

    func testPluralWithOtherArgumentsKeepsThemInPlace() throws {
        let key = "- %@: %lld days, worst %lld/5"
        XCTAssertEqual(try format("en", key, "Nausea", 1, 3), "- Nausea: 1 day, worst 3/5")
        XCTAssertEqual(try format("en", key, "Nausea", 4, 2), "- Nausea: 4 days, worst 2/5")
        XCTAssertEqual(try format("de", key, "Übelkeit", 4, 2), "- Übelkeit: 4 Tage, am stärksten 2/5")
        XCTAssertEqual(try format("en", "%lld items · %@", 1, "Lunch"), "1 item · Lunch")
    }

    func testReorderedArgumentsLandInTheRightPlace() throws {
        XCTAssertEqual(try format("ja", "Tablet logged taken on %lld of %lld days", 20, 30), "服用を記録した日：30日中20日")
    }

    func testStoredEnglishValuesAreTranslatedForDisplay() throws {
        let de = try bundle("de")
        XCTAssertEqual(Loc.text("Eggs", bundle: de), "Eier")
        XCTAssertEqual(Loc.text("Fatty food", bundle: de), "Fettiges Essen")
        XCTAssertEqual(Loc.text("Homemade soup", bundle: de), "Homemade soup", "food the user typed stays as typed")
        let translated = Catalog.foods.filter { Loc.text($0.name, bundle: de) != $0.name }
        XCTAssertGreaterThanOrEqual(translated.count, Catalog.foods.count - 1, "only Edamame keeps its name")
    }

    func testDoseLabelsReadTheSameWithOrWithoutTheOldSuffix() {
        XCTAssertEqual(Loc.doseDaily("7 mg"), "7 mg daily")
        XCTAssertEqual(Loc.doseDaily("7 mg daily"), "7 mg daily")
    }

    func testHealthPermissionTextIsTranslated() throws {
        for lang in Self.languages {
            let info = try table(lang, "InfoPlist", ext: "strings")
            let text = try XCTUnwrap(info["NSHealthShareUsageDescription"] as? String, lang)
            XCTAssertTrue(text.contains("Dawnwell"), lang)
        }
    }
}
