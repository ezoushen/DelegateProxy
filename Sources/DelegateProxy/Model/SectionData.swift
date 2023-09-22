// SectionData.swift

import Foundation

public protocol ContentHashable: Hashable {
    var contentHashValue: Int { get }
}

extension ContentHashable {
    public var contentHashValue: Int {
        hashValue
    }
}

public protocol SectionDataProtocol<Data, Rows>:
    RandomAccessCollection,
    ContentHashable
where Index == Int {
    associatedtype Data: Hashable
    associatedtype Row: ContentHashable & Equatable
    associatedtype Rows: RandomAccessCollection = [Row]
    where Rows.Element == Row, Rows.Index == Int, Rows.Element == Element
    
    var data: Data { get }
    var rows: Rows { get }
}

extension SectionDataProtocol {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.data == rhs.data
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(data)
    }
}

extension SectionDataProtocol {
    public var startIndex: Int {
        rows.startIndex
    }
    
    public var endIndex: Int {
        rows.endIndex
    }
    
    public subscript(_ index: Int) -> Row {
        _read {
            yield rows[index]
        }
    }
}

public protocol MutableSectionDataProtocol: SectionDataProtocol {
    var rows: Rows { get set }
}

extension MutableSectionDataProtocol
where Self: MutableCollection, Self.Rows: MutableCollection {
    public subscript(_ index: Int) -> Row {
        _read {
            yield rows[index]
        }
        _modify {
            yield &rows[index]
        }
    }
}

public struct SectionData<Data, Rows>:
    MutableSectionDataProtocol,
    RandomAccessCollection
where
    Data: Hashable,
    Rows: RandomAccessCollection,
    Rows.Element: ContentHashable,
    Rows.Index == Int
{
    public typealias Row = Rows.Element
    
    public let data: Data
    public var rows: Rows
    
    public init(data: Data, rows: Rows) {
        self.data = data
        self.rows = rows
    }
}

extension SectionData: ContentHashable where Row: ContentHashable {
    public var contentHashValue: Int {
        var hasher = Hasher()
        hasher.combine(data)
        for row in rows {
            hasher.combine(row.contentHashValue)
        }
        return hasher.finalize()
    }
}

extension RandomAccessCollection where
    Index == Int,
    Element: RandomAccessCollection,
    Element.Index == Int
{
    public subscript(safe indexPath: IndexPath) -> Element.Element? {
        guard indexPath.section < count,
              indexPath.row < self[indexPath.section].count,
              indexPath.section >= 0,
              indexPath.row >= 0 else { return nil }
        return self[indexPath.section][indexPath.row]
    }
}

extension RandomAccessCollection where
    Index == Int,
    Element: RandomAccessCollection & MutableCollection,
    Element.Index == Int
{
    public subscript(safe indexPath: IndexPath) -> Element.Element? {
        guard indexPath.section < count,
              indexPath.row < self[indexPath.section].count,
              indexPath.section >= 0,
              indexPath.row >= 0 else { return nil }

        return self[indexPath.section][indexPath.row]
    }
}

extension RandomAccessCollection where
    Self: MutableCollection,
    Index == Int,
    Element: RandomAccessCollection & MutableCollection,
    Element.Index == Int
{
    public subscript(safe indexPath: IndexPath) -> Element.Element? {
        get {
            guard indexPath.section < count,
                  indexPath.row < self[indexPath.section].count,
                  indexPath.section >= 0,
                  indexPath.row >= 0 else { return nil }

            return self[indexPath.section][indexPath.row]
        }
        set {
            guard let newValue = newValue,
                  indexPath.section < count,
                  indexPath.row < self[indexPath.section].count,
                  indexPath.section >= 0,
                  indexPath.row >= 0 else { return }

            self[indexPath.section][indexPath.row] = newValue
        }
    }
}

extension RandomAccessCollection where Index == Int {
    public subscript(safe index: Int) -> Element? {
        index >= 0 && index < self.count ? self[index] : nil
    }
}

public func === <
    SectionData: SectionDataProtocol
>(
    lhs: SectionData,
    rhs: SectionData) -> Bool
{
    guard lhs.data == rhs.data else { return false }
    for (ld, rd)
    in zip(lhs.rows, rhs.rows)
    where ld.contentHashValue != rd.contentHashValue {
        return false
    }
    return true
}

public func !== <
    SectionData: SectionDataProtocol
>(
    lhs: SectionData,
    rhs: SectionData) -> Bool
{
    guard lhs.data == rhs.data else { return true }
    for (ld, rd)
    in zip(lhs.rows, rhs.rows)
    where ld.contentHashValue != rd.contentHashValue {
        return true
    }
    return false
}

public func !== <
    Collection: RandomAccessCollection
>(lhs: Collection,rhs: Collection) -> Bool
where Collection.Element: SectionDataProtocol {
    guard lhs.count == rhs.count else { return true }
    
    for (ld, rd) in zip(lhs, rhs) {
        guard ld.contentHashValue != rd.contentHashValue
        else { continue }
        return true
    }
    
    return false
}
