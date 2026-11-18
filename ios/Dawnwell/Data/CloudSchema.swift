import CoreData
import Foundation
import SwiftData

/// Dawnwell's record types in the user's private iCloud database, written as a CloudKit schema file.
///
/// iCloud only syncs record types that exist in the container's Production schema, and Production
/// can't create them on the fly. `ios/CloudKit/schema.ckdb` holds them; the "iCloud schema" workflow
/// imports it into Development with `cktool`, then it is deployed to Production in CloudKit Console.
/// `CloudSchemaTests` checks the file against `ckdb()`, which follows Core Data's CloudKit mapping:
/// https://developer.apple.com/documentation/coredata/reading-cloudkit-records-for-core-data
enum CloudSchema {
    /// The same model SwiftData stores, as Core Data sees it.
    static func managedObjectModel() -> NSManagedObjectModel? {
        NSManagedObjectModel.makeManagedObjectModel(for: SchemaV1.models)
    }

    enum Problem: Error, Equatable { case unsupported(entity: String, attribute: String) }

    /// CloudKit field types for one Core Data attribute: its own field, plus an asset field for
    /// variable-length values that Core Data moves out of the record when they grow past 1 MB.
    static func fields(for attr: NSAttributeDescription) -> [(name: String, type: String)]? {
        let name = "CD_\(attr.name)"
        switch attr.attributeType {
        case .integer16AttributeType, .integer32AttributeType, .integer64AttributeType, .booleanAttributeType:
            return [(name, "INT64")]
        case .doubleAttributeType, .floatAttributeType, .decimalAttributeType:
            return [(name, "DOUBLE")]
        case .dateAttributeType:
            return [(name, "TIMESTAMP")]
        case .UUIDAttributeType, .URIAttributeType:
            return [(name, "STRING")]
        case .stringAttributeType:
            return [(name, "STRING"), ("\(name)_ckAsset", "ASSET")]
        case .binaryDataAttributeType, .transformableAttributeType:
            return [(name, "BYTES"), ("\(name)_ckAsset", "ASSET")]
        default:
            return nil
        }
    }

    /// The schema file text for a model.
    static func ckdb(for model: NSManagedObjectModel) throws -> String {
        var out = "DEFINE SCHEMA\n"
        for entity in model.entities.sorted(by: { ($0.name ?? "") < ($1.name ?? "") }) where entity.superentity == nil {
            let entityName = entity.name ?? ""
            var fields: [(name: String, type: String)] = [("CD_entityName", "STRING")]
            for attr in entity.attributesByName.values {
                guard let f = Self.fields(for: attr) else {
                    throw Problem.unsupported(entity: entityName, attribute: attr.name)
                }
                fields += f
            }
            // Dawnwell has no relationships; entries point at their day by key (see SchemaV1).
            for rel in entity.relationshipsByName.values where !rel.isToMany {
                fields.append(("CD_\(rel.name)", "STRING"))
            }
            out += "\n    RECORD TYPE CD_\(entityName) (\n"
            out += systemFields.map { "        \($0),\n" }.joined()
            out += fields.sorted { $0.name < $1.name }.map { "        \($0.name) \($0.type),\n" }.joined()
            out += grants.map { "        \($0)" }.joined(separator: ",\n") + "\n    );\n"
        }
        out += """

            RECORD TYPE Users (
                "___createTime" TIMESTAMP,
                "___createdBy" REFERENCE,
                "___etag" STRING,
                "___modTime" TIMESTAMP,
                "___modifiedBy" REFERENCE,
                "___recordID" REFERENCE,
                roles LIST<INT64>,
                GRANT WRITE TO "_creator",
                GRANT READ TO "_world"
            );

        """
        return out
    }

    private static let systemFields = [
        "\"___createTime\" TIMESTAMP",
        "\"___createdBy\" REFERENCE",
        "\"___etag\" STRING",
        "\"___modTime\" TIMESTAMP",
        "\"___modifiedBy\" REFERENCE",
        "\"___recordID\" REFERENCE QUERYABLE",
    ]

    private static let grants = [
        "GRANT WRITE TO \"_creator\"",
        "GRANT CREATE TO \"_icloud\"",
        "GRANT READ TO \"_world\"",
    ]
}
