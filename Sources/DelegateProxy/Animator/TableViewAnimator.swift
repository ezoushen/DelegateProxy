// TableViewAnimator.swift

import UIKit

public struct SectionAnimationInstruction<Collection>: Hashable
where
    Collection: RandomAccessCollection & ExpressibleByArrayLiteral,
    Collection.Element: SectionDataProtocol
{
    public static func == (
        lhs: SectionAnimationInstruction<Collection>,
        rhs: SectionAnimationInstruction<Collection>) -> Bool
    {
        lhs.hashValue == rhs.hashValue
    }

    public struct Moving<Index: Hashable>: Hashable, CustomStringConvertible {
        public let from: Index
        public let to: Index
        
        public var description: String {
            "Moving(from: \(from), to: \(to))"
        }
    }

    public let snapshot: Collection

    public let deleteSections: IndexSet
    public let insertSections: IndexSet

    public let movingSections: Set<Moving<Int>>
    
    public let deleteIndexPaths: [IndexPath]
    public let insertIndexPaths: [IndexPath]

    public let movingIndexPaths: Set<Moving<IndexPath>>

    public func hash(into hasher: inout Hasher) {
        for section in snapshot {
            hasher.combine(section.contentHashValue)
        }
        hasher.combine(deleteSections)
        hasher.combine(insertSections)
        hasher.combine(movingSections)
        hasher.combine(deleteIndexPaths)
        hasher.combine(insertIndexPaths)
        hasher.combine(movingIndexPaths)
    }
}

extension SectionAnimationInstruction: Swift.CustomStringConvertible {
    public var description: String {
        """
        SectionAnimationInstruction
        {
            Section deleted: \(Array(deleteSections)) ;
            Section inserted: \(Array(insertSections)) ;
            Section moved: \(movingSections) ;
            IndexPath deleted: \(deleteIndexPaths) ;
            IndexPath inserted: \(insertIndexPaths) ;
            IndexPath moved: \(movingIndexPaths) ;
        }

        """
    }
}

extension SectionAnimationInstruction {
    public var affectedSections: IndexSet {
        deleteSections
            .union(insertSections)
            .union(IndexSet(deleteIndexPaths.map{ $0.section }))
            .union(IndexSet(insertIndexPaths.map { $0.section }))
    }
    
    public var isEmpty: Bool {
        deleteSections.isEmpty && insertSections.isEmpty && deleteIndexPaths.isEmpty && insertIndexPaths.isEmpty
    }
}

public struct TableViewRowAnimation {
    public var rowDelete: UITableView.RowAnimation
    
    public var sectionDelete: UITableView.RowAnimation
    
    public var rowInsert: UITableView.RowAnimation
    
    public var sectionInsert: UITableView.RowAnimation
}

extension TableViewRowAnimation {
    public init(_ animation: UITableView.RowAnimation) {
        self.init(rowDelete: animation, sectionDelete: animation, rowInsert: animation, sectionInsert: animation)
    }
    
    public init(section: UITableView.RowAnimation, row: UITableView.RowAnimation) {
        self.init(rowDelete: row, sectionDelete: section, rowInsert: row, sectionInsert: section)
    }
    
    public init(insert: UITableView.RowAnimation, delete: UITableView.RowAnimation) {
        self.init(rowDelete: delete, sectionDelete: delete, rowInsert: insert, sectionInsert: insert)
    }

    public init(
        rowInsert: UITableView.RowAnimation,
        rowDelete: UITableView.RowAnimation,
        sectionInsert: UITableView.RowAnimation,
        sectionDelete: UITableView.RowAnimation)
    {
        self.init(rowDelete: rowDelete, sectionDelete: sectionDelete, rowInsert: rowInsert, sectionInsert: sectionInsert)
    }
}

extension UITableView.RowAnimation: Swift.CustomStringConvertible {
    public var description: String {
        switch self {
        case .fade:
            return "fade"
        case .right:
            return "right"
        case .left:
            return "left"
        case .top:
            return "top"
        case .bottom:
            return "bottom"
        case .none:
            return "none"
        case .middle:
            return "middle"
        case .automatic:
            return "automatic"
        @unknown default:
            return "unknown"
        }
    }
}

public final class TableViewAnimator<Collection>
where
    Collection: RandomAccessCollection & ExpressibleByArrayLiteral,
    Collection.Element: SectionDataProtocol
{
#if DEBUG
    public var logEnabled: Bool = true
#endif
    private(set) public var snapshot: Collection? = nil

    private(set) public var instructions: SectionAnimationInstruction<Collection>?
    
    public weak var tableView: UITableView?
    
    public weak var reloadDelegate: UITableViewReloadDelegate?
    
    public var animation = TableViewRowAnimation(.top)

    public var animationDuration: CFTimeInterval?

    public var shouldInferMovings: Bool = false

    /// Generally, it'll compute the diff between two snapshot in ascending order.
    /// By setting this option to `true`, it'll become descending order. Default value is `false`.
    /// For example, the diff of [a, b] -> [b, a] will be considered as deleting a and then inserting a behind b for `true`,
    /// and considered as deleting b and inserting b in front of a for `false`.
    public var reverseDeleteInsertion: Bool = false
    
    public var hasPendingChanges: Bool {
        instructions != nil
    }
    
    init(tableView: UITableView, snapshot: Collection? = nil) {
        self.snapshot = snapshot
        self.tableView = tableView
    }
    
    /// Clear pending changes and update the snapshot
    func updateSnapshot(_ snapshot: Collection) {
        instructions = nil
        self.snapshot = snapshot
    }

    /// Apply pending changes with or without animations.
    /// Snapshot will already be updated while completion handler called
    func applyCurrentChanges(
        animated: Bool,
        sections: Collection,
        completion: @escaping (Bool) -> Void)
    {
        let reloadCompletion: (Bool) -> Void = {
            self.reloadVisibleCells()
            completion($0)
        }
        
        guard let instructions = instructions ??
                createAnimationInstruction(sections: sections) else {
            updateSnapshot(sections)
            return reloadCompletion(false)
        }
#if DEBUG
        if logEnabled {
            print(instructions.description)
        }
#endif
        guard snapshot != nil && animated else {
            updateSnapshot(instructions: instructions)
            tableView?.reloadData()
            return completion(true)
        }
        let execution: () -> Void = {
            guard let tableView = self.tableView else { return completion(false) }
            tableView.performBatchUpdates({
                self.applyInstructions(instructions)
                // Snapshot update must be placed after instructions applied
                self.updateSnapshot(instructions: instructions)
            }, completion: reloadCompletion)
        }
        if let interval = animationDuration {
            UIView.animate(withDuration: interval, animations: execution)
        } else {
            execution()
        }
    }
    
    private func reloadVisibleCells() {
        guard let tableView = tableView,
              let indexPaths = tableView.indexPathsForVisibleRows?.filter({
                  reloadDelegate?.tableView(
                    tableView, shouldReloadRowAfterAnimationAt: $0) == true
              }), indexPaths.isEmpty == false
        else { return }
        tableView.reloadRows(at: indexPaths, with: .none)
    }

    private func applyInstructions(_ instructions: SectionAnimationInstruction<Collection>) {
        if instructions.deleteIndexPaths.isEmpty == false {
            tableView?.deleteRows(
                at: instructions.deleteIndexPaths, with: animation.rowDelete)
        }
        if instructions.deleteSections.isEmpty == false {
            tableView?.deleteSections(
                instructions.deleteSections, with: animation.sectionDelete)
        }
        if instructions.movingSections.isEmpty == false {
            instructions.movingSections.forEach {
                tableView?.moveSection($0.from, toSection: $0.to)
            }
        }
        if instructions.insertSections.isEmpty == false {
            tableView?.insertSections(
                instructions.insertSections, with: animation.sectionInsert)
        }
        if instructions.insertIndexPaths.isEmpty == false {
            tableView?.insertRows(
                at: instructions.insertIndexPaths, with: animation.rowInsert)
        }
        if instructions.movingIndexPaths.isEmpty == false {
            instructions.movingIndexPaths.forEach {
                tableView?.moveRow(at: $0.from, to: $0.to)
            }
        }
    }
    
    private func updateSnapshot(instructions: SectionAnimationInstruction<Collection>) {
        if self.instructions == instructions {
            self.instructions =  nil
        }
        snapshot = instructions.snapshot
    }
    
    private func createAnimationInstruction(
        sections: Collection) -> SectionAnimationInstruction<Collection>?
    {
        guard snapshot == nil || snapshot! !== sections else { return nil }

        let sectionDataMap = sections.reduce(into: [AnyHashable: Collection.Element]()) {
            $0[$1] = $1
        }

        let snapshot = self.snapshot ?? []
        var sectionDiff = sections.difference(from: snapshot)

        if shouldInferMovings {
            sectionDiff = sectionDiff.inferringMoves()
        }

        let (deleteSections, insertSections, movingSections) =
            calculateSectionAnimation(diff: sectionDiff)

        let modifiedSectionIndexesByIdentifier = sections
            .enumerated()
            .reduce(into: [AnyHashable: Int]()) {
                for row in $1.element.rows {
                    $0[row] = $1.offset
                }
            }
        let originalSectionIndexesByIdentifier = snapshot
            .enumerated()
            .reduce(into: [AnyHashable: Int]()) {
                for row in $1.element.rows {
                    $0[row] = $1.offset
                }
            }
        let rowsDiff = snapshot
            .compactMap { snapshot -> CollectionDifference<Collection.Element.Row>? in
                guard let section = sectionDataMap[snapshot] else { return nil }
                return Array(section.rows).difference(from: Array(snapshot.rows))
            }
        let (deleteIndexPaths, insertIndexPaths, movingIndexPaths) =
            calculateRowAnimations(
                modifiedSectionIndexesByIdentifier: modifiedSectionIndexesByIdentifier,
                originalSectionIndexesByIdentifier: originalSectionIndexesByIdentifier,
                rowsDiff: rowsDiff)

        return SectionAnimationInstruction(
            snapshot: sections,
            deleteSections: deleteSections,
            insertSections: insertSections,
            movingSections: movingSections,
            deleteIndexPaths: deleteIndexPaths,
            insertIndexPaths: insertIndexPaths,
            movingIndexPaths: movingIndexPaths)
    }

    private func calculateSectionAnimation(
        diff: CollectionDifference<Collection.Element>
    ) -> (
        deleteSections: IndexSet,
        insertSections: IndexSet,
        movingSections: Set<SectionAnimationInstruction<Collection>.Moving<Int>>
    ) {
        var deleteSections: IndexSet = IndexSet()
        var insertSections: IndexSet = IndexSet()
        var movingSections: Set<SectionAnimationInstruction<Collection>.Moving<Int>> = .init()

        for change in diff {
            switch change {
            case .insert(let index, _, let association):
                guard let source = association else {
                    insertSections.insert(index)
                    continue
                }
                _ = movingSections.insert(.init(from: source, to: index))

            case .remove(let index, _, let association):
                // Ingore association here because inferred moving
                // will be handled in insertion case
                guard association == nil else { continue }
                deleteSections.insert(index)
            }
        }

        return (deleteSections, insertSections, movingSections)
    }

    private func calculateRowAnimations(
        modifiedSectionIndexesByIdentifier: [AnyHashable: Int],
        originalSectionIndexesByIdentifier: [AnyHashable: Int],
        rowsDiff: [CollectionDifference<Collection.Element.Row>]
    ) ->(
        deleteIndexPaths: [IndexPath],
        insertIndexPaths: [IndexPath],
        movingIndexPaths: Set<SectionAnimationInstruction<Collection>.Moving<IndexPath>>
    ) {
        var deleteIndexPaths: [IndexPath] = []
        var insertIndexPaths: [IndexPath] = []
        var insertionModelKeyedByIndexPath: [IndexPath: AnyHashable] = [:]
        var indexPathKeyedByInsertionModel: [AnyHashable: IndexPath] = [:]
        var deleteModelKeyedByIndexPath: [IndexPath: AnyHashable] = [:]
        var indexPathKeyedByDeleteModel: [AnyHashable: IndexPath] = [:]

        for change in rowsDiff.flatMap({ $0 }) {
            switch change {
            case .insert(let row, let model, _):
                let section = modifiedSectionIndexesByIdentifier[model]!
                let indexPath = IndexPath(row: row, section: section)
                insertIndexPaths.append(indexPath)

                guard shouldInferMovings else { continue }

                insertionModelKeyedByIndexPath[indexPath] = model
                indexPathKeyedByInsertionModel[model] = indexPath

            case .remove(let row, let model, _):
                let section = originalSectionIndexesByIdentifier[model]!
                let indexPath = IndexPath(row: row, section: section)
                deleteIndexPaths.append(indexPath)

                guard shouldInferMovings else { continue }

                deleteModelKeyedByIndexPath[indexPath] = model
                indexPathKeyedByDeleteModel[model] = indexPath
            }
        }

        guard shouldInferMovings else {
            return (
                deleteIndexPaths: reverseDeleteInsertion ? insertIndexPaths : deleteIndexPaths,
                insertIndexPaths: reverseDeleteInsertion ? deleteIndexPaths : insertIndexPaths,
                movingIndexPaths: [])
        }

        var movingIndexPaths: Set<SectionAnimationInstruction<Collection>.Moving<IndexPath>> = []

        let uniqueIndexPathDelete = deleteIndexPaths.filter {
            guard let model = deleteModelKeyedByIndexPath[$0] else { return false }
            guard let insertionIndexPath = indexPathKeyedByInsertionModel[model]
            else { return true }

            _ = reverseDeleteInsertion
                ? movingIndexPaths.insert(.init(from: insertionIndexPath, to: $0))
                : movingIndexPaths.insert(.init(from: $0, to: insertionIndexPath))

            return false
        }

        let uniqueIndexPathInsertion = insertIndexPaths.filter {
            guard let model = insertionModelKeyedByIndexPath[$0] else { return false }
            return indexPathKeyedByDeleteModel[model] == nil
        }

        return (
            deleteIndexPaths: reverseDeleteInsertion ? uniqueIndexPathInsertion : uniqueIndexPathDelete,
            insertIndexPaths: reverseDeleteInsertion ? uniqueIndexPathDelete : uniqueIndexPathInsertion,
            movingIndexPaths: movingIndexPaths)
    }
}
