// DelegateProxy.swift

import UIKit

public protocol DelegateProxyProtocol: NSObjectProtocol {
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

        func subjectDidUpdate(subject: Subject) {
            block(subject)
        }

        public func cancel() {
            cancelled = true
        }
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
            subjectObservations.allObjects.forEach { $0.subjectDidUpdate(subject: subject) }
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
