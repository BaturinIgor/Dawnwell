import CoreData
import XCTest
@testable import Dawnwell

final class CloudSchemaTests: XCTestCase {
    func testCoreDataSeesEveryModel() throws {
        let model = try XCTUnwrap(CloudSchema.managedObjectModel())
        let names = Set(model.entities.compactMap(\.name))
        XCTAssertEqual(names, ["Profile", "DayLog", "FoodEntry", "SymptomEntry", "WeightEntry", "DoseChange"])
    }

    func testModelIsSyncable() throws {
        // CloudKit needs every attribute optional or defaulted and no unique constraints.
        let model = try XCTUnwrap(CloudSchema.managedObjectModel())
        for entity in model.entities {
            XCTAssertTrue(entity.uniquenessConstraints.isEmpty, "\(entity.name ?? "?") has a unique constraint")
            for attr in entity.attributesByName.values {
                XCTAssertTrue(attr.isOptional || attr.defaultValue != nil, "\(entity.name ?? "?").\(attr.name) needs a default")
            }
        }
    }

    /// The schema file imported into iCloud must match the data model, or iCloud rejects records.
    /// After a model change, copy the generated text from the failure message into the file.
    func testSchemaFileMatchesTheModel() throws {
        let model = try XCTUnwrap(CloudSchema.managedObjectModel())
        let generated = try CloudSchema.ckdb(for: model)
        let file = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("CloudKit/schema.ckdb")
        let saved = try String(contentsOf: file, encoding: .utf8)
        XCTAssertEqual(saved, generated, "ios/CloudKit/schema.ckdb is out of date. It should be:\n\(generated)")
    }

    func testEveryAttributeHasACloudKitType() throws {
        let model = try XCTUnwrap(CloudSchema.managedObjectModel())
        for entity in model.entities {
            for attr in entity.attributesByName.values {
                XCTAssertNotNil(CloudSchema.fields(for: attr), "\(entity.name ?? "?").\(attr.name)")
            }
        }
    }

    func testStringsAndDataGetAnAssetFieldForLargeValues() throws {
        let model = try XCTUnwrap(CloudSchema.managedObjectModel())
        let text = try CloudSchema.ckdb(for: model)
        XCTAssertTrue(text.contains("CD_note_ckAsset ASSET"))
        XCTAssertTrue(text.contains("CD_triggers BYTES"))
        XCTAssertTrue(text.contains("CD_entryID STRING,"), "UUIDs are plain strings without an asset field")
        XCTAssertFalse(text.contains("CD_entryID_ckAsset"))
    }
}
