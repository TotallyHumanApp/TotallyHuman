import Foundation
import SQLite3

// SQLITE_TRANSIENT_DESTRUCTOR ist ein C-Makro und in Swift nicht direkt verfügbar.
private let SQLITE_TRANSIENT_DESTRUCTOR = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

/// SQLite-basierte Datenbank für Trainingsproben.
final class TrainingDatabase {
    private let dbURL: URL
    private var db: OpaquePointer?
    private let queue = DispatchQueue(label: "TotallyHuman.TrainingDatabase")

    init(fileManager: FileManager = .default) throws {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? fileManager.temporaryDirectory
        let folder = base.appendingPathComponent("Totally Human", isDirectory: true)
            .appendingPathComponent("Database", isDirectory: true)
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        dbURL = folder.appendingPathComponent("training.sqlite3")
        try openDatabase()
        try createSchema()
    }

    deinit { sqlite3_close(db) }

    func insert(_ probe: TrainingsProbe) throws {
        try queue.sync {
            let sql = """
            INSERT OR REPLACE INTO trainings_proben (id, dateiPfad, dateiName, label, merkmalsvektor, dateiSignatur, hinzugefuegtAm)
            VALUES (?, ?, ?, ?, ?, ?, ?);
            """
            try execute(sql: sql) { statement in
                try bind(probe.id.uuidString, to: statement, at: 1)
                try bind(probe.dateiPfad, to: statement, at: 2)
                try bind(probe.dateiName, to: statement, at: 3)
                try bind(probe.label.rawValue, to: statement, at: 4)
                try bind(try JSONEncoder.german.encode(probe.merkmalsvektor), to: statement, at: 5)
                try bind(probe.dateiSignatur, to: statement, at: 6)
                try bind(probe.hinzugefuegtAm, to: statement, at: 7)
            }
        }
    }

    func fetchAll() throws -> [TrainingsProbe] {
        try queue.sync {
            let sql = "SELECT id, dateiPfad, dateiName, label, merkmalsvektor, dateiSignatur, hinzugefuegtAm FROM trainings_proben ORDER BY hinzugefuegtAm DESC;"
            return try query(sql: sql) { statement in
                var items: [TrainingsProbe] = []
                while sqlite3_step(statement) == SQLITE_ROW {
                    items.append(try readProbe(from: statement))
                }
                return items
            }
        }
    }

    func delete(id: UUID) throws {
        try queue.sync {
            try execute(sql: "DELETE FROM trainings_proben WHERE id = ?;") { statement in
                try bind(id.uuidString, to: statement, at: 1)
            }
        }
    }

    func clear() throws {
        try queue.sync { try execute(sql: "DELETE FROM trainings_proben;") { _ in } }
    }

    // MARK: - Intern

    private func openDatabase() throws {
        if sqlite3_open(dbURL.path, &db) != SQLITE_OK {
            throw dbError(message: Loc.s("Die Trainingsdatenbank konnte nicht geöffnet werden.",
                                         "The training database could not be opened."))
        }
    }

    private func createSchema() throws {
        try execute(sql: """
        CREATE TABLE IF NOT EXISTS trainings_proben (
            id TEXT PRIMARY KEY,
            dateiPfad TEXT NOT NULL,
            dateiName TEXT NOT NULL,
            label INTEGER NOT NULL,
            merkmalsvektor BLOB NOT NULL,
            dateiSignatur TEXT NOT NULL UNIQUE,
            hinzugefuegtAm REAL NOT NULL
        );
        """) { _ in }
    }

    private func execute(sql: String, bindBlock: (OpaquePointer?) throws -> Void = { _ in }) throws {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw dbError(message: String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(statement) }
        try bindBlock(statement)
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw dbError(message: String(cString: sqlite3_errmsg(db)))
        }
    }

    private func query<T>(sql: String, block: (OpaquePointer?) throws -> T) throws -> T {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw dbError(message: String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(statement) }
        return try block(statement)
    }

    private func bind(_ value: String, to statement: OpaquePointer?, at index: Int32) throws {
        guard sqlite3_bind_text(statement, index, value, -1, SQLITE_TRANSIENT_DESTRUCTOR) == SQLITE_OK else { throw dbError(message: "Bind-Fehler") }
    }

    private func bind(_ value: Int, to statement: OpaquePointer?, at index: Int32) throws {
        guard sqlite3_bind_int(statement, index, Int32(value)) == SQLITE_OK else { throw dbError(message: "Bind-Fehler") }
    }

    private func bind(_ value: Date, to statement: OpaquePointer?, at index: Int32) throws {
        guard sqlite3_bind_double(statement, index, value.timeIntervalSince1970) == SQLITE_OK else { throw dbError(message: "Bind-Fehler") }
    }

    private func bind(_ value: Data, to statement: OpaquePointer?, at index: Int32) throws {
        guard sqlite3_bind_blob(statement, index, (value as NSData).bytes, Int32(value.count), SQLITE_TRANSIENT_DESTRUCTOR) == SQLITE_OK else { throw dbError(message: "Bind-Fehler") }
    }

    private func readProbe(from statement: OpaquePointer?) throws -> TrainingsProbe {
        guard
            let idString = sqlite3_column_text(statement, 0).flatMap({ String(cString: $0) }),
            let id = UUID(uuidString: idString),
            let path = sqlite3_column_text(statement, 1).flatMap({ String(cString: $0) }),
            let name = sqlite3_column_text(statement, 2).flatMap({ String(cString: $0) }),
            let labelRaw = Int(exactly: sqlite3_column_int(statement, 3)),
            let label = TrainingsProbe.TrainingsLabel(rawValue: labelRaw),
            let hash = sqlite3_column_text(statement, 5).flatMap({ String(cString: $0) })
        else { throw dbError(message: Loc.s("Ungültige Trainingsdaten", "Invalid training data")) }

        let blobSize = Int(sqlite3_column_bytes(statement, 4))
        let blob: Data
        if let blobBytes = sqlite3_column_blob(statement, 4), blobSize > 0 {
            blob = Data(bytes: blobBytes, count: blobSize)
        } else {
            blob = Data()
        }
        let features = try JSONDecoder.german.decode([Double].self, from: blob)
        let timestamp = Date(timeIntervalSince1970: sqlite3_column_double(statement, 6))

        return TrainingsProbe(id: id, dateiPfad: path, dateiName: name, label: label, merkmalsvektor: features, dateiSignatur: hash, hinzugefuegtAm: timestamp)
    }

    private func dbError(message: String) -> NSError {
        NSError(domain: "TotallyHuman.TrainingDatabase", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
}

private extension JSONEncoder {
    static var german: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private extension JSONDecoder {
    static var german: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
