// DataSubscriber.swift

import Foundation

public protocol DataSubscriber: AnyObject {
    func dataSourceWillChange<D: SectionDataSource>(_ dataSource: D, newValue: D.Sections)
    func dataSourceDidRefresh<D: SectionDataSource>(_ dataSource: D, hasChanged: Bool)
}

extension DataSubscriber {
    public func dataSourceWillChange<D: SectionDataSource>(_ dataSource: D, newValue: D.Sections) { }
    public func dataSourceDidRefresh<D: SectionDataSource>(_ dataSource: D, hasChanged: Bool) { }
}
