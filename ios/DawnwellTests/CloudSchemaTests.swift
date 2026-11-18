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

    func testOffInNormalBuilds() {
        XCTAssertFalse(CloudSchema.isEnabledInThisBuild)
    }
}
