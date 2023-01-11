// TableViewDataSource.swift

import Foundation

public protocol SectionDataSource: AnyObject {
    associatedtype Section: SectionDataProtocol
    
    associatedtype Sections: RandomAccessCollection & ExpressibleByArrayLiteral = [Section]
    where Sections.Element == Section, Sections.Index == Int
    
    var sections: Sections { get }
    
    func sectionIndexOf(data: Section.Data) -> Int?
    func refresh()
}

public protocol MutableSectionDataSource: SectionDataSource {
    var sections: Sections { get set }
}

extension SectionDataSource where Sections.Index == Int {
    public func sectionIndexOf(data: Section.Data) -> Int? {
        guard let pair = sections
                .enumerated().first(where: { $1.data == data })
        else { return nil }
        
        return pair.offset
    }

    public subscript(safe indexPath: IndexPath) -> Section.Row? {
        sections[safe: indexPath]
    }
}
