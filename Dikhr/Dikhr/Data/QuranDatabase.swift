import Foundation
import SQLite3

struct QuranSurah: Identifiable, Hashable {
    var id: Int
    var name: String
    var page: Int
    var ayahCount: Int
    var revelationType: String
}

struct QuranAyah: Identifiable, Hashable {
    var id: Int
    var surahID: Int
    var number: Int
    var text: String
    var page: Int
}

/// Read-only access to the bundled Quran database (SQLite via the system sqlite3).
final class QuranDatabase {
    static let shared = QuranDatabase()

    private var db: OpaquePointer?
    private let queue = DispatchQueue(label: "dev.dikhr.quran")

    private init() {
        guard let url = Bundle.main.url(forResource: "Quran", withExtension: "sqlite") else { return }
        var dbPointer: OpaquePointer?
        let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX
        if sqlite3_open_v2(url.path, &dbPointer, flags, nil) == SQLITE_OK {
            db = dbPointer
        }
    }

    deinit {
        if let db { sqlite3_close_v2(db) }
    }

    private func run<T>(_ body: (OpaquePointer) throws -> T) -> T? {
        guard let db else { return nil }
        return queue.sync {
            try? body(db)
        }
    }

    // MARK: - Queries

    func surahs() -> [QuranSurah] {
        run { db in
            var list: [QuranSurah] = []
            let sql = "SELECT id, name, page, count, type FROM surah ORDER BY id"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return list }
            defer { sqlite3_finalize(stmt) }
            while sqlite3_step(stmt) == SQLITE_ROW {
                list.append(QuranSurah(
                    id: Int(sqlite3_column_int64(stmt, 0)),
                    name: String(cString: sqlite3_column_text(stmt, 1)),
                    page: Int(sqlite3_column_int64(stmt, 2)),
                    ayahCount: Int(sqlite3_column_int64(stmt, 3)),
                    revelationType: String(cString: sqlite3_column_text(stmt, 4))))
            }
            return list
        } ?? []
    }

    func ayahs(surahID: Int) -> [QuranAyah] {
        run { db in
            var list: [QuranAyah] = []
            let sql = "SELECT id, surah_id, number, text, page FROM ayah WHERE surah_id = ? ORDER BY number"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return list }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_int64(stmt, 1, Int64(surahID))
            while sqlite3_step(stmt) == SQLITE_ROW {
                list.append(QuranAyah(
                    id: Int(sqlite3_column_int64(stmt, 0)),
                    surahID: Int(sqlite3_column_int64(stmt, 1)),
                    number: Int(sqlite3_column_int64(stmt, 2)),
                    text: String(cString: sqlite3_column_text(stmt, 3)),
                    page: Int(sqlite3_column_int64(stmt, 4))))
            }
            return list
        } ?? []
    }

    func search(_ query: String, limit: Int = 50) -> [QuranAyah] {
        run { db in
            var list: [QuranAyah] = []
            let sql = """
                SELECT id, surah_id, number, text, page
                FROM ayah WHERE search_text LIKE '%' || ? || '%'
                LIMIT ?
                """
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return list }
            defer { sqlite3_finalize(stmt) }
            let utf8 = query.cString(using: .utf8) ?? []
            sqlite3_bind_text(stmt, 1, utf8, -1, nil)
            sqlite3_bind_int64(stmt, 2, Int64(limit))
            while sqlite3_step(stmt) == SQLITE_ROW {
                list.append(QuranAyah(
                    id: Int(sqlite3_column_int64(stmt, 0)),
                    surahID: Int(sqlite3_column_int64(stmt, 1)),
                    number: Int(sqlite3_column_int64(stmt, 2)),
                    text: String(cString: sqlite3_column_text(stmt, 3)),
                    page: Int(sqlite3_column_int64(stmt, 4))))
            }
            return list
        } ?? []
    }

    func ayahIDs(surahID: Int, number: Int) -> (id: Int, page: Int)? {
        run { db in
            let sql = "SELECT id, page FROM ayah WHERE surah_id = ? AND number = ?"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_int64(stmt, 1, Int64(surahID))
            sqlite3_bind_int64(stmt, 2, Int64(number))
            if sqlite3_step(stmt) == SQLITE_ROW {
                return (Int(sqlite3_column_int64(stmt, 0)), Int(sqlite3_column_int64(stmt, 1)))
            }
            return nil
        } ?? nil
    }

    func surah(_ id: Int) -> QuranSurah? {
        surahs().first(where: { $0.id == id })
    }
}