import GRDB

/// Schema of `core.db`, the store for configuration and user-curated entities
/// (MOS-DM-001 §4.1). Migrations are append-only: never edit a shipped one.
public enum CoreSchema {
    public static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1-foundations") { db in
            try db.create(table: "setting") { table in
                table.primaryKey("key", .text)
                table.column("value_json", .text).notNull()
                table.column("updated_at", .integer).notNull()
            }
            try db.create(table: "device") { table in
                table.primaryKey("id", .blob)
                table.column("name", .text).notNull()
                table.column("model", .text).notNull()
                table.column("os_version", .text).notNull()
                table.column("first_seen_at", .integer).notNull()
            }
            // Local change feed for user-curated entities, the basis for future
            // multi-Mac sync (§57). The sequence number never leaves this database.
            try db.create(table: "change_log") { table in
                table.autoIncrementedPrimaryKey("seq")
                table.column("entity", .text).notNull()
                table.column("entity_id", .blob).notNull()
                table.column("op", .text).notNull().check(sql: "op IN ('insert', 'update', 'delete')")
                table.column("at", .integer).notNull()
                table.column("device_id", .blob).notNull()
            }
        }
        return migrator
    }
}
