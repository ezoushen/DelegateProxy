// TableViewInterceptor.swift

import UIKit

public protocol TableViewInterceptorProtocol: ReloadInterceptorProtocol, TableViewProxyProtocol
where Proxy: TableViewProxyProtocol { }

/// An object that intercepts interested methods and controls the calling stack.
///
/// It's an abstract class that you should always override and provide your own implementations to interested
/// delegate methods. Please notice that if any of your methods is not declared here (your implementation is not declared with
/// `override`), you should provide the objc method name for it. Otherwise, your method could not be found or triggered
/// in runtime since all delegate methods of `UIKit` components are based on objc message sending mechanism.
///
///         class CustomInterceptor<Proxy: TableViewProxyProtocol>: TableViewInterceptor<Proxy> {
///              @objc(tableView:willDisplayCell:forRowAtIndexPath:)
///              public func tableView( _ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
///                  // Custom implementation
///              }
///         }
///
/// It is recommended that declaring the interceptor as a property wrapper, and it is also capable of building nested property wrappers.
/// That means you can encapsulate any shared feature as an interceptor and compose whatever interceptors together if you want.
///
///         @ReorderableTableViewInterceptor
///         @BlueBackgroundTableViewInterceptor
///         var basiceTableViewProxy: TableViewProxy<BasicDataSource>
///
/// The outer interceptor would be the final delegate and dataSource of the tableView, which means it controls the calling stack of all
/// delegate methods.
open /* abstract */ class TableViewInterceptor<Proxy: TableViewProxyProtocol>:
    ReloadInterceptor<Proxy>,
    TableViewInterceptorProtocol
{
    @MainActor
    open func performUpdates(_ block: @MainActor @escaping () -> Void) async throws {
        try await proxy.performUpdates(block)
    }

    open func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        proxy.tableView(tableView, numberOfRowsInSection: section)
    }

    open func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        proxy.tableView(tableView, cellForRowAt: indexPath)
    }
}
