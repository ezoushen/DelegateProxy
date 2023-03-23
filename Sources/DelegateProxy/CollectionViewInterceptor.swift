// CollectionViewInterceptor.swift

import UIKit

public protocol CollectionViewInterceptorProtocol<Proxy>: ReloadInterceptorProtocol, CollectionViewProxyProtocol
where Proxy: CollectionViewProxyProtocol { }

/// An object that intercepts interested methods and controls the calling stack.
///
/// It's an abstract class that you should always override and provide your own implementations to interested
/// delegate methods. Please notice that if any of your methods is not declared here (your implementation is not declared with
/// `override`), you should provide the objc method name for it. Otherwise, your method could not be found or triggered
/// in runtime since all delegate methods of `UIKit` components are based on objc message sending mechanism.
///
///     class CustomInterceptor<Proxy: TableViewProxyProtocol>: CollectionViewInterceptor<Proxy> {
///          @objc(collectionView:willDisplayCell:forItemAtIndexPath:)
///          func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
///              // Custom implementation
///          }
///     }
///
/// It is recommended that declaring the interceptor as a property wrapper, and it is also capable of building nested property wrappers.
/// That means you can encapsulate any shared feature as an interceptor and compose whatever interceptors together if you want.
///
///     @ReorderableCollectionViewInterceptor
///     @BlueBackgroundCollectionViewInterceptor
///     var basiceCollectionViewProxy: CollectionViewProxy<BasicDataSource>
///
/// The outer interceptor would be the final delegate and dataSource of the tableView, which means it controls the calling stack of all
/// delegate methods.
open class CollectionViewInterceptor<Proxy: CollectionViewProxyProtocol>:
    ReloadInterceptor<Proxy>,
    CollectionViewInterceptorProtocol
{
    public typealias Provider = Proxy.Provider

    // MARK: UICollectionViewDelegate & UICollectionViewDataSource

    open func collectionView(
        _ collectionView: UICollectionView,
        numberOfItemsInSection section: Int) -> Int
    {
        proxy.collectionView(collectionView, numberOfItemsInSection: section)
    }

    open func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        proxy.collectionView(collectionView, cellForItemAt: indexPath)
    }
}
