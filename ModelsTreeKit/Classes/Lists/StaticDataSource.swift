//
// Created by aleksey on 05.11.15.
// Copyright (c) 2015 aleksey chernish. All rights reserved.
//

import Foundation

public class StaticObjectsSection<U>: CustomStringConvertible {
  
  public private(set) var title: String?
  public var objects: [U]
  
  public init(title: String?, objects: [U]) {
    self.title = title
    self.objects = objects
  }
  
  public var description: String {
    return String(describing: StaticObjectsSection.self) + ", title: \(title)" + ", objects: \(objects)"
  }
  
  public func copy() -> StaticObjectsSection<U> {
    return StaticObjectsSection(title: title, objects: objects)
  }
  
}

public class StaticDataSource<ObjectType> : ObjectsDataSource<ObjectType> where ObjectType: Equatable, ObjectType: Hashable {
  
  public override init() { }
  
  public var sections: [StaticObjectsSection<ObjectType>] = [] {
    didSet { reloadDataSignal.sendNext() }
  }
  
  override func numberOfSections() -> Int {
    return sections.count
  }
  
  override public func numberOfObjectsInSection(_ section: Int) -> Int {
    return sections[section].objects.count
  }
  
  override public func objectAtIndexPath(_ indexPath: IndexPath) -> ObjectType? {
    return sections[indexPath.section].objects[indexPath.row]
  }
  
  public func indexPath(forObject object: ObjectType) -> IndexPath {
    var objectRow = 0
    var objectSection = 0
    
    for (index, section) in sections.enumerated() {
      if section.objects.contains(object) {
        objectSection = index
        objectRow = section.objects.index(of: object)!
      }
    }
    
    return IndexPath(row: objectRow, section: objectSection)
  }
  
  override public func titleForSection(atIndex sectionIndex: Int) -> String? {
    return sections[sectionIndex].title
  }
  
}
