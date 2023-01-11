// DataPublisher.swift

import Foundation

open class DataPublisher {
    private var _subscribers: NSHashTable<AnyObject> = .weakObjects()

    public var dataSubscribers: [DataSubscriber] {
        _subscribers.allObjects.compactMap { $0 as? DataSubscriber }
    }

    public func receiveModification(subscriber: DataSubscriber) {
        _subscribers.add(subscriber)
    }

    public init() { }
}

open class DataSourcePublisher<Section>:
    DataPublisher,
    MutableSectionDataSource
where
    Section: SectionDataProtocol
{

    func contentHash(for sections: [Section]) -> Int {
        var hasher = Hasher()
        for section in sections {
            hasher.combine(section.contentHashValue)
        }
        return hasher.finalize()
    }
    
    public var sections: [Section] {
        get {
            _sectionData
        }
        set {
            let oldHash = _sectionDataContentHash
            let newHash = contentHash(for: newValue)
            let willChange = oldHash != newHash

            defer {
                _sectionDataContentHash = newHash
                dataSubscribers.forEach {
                    $0.dataSourceDidRefresh(self, hasChanged: willChange)
                }
            }

            guard willChange else { return }

            dataSubscribers.forEach {
                $0.dataSourceWillChange(self, newValue: newValue)
            }

            _sectionData = newValue
        }
    }

    private var _sectionDataContentHash: Int = 0
    private var _sectionData: [Section] = []

    open func refresh() {
        fatalError("please implement your own refresh function")
    }
}
