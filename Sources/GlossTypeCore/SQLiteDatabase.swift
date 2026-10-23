import Foundation
import SQLite3

public enum SQLiteValue: Equatable {
    case text(String)
    case integer(Int64)
    case real(Double)
    case null
}

public struct SQLiteError: Error, CustomStringConvertible {
    public let message: String
    public var description: String { message }
}

/// 查询结果的一行，只在回调里有效。
public struct SQLiteRow {
    fileprivate let statement: OpaquePointer

    public func string(_ column: Int32) -> String? {
        guard let pointer = sqlite3_column_text(statement, column) else { return nil }
        return String(cString: pointer)
    }

    public func int(_ column: Int32) -> Int {
        Int(sqlite3_column_int64(statement, column))
    }

    public func double(_ column: Int32) -> Double {
        sqlite3_column_double(statement, column)
    }

    public func isNull(_ column: Int32) -> Bool {
        sqlite3_column_type(statement, column) == SQLITE_NULL
    }
}

/// SQLite 的薄封装：预编译语句缓存、参数绑定。只在主线程使用。
public final class SQLiteDatabase {
    private static let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    private var handle: OpaquePointer?
    private var statements: [String: OpaquePointer] = [:]

    public init(path: String, readOnly: Bool) throws {
        let flags = readOnly ? SQLITE_OPEN_READONLY : (SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE)
        var pointer: OpaquePointer?
        let status = sqlite3_open_v2(path, &pointer, flags, nil)
        guard status == SQLITE_OK, let pointer else {
            let message = pointer.map { String(cString: sqlite3_errmsg($0)) } ?? "status \(status)"
            if let pointer { sqlite3_close(pointer) }
            throw SQLiteError(message: "打开 \(path) 失败：\(message)")
        }
        handle = pointer
    }

    public static func inMemory() throws -> SQLiteDatabase {
        try SQLiteDatabase(path: ":memory:", readOnly: false)
    }

    deinit {
        for statement in statements.values { sqlite3_finalize(statement) }
        sqlite3_close(handle)
    }

    /// 执行不带参数的一条或多条语句（建表等）。
    public func execute(_ sql: String) throws {
        var error: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(handle, sql, nil, nil, &error) != SQLITE_OK {
            let message = error.map { String(cString: $0) } ?? "未知错误"
            sqlite3_free(error)
            throw SQLiteError(message: message)
        }
    }

    /// 执行一条带参数的写语句。
    public func run(_ sql: String, _ arguments: [SQLiteValue] = []) throws {
        let statement = try prepared(sql, arguments)
        defer { sqlite3_reset(statement) }
        let status = sqlite3_step(statement)
        guard status == SQLITE_DONE || status == SQLITE_ROW else {
            throw SQLiteError(message: lastError)
        }
    }

    /// 执行查询，逐行回调。
    public func query(_ sql: String, _ arguments: [SQLiteValue] = [], row: (SQLiteRow) -> Void) throws {
        let statement = try prepared(sql, arguments)
        defer { sqlite3_reset(statement) }
        while true {
            let status = sqlite3_step(statement)
            if status == SQLITE_ROW {
                row(SQLiteRow(statement: statement))
            } else if status == SQLITE_DONE {
                return
            } else {
                throw SQLiteError(message: lastError)
            }
        }
    }

    /// 读 meta 表（key / value），表不存在时抛错。
    public func metadata() throws -> [String: String] {
        var result: [String: String] = [:]
        try query("SELECT key, value FROM meta") { row in
            if let key = row.string(0) { result[key] = row.string(1) ?? "" }
        }
        return result
    }

    private var lastError: String {
        handle.map { String(cString: sqlite3_errmsg($0)) } ?? "数据库已关闭"
    }

    private func prepared(_ sql: String, _ arguments: [SQLiteValue]) throws -> OpaquePointer {
        let statement: OpaquePointer
        if let cached = statements[sql] {
            statement = cached
            sqlite3_reset(cached)
            sqlite3_clear_bindings(cached)
        } else {
            var pointer: OpaquePointer?
            guard sqlite3_prepare_v2(handle, sql, -1, &pointer, nil) == SQLITE_OK, let pointer else {
                throw SQLiteError(message: "\(lastError)：\(sql)")
            }
            statements[sql] = pointer
            statement = pointer
        }
        for (offset, argument) in arguments.enumerated() {
            let index = Int32(offset + 1)
            switch argument {
            case .text(let value):
                sqlite3_bind_text(statement, index, value, -1, Self.transient)
            case .integer(let value):
                sqlite3_bind_int64(statement, index, value)
            case .real(let value):
                sqlite3_bind_double(statement, index, value)
            case .null:
                sqlite3_bind_null(statement, index)
            }
        }
        return statement
    }
}
