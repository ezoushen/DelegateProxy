# DelegateProxy

`DelegateProxy` is a lightweight Swift framework that enables developers to intercept and control 
delegate method calls in UIKit components. It is designed to be used in combination with the UIKit 
components, such as `UITableView` and `UICollectionView`, where delegate methods can be used to customize their behavior.

## Introduction

DelegateProxy works by creating a proxy object that sits between the original object and its delegate. 
The proxy object implements the same delegate protocol as the original object's delegate, 
and forwards the delegate method calls to the original delegate object.
 By intercepting these method calls, the proxy object can customize or control the behavior of the original object.

The `DelegateProxy` class provided in this package is an abstract class that you can extend to 
create your own proxy objects. To create a proxy object, you need to:

1. Subclass `DelegateProxy` and implement the delegate methods you want to intercept.
2. Set the proxy object as the delegate of the original object.
3. Implement the same delegate methods in the original delegate object, but call them on the proxy object instead.


This allows the proxy object to intercept and modify the method calls before 
they are passed on to the original delegate object.

## SectionDataSource

### `SectionDataSource` 

`SectionDataSource` is a protocol that represents a data source for a table view that is comprised 
of sections. This protocol is a class protocol, which means that it can only be adopted by classes, 
and not by value types. `SectionDataSource` is a flexible protocol because it is parameterized by 
the type `Section`, which conforms to `SectionDataProtocol`. This allows the data for a section to 
be any type that conforms to `SectionDataProtocol`.

### `MutableSectionDataSource` 

A protocol that extends `SectionDataSource` and provides write access to the sections.


### `SectionDataProtocol`

`SectionDataProtocol` is a protocol that defines the data for a section in a table view, including
its header data and its rows. The header data is of type `Data`, while the rows are of type `Row`. 
The protocol requires that `Data` and `Row` both conform to the `Hashable` and `ContentHashable` protocols, respectively. 
`RandomAccessCollection` is used to declare that SectionDataProtocol is a collection of Row elements, 
with `Index` being `Int`. This allows for random access to Row elements through index values.
 
 ```swift
struct MySectionData: SectionDataProtocol {
    var data: String
    var rows: [Int]
}

let mySectionData = MySectionData(data: "Section 1", rows: [1, 2, 3])

print(mySectionData.data) // Output: "Section 1"
print(mySectionData[0]) // Output: 1
```
 
### `SectionData`

`SectionData` is a struct that conforms to `SectionDataProtocol` and provides an implementation 
for the protocol. It defines the data property, which represents the data for the header of the 
section, and the rows property, which represents the rows for the section. `SectionData` conforms to 
`MutableSectionDataProtocol` because it provides a mutable implementation of the rows property.

## TableViewProxy

`TableViewProxy` is a concrete implementation of `DelegateProxy` designed specifically for `UITableView`. 
It provides a simple way to customize the behavior of a `UITableView` by intercepting and controlling 
its delegate and data source methods.

## TableViewProxyInterceptor

`TableViewProxyInterceptor` is another concrete implementation of `DelegateProxy` that allows you 
to create custom interceptors for `UITableView` methods. By creating a subclass of `TableViewProxyInterceptor` 
and implementing the methods you want to intercept, you can easily customize the behavior of a `UITableView`
 without having to implement a full `TableViewProxy` subclass.
 
Here's an example of a custom interceptor for a `UITableView`:

 ```swift
class CustomInterceptor<Proxy: TableViewProxyProtocol>: TableViewInterceptor<Proxy> {
    @objc(tableView:willDisplayCell:forRowAtIndexPath:)
    public func tableView( _ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        // Custom implementation
    }
}
```

You can then use this custom interceptor as a property wrapper and compose it with other 
interceptors to create your final delegate and `dataSource` for the `tableView`:

```swift
@ReorderableTableViewInterceptor
@BlueBackgroundTableViewInterceptor
var basicTableViewProxy: TableViewProxy<BasicDataSource>
```

# Conclusion

`DelegateProxy` is a powerful tool for customizing the behavior of `UIKit` components such as `UITableView`
and `UICollectionView`. By intercepting and controlling delegate method calls, you can easily create
custom behaviors and features without having to implement a full subclass. `TableViewProxy` and 
`TableViewProxyInterceptor` provide a convenient way to customize `UITableView` behavior, and 
`SectionDataSource` provides a simple way to organize and manage data in the table view.



