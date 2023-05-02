// TableViewProxy.swift

import UIKit

public protocol TableViewProxyProtocol:
    ReloadDelegateProxyProtocol,
    UITableViewDelegate,
    UITableViewDataSource
where
    Subject == UITableView
{
    @MainActor
    func performUpdates(_ block: @MainActor @escaping () -> Void) async throws
}

extension TableViewProxyProtocol {
    public func reload(completion: ((Bool) -> Void)? = nil) {
        Task { @MainActor in
            let result = await reload()
            completion?(result)
        }
    }
}

public protocol UITableViewReloadDelegate: AnyObject {
    /// Check wheather reload  the row at specified `IndexPath` after the batch updates
    func tableView(
        _ tableView: UITableView,
        shouldReloadRowAfterAnimationAt indexPath: IndexPath) -> Bool
}

class TaskScheduler<Output> {
    private var currentTask : Task<Output, Never>?

    /// Please be aware that this method is not reentrant.
    @discardableResult func dispatch(block: @escaping () async -> Output) -> Task<Output, Never> {
        let oldTask = currentTask
        let newTask = Task {
            _ = await oldTask?.value
            return await block()
        }
        
        currentTask = newTask
        return newTask
    }
    
    func cancel() {
        currentTask?.cancel()
    }
}

@MainActor
class TableViewReloadScheduler: TaskScheduler<Bool> {
    /// Please be aware that this method is not reentrant.
    @discardableResult override func dispatch(block: @escaping () async -> Bool) -> Task<Bool, Never> {
        super.dispatch { @MainActor in
            return await block()
        }
    }
}


/// An object that organizes works of `UITableViewDelegate` and `UITableViewDataSource`
///
/// You can set the `delegate` property to proxy unimplemented methods to a specified object
/// which makes the `TableViewProxy` able to focus on its own concern.
open class TableViewProxy<Provider: SectionDataSource>:
    ReloadDelegateProxy<UITableViewDelegate & UITableViewDataSource, UITableView>,
    DataSubscriber,
    UITableViewReloadDelegate,
    TableViewProxyProtocol
where Provider.Sections: ExpressibleByArrayLiteral
{
    public typealias Row = Provider.Section.Row
    public typealias Data = Provider.Section.Data
    
    public typealias CellConfigurator = (UITableView,
                                         IndexPath,
                                         Row?) -> UITableViewCell
    /// The data provider that notify the proxy to update its data source.
    /// Please be noticed that `provider.sections` might return different content against `dataSource`
    public let provider: Provider
    
    /// Indicate whether to perform animations on reload or not
    public var animated: Bool = true
    
    /// Is the table view in the reordering session (started by reorder control)
    public private(set) var isReordering: Bool = false
    
    /// Indicates whether the table view is able to present reorder control or not
    ///
    /// Please be noticed that if you have planned to suppport drag and drop, this flag should be set to `false`
    public var reorderEnabled: Bool = false
    
    /// The two-dimentional collection that is currently presented in table view
    public var dataSource: Provider.Sections {
        animator.snapshot ?? []
    }
    
    @MainActor
    /// Scheduler for dispatching `UITableView.reload` calls
    internal let reloadScheduler = TableViewReloadScheduler()
    /// Scheduler for processing refresh data notifioncations squentially
    internal let refreshScheduler = TaskScheduler<Void>()
    
    public let animator: TableViewAnimator<Provider.Sections>
    
    public var cellHeight: CGFloat = 44.0
    
    public var headerHeight: CGFloat = .leastNormalMagnitude
    
    public var footerHeight: CGFloat = .leastNormalMagnitude
    
    private var cellConfigurator: CellConfigurator

    /// This should return nil all the time
    public required init?(context: Any) {
        return nil
    }
    
    public init(
        provider: Provider,
        tableView: UITableView,
        cellConfigurator: @escaping CellConfigurator)
    {
        self.cellConfigurator = cellConfigurator
        self.provider = provider
        self.animator = TableViewAnimator(
            tableView: tableView, snapshot: nil)

        super.init()

        self.subject = tableView
        
        animator.reloadDelegate = self
        tableView.delegate = self
        tableView.dataSource = self
        
        if let provider = provider as? DataPublisher {
            provider.receiveModification(subscriber: self)
        }
    }
    
    /// Update the data source from the provider and reload the table view. All reload calls will be executed sequentially
    @MainActor
    @discardableResult
    public func reload() async -> Bool {
        /// Capture current animation config
        let animated = self.animated
        let animator = self.animator
        let task = reloadScheduler.dispatch {
            guard Task.isCancelled == false else { return false }
            return await withCheckedContinuation { continuation in
                self.willReload()
                /// Apply changes
                animator.applyCurrentChanges(
                    animated: animated, sections: self.provider.sections)
                { [weak self] in
                    self?.isReordering = false
                    self?.didReload()
                    continuation.resume(with: .success($0))
                }
            }
        }
        return await task.value
    }

    @MainActor
    public func performUpdates(_ block: @MainActor @escaping () -> Void) async throws {
        let task = reloadScheduler.dispatch { @MainActor [weak self] in
            guard Task.isCancelled == false,
                  let subject = self?.subject else { return false }
            return await withCheckedContinuation { continuation in
                subject.performBatchUpdates {
                    block()
                } completion: {
                    continuation.resume(with: .success($0))
                }
            }
        }
        let result = await task.value
        guard result == false else { return }
        throw CancellationError()
    }
    
    open func tableView(
        _ tableView: UITableView,
        shouldReloadRowAfterAnimationAt indexPath: IndexPath) -> Bool
    {
        true
    }
    
    // MARK: UITableViewDelegate & UITableViewDataSource
    
    open func tableView(
        _ tableView: UITableView,
        canMoveRowAt indexPath: IndexPath
    ) -> Bool {
        reorderEnabled
    }
    
    open func tableView(
        _ tableView: UITableView,
        moveRowAt sourceIndexPath: IndexPath,
        to destinationIndexPath: IndexPath)
    {
        /// If the table view supports reordering (legacy reorder API) then marks `isReordering` true.
        isReordering = true
    }
    
    open func tableView(
        _ tableView: UITableView,
        heightForHeaderInSection section: Int
    ) -> CGFloat {
        headerHeight
    }
    
    open func tableView(
        _ tableView: UITableView,
        heightForRowAt indexPath: IndexPath
    ) -> CGFloat {
        cellHeight
    }
    
    open func tableView(
        _ tableView: UITableView,
        heightForFooterInSection section: Int
    ) -> CGFloat {
        footerHeight
    }
    
    open func numberOfSections(in tableView: UITableView) -> Int {
        dataSource.count
    }
    
    open func tableView(
        _ tableView: UITableView,
        numberOfRowsInSection section: Int
    ) -> Int {
        guard dataSource.isEmpty == false else { return 0 }
        return dataSource[safe: section]?.count ?? 0
    }
    
    open func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        cellConfigurator(tableView, indexPath, dataSource[safe: indexPath])
    }
    
    // MARK: DataSubscriber

    open func dataSourceDidRefresh<D>(_ dataSource: D, hasChanged: Bool)
    where
        D : SectionDataSource
    {
        if isReordering {
            /// Legacy reordering API infers that developers should handle the underlying data changes without reloading table view
            /// So updating the data snapshot is all we need here.
            reloadScheduler.cancel()
            animator.updateSnapshot(provider.sections)
            isReordering = false
        } else {
            refreshScheduler.dispatch {
                await self.reload()
            }
        }
    }
}
