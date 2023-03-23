// CollectionViewProxy.swift

import UIKit

public protocol CollectionViewProxyProtocol<Provider>:
    ReloadDelegateProxyProtocol,
    DataSubscriber,
    UICollectionViewDelegate,
    UICollectionViewDataSource,
    UICollectionViewDelegateFlowLayout
where
    Subject == UICollectionView
{ }

open class CollectionViewProxy<Provider: SectionDataSource>:
    ReloadDelegateProxy<
        UICollectionViewDelegate & UICollectionViewDataSource & UICollectionViewDelegateFlowLayout,
        UICollectionView
    >,
    CollectionViewProxyProtocol
{

    public typealias Row = Provider.Section.Row
    public typealias Data = Provider.Section.Data

    public typealias CellConfigurator = (UICollectionView,
                                         IndexPath,
                                         Row?) -> UICollectionViewCell
    /// The data provider that notify the proxy to update its data source.
    /// Please be noticed that `provider.sections` might return different content against `dataSource`
    public let provider: Provider

    /// Is the collection view in the reordering session (started by reorder control)
    public private(set) var isReordering: Bool = false

    /// Indicates whether the collection view is able to present reorder control or not
    ///
    /// Please be noticed that if you have planned to suppport drag and drop, this flag should be set to `false`
    public var reorderEnabled: Bool = false

    /// The two-dimentional collection that is currently presented in collection view
    public private(set) var dataSource: Provider.Sections = []

    /// Scheduler for processing refresh data notifioncations squentially
    internal let refreshScheduler = TaskScheduler<Void>()

    private var cellConfigurator: CellConfigurator

    /// This should return nil all the time
    public required init?(context: Any) {
        return nil
    }

    public init(
        provider: Provider,
        collectionView: UICollectionView,
        cellConfigurator: @escaping CellConfigurator)
    {
        self.cellConfigurator = cellConfigurator
        self.provider = provider
        self.dataSource = provider.sections

        super.init()

        self.subject = collectionView
        
        collectionView.delegate = self
        collectionView.dataSource = self

        if let provider = provider as? DataPublisher {
            provider.receiveModification(subscriber: self)
        }
    }

    /// Update the data source from the provider and reload the collection view. All reload calls will be executed sequentially
    public func reload(completion: (() -> Void)?) {
        Task { @MainActor in
            _reload()
            completion?()
        }
    }
    
    @MainActor
    @discardableResult
    public func reload() -> Bool {
        _reload()
        return true
    }

    @MainActor
    private func _reload() {
        willReload()
        subject?.reloadData()
        didReload()
    }

    // MARK: UICollectionViewDelegate & UICollectionViewDataSource

    open func collectionView(
        _ collectionView: UICollectionView,
        canMoveItemAt indexPath: IndexPath) -> Bool
    {
        reorderEnabled
    }

    open func collectionView(
        _ collectionView: UICollectionView,
        moveItemAt sourceIndexPath: IndexPath,
        to destinationIndexPath: IndexPath)
    {
        /// If the collection view supports reordering (legacy reorder API) then marks `isReordering` true.
        isReordering = true
    }

    open func numberOfSections(in collectionView: UICollectionView) -> Int {
        dataSource.count
    }

    open func collectionView(
        _ collectionView: UICollectionView,
        numberOfItemsInSection section: Int) -> Int
    {
        guard dataSource.isEmpty == false else { return 0 }
        return dataSource[safe: section]?.count ?? 0
    }

    open func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        cellConfigurator(collectionView, indexPath, dataSource[safe: indexPath])
    }

    // MARK: DataSubscriber

    open func dataSourceWillChange<D>(_ dataSource: D, newValue: D.Sections)
    where
        D : SectionDataSource
    {

    }

    open func dataSourceDidRefresh<D>(_ dataSource: D, hasChanged: Bool)
    where
        D : SectionDataSource
    {
        guard let provider = dataSource as? Provider else { return }
        refreshScheduler.dispatch {
            self.dataSource = provider.sections
            self._reload()
        }
    }
}
