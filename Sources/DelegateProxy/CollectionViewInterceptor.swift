// CollectionViewInterceptor.swift

import UIKit

public protocol CollectionViewInterceptorProtocol<Proxy>: CollectionViewProxyProtocol {
    associatedtype Proxy: CollectionViewProxyProtocol
    var proxy: Proxy! { get }
}

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
