// ReloadInterceptor.swift

import Foundation

public protocol ReloadInterceptorProtocol: ReloadDelegateProxyProtocol {
    associatedtype Proxy: ReloadDelegateProxyProtocol
    var proxy: Proxy! { get }
}

open /* abstract */ class ReloadInterceptor<Proxy: ReloadDelegateProxyProtocol>:
    ReloadDelegateProxy<Proxy.Delegate, Proxy.Subject>,
    ReloadInterceptorProtocol
{
    open override weak var subject: Subject? {
        willSet {
            newValue?.perform(delegateSetSelector, with: self)
            newValue?.perform(dataSourceSetSelector, with: self)
        }
    }

    public typealias Provider = Proxy.Provider
    
    /// Collect observations returned from `proxy.observeSubjectDidChange`
    public var proxySubjectObservations: [Proxy.Observation] = []
    
    /// Collect observations returned from ``
    public var proxyWillReloadObservations: [Proxy.Observation] = []
    
    /// Collect observations returned from ``
    public var proxyDidReloadObservations: [Proxy.Observation] = []

    public var provider: Proxy.Provider { proxy.provider }

    public var proxy: Proxy! {
        willSet {
            proxySubjectObservations = []
            proxyWillReloadObservations = []
            proxyDidReloadObservations = []
        }
        didSet { setupProxy() }
    }

    public var dataSource: Proxy.Provider.Sections {
        proxy.dataSource
    }

    public required init?(context: Any) {
        proxy = Proxy.init(context: context)
        super.init()
        setupProxy()
    }

    public override init() {
        proxy = Proxy.init(context: ())
        super.init()
        setupProxy()
    }

    public required init(wrappedValue proxy: Proxy) {
        self.proxy = proxy
        super.init()
        setupProxy()
    }

    internal func setupProxy() {
        guard let proxy = proxy else { return }
        delegate = proxy as? Proxy.Delegate
        subject = proxy.subject
        didUpdateProxy()
    }

    open func didUpdateProxy() {
        proxySubjectObservations.append(
            proxy.observeSubjectDidUpdate { [unowned self] in
                subject = $0
            }
        )
        proxyDidReloadObservations.append(
            proxy.observeSubjectWillReload { [unowned self] _ in
                Task { @MainActor in willReload() }
            }
        )
        proxyDidReloadObservations.append(
            proxy.observeSubjectDidReload { [unowned self] _ in
                Task { @MainActor in didReload() }
            }
        )
    }

    @MainActor
    @discardableResult
    open func reload() async -> Bool {
        await proxy.reload()
    }
}
