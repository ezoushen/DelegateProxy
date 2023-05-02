// DelegateProxy.swift

import UIKit

public protocol DelegateProxyProtocol: NSObjectProtocol {
    associatedtype Delegate: NSObjectProtocol
    associatedtype Subject: NSObject
    associatedtype Observation

    var subject: Subject? { get }
    
    func observeSubjectDidUpdate(_ block: @escaping (Subject) -> Void) -> Observation
    func cleanSubjectObservations()
}

open class DelegateProxy<Delegate, Subject>:
    NSObject,
    DelegateProxyProtocol
where Delegate: NSObjectProtocol, Subject: NSObject {

    public class Observation {

        var cancelled: Bool = false

        let block: (Subject) -> Void

        init(block: @escaping (Subject) -> Void) {
            self.block = block
        }

        func notify(with subject: Subject) {
            guard cancelled == false else { return }
            block(subject)
        }

        public func cancel() {
            cancelled = true
        }

        deinit { cancel() }
    }
    
    @inlinable open var delegateGetSelector: Selector {
        NSSelectorFromString("delegate")
    }
    
    @inlinable open var delegateSetSelector: Selector {
        NSSelectorFromString("setDelegate:")
    }

    open weak var delegate: Delegate? {
        didSet {
            guard subject?.responds(to: delegateGetSelector) == true,
                  subject?.responds(to: delegateSetSelector) == true else { return }
            let oldDelegate = subject?.perform(delegateGetSelector).takeUnretainedValue()
            subject?.perform(delegateSetSelector, with: nil)
            subject?.perform(delegateSetSelector, with: oldDelegate)
        }
    }
    
    open weak var subject: Subject? {
        didSet {
            guard let subject = subject else { return }
            subjectObservations.allObjects.forEach { $0.notify(with: subject) }
        }
    }

    private var subjectObservations = NSHashTable<Observation>.weakObjects()

    /// Observe subject change notifications, you must manage returned `Observation`object since the observation is cancelled once the object released
    public func observeSubjectDidUpdate(_ block: @escaping (Subject) -> Void) -> Observation {
        let observation = Observation(block: block)
        subjectObservations.add(observation)
        return observation
    }

    /// Remove all registered observations
    public func cleanSubjectObservations() {
        subjectObservations.removeAllObjects()
    }

    public override func isProxy() -> Bool {
        true
    }
    
    public override func responds(to aSelector: Selector!) -> Bool {
        super.responds(to: aSelector) || delegate?.responds(to: aSelector) == true
    }
    
    public override func forwardingTarget(for aSelector: Selector!) -> Any? {
        delegate
    }
}

public protocol ReloadDelegateProxyProtocol: DelegateProxyProtocol {
    associatedtype Provider: SectionDataSource
    var provider: Provider { get }
    var dataSource: Provider.Sections { get }
    
    init?(context: Any)

    @MainActor
    @discardableResult
    func reload() async -> Bool
    
    @MainActor func willReload()
    @MainActor func didReload()
    
    /// Observe subject didReload notifications, you must manage returned `Observation`object since the observation is cancelled once the object released
    func observeSubjectDidReload(_ block: @escaping (Subject) -> Void) -> Observation
    /// Observe subject willReload notifications, you must manage returned `Observation`object since the observation is cancelled once the object released
    func observeSubjectWillReload(_ block: @escaping (Subject) -> Void) -> Observation
}

open class ReloadDelegateProxy<Delegate, Subject>:
    DelegateProxy<Delegate, Subject>
where Delegate: NSObjectProtocol, Subject: NSObject {
    
    private var willReloadObservations = NSHashTable<Observation>.weakObjects()
    private var didReloadObservations = NSHashTable<Observation>.weakObjects()
    
    @inlinable open var dataSourceGetSelector: Selector {
        NSSelectorFromString("dataSource")
    }
    
    @inlinable open var dataSourceSetSelector: Selector {
        NSSelectorFromString("setDataSource:")
    }
    
    @MainActor
    open func willReload() {
        guard let subject = subject else { return }
        willReloadObservations.allObjects.forEach { $0.notify(with: subject) }
    }
    
    @MainActor
    open func didReload() {
        guard let subject = subject else { return }
        didReloadObservations.allObjects.forEach { $0.notify(with: subject) }
    }
    
    public func observeSubjectDidReload(_ block: @escaping (Subject) -> Void) -> Observation {
        let observation = Observation(block: block)
        didReloadObservations.add(observation)
        return observation
    }
    
    public func observeSubjectWillReload(_ block: @escaping (Subject) -> Void) -> Observation {
        let observation = Observation(block: block)
        willReloadObservations.add(observation)
        return observation
    }
}
