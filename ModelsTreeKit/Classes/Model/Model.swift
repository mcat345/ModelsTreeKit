//
//  Model.swift
//  SessionSwift
//
//  Created by aleksey on 10.10.15.
//  Copyright © 2015 aleksey chernish. All rights reserved.
//

import Foundation

public class Model {
  
  public private(set) weak var parent: Model?
  
  public let pushChildSignal = Pipe<Model>()
  public let wantsRemoveChildSignal = Pipe<Model>()
  public let errorSignal = Pipe<Error>()
  public let pool = AutodisposePool()
  public let deinitSignal = Pipe<Void>()
  
  private let hash = NSProcessInfo.processInfo().globallyUniqueString
  
  deinit {
    representationDeinitDisposable?.dispose()
  }
  
  public init(parent: Model?) {
    self.parent = parent
    parent?.addChild(self)
    deinitSignal.sendNext()
  }
  
  //Connection with representation
  
  private weak var representationDeinitDisposable: Disposable?
  
  public func applyRepresentation(representation: DeinitObservable) {
    representationDeinitDisposable = representation.deinitSignal.subscribeNext { [weak self] _ in
      self?.parent?.removeChild(self!)
    }.autodispose()
  }
  
  //Lifecycle
  
  public func sessionWillClose() {
    childModels().forEach { $0.sessionWillClose() }
  }
  
  //Child models
  
  private lazy var childModelsSet = Set<Model>()
  
  final func childModels() -> Set<Model> {
    return childModelsSet
  }
  
  final func addChild(childModel: Model) {
    childModelsSet.insert(childModel)
  }
  
  final func removeChild(childModel: Model) {
    childModelsSet.remove(childModel)
  }
  
  public func removeFromParent() {
    parent?.removeChild(self)
  }
  
  //Session Helpers
  
  public final func session() -> Session? {
    if let session = parent as? Session { return session }
    else { return parent?.session() }
  }
  
  //Bubble Notifications
  
  //TODO: extensions

  private var registeredBubbles = Set<String>()
  
  public final func registerForBubble<T where T: BubbleNotificationName>(name: T) {
    registeredBubbles.insert(T.domain + "." + name.rawValue)
  }
  
  public final func unregisterFromBubble<T where T: BubbleNotificationName>(name: T) {
    registeredBubbles.remove(T.domain + "." + name.rawValue)
  }
  
  public final func isRegisteredForBubble<T where T: BubbleNotificationName>(name: T) -> Bool {
    return registeredBubbles.contains(T.domain + "." + name.rawValue)
  }
  
  public func raiseBubble<T where T: BubbleNotificationName>(name: T, withObject object: Any? = nil, sender: Model) {
    if isRegisteredForBubble(name) {
      handleBubbleNotification(BubbleNotification(name: name, object: object), sender: sender)
    } else {
      parent?.raiseBubble(name, withObject: object, sender: sender)
    }
  }
  
  public func handleBubbleNotification(bubble: BubbleNotification, sender: Model) {}
  
  //Errors
  
  //TODO: extensions
  private var registeredErrors = [String: Set<Int>]()
  
  public final func registerForError<T where T: ErrorCode>(code: T) {
    var allCodes = registeredErrors[T.domain] ?? []
    allCodes.insert(code.rawValue)
    registeredErrors[T.domain] = allCodes
  }
  
  public final func registerForErrorCodes<T where T: ErrorCode>(codes: [T]) {
    var allCodes = registeredErrors[T.domain] ?? []
    let mappedCodes = codes.map { $0.rawValue }
    mappedCodes.forEach { allCodes.insert($0) }
    registeredErrors[T.domain] = allCodes
  }
  
  public final func unregisterFromError<T where T: ErrorCode>(code code: T) {
    if let codes = registeredErrors[T.domain] {
      var filteredCodes = codes
      filteredCodes.remove(code.rawValue)
      registeredErrors[T.domain] = filteredCodes
    }
  }
  
  public final func isRegisteredForError(error: Error) -> Bool {
    guard let codes = registeredErrors[error.domain] else { return false }
    return codes.contains(error.code.rawValue)
  }
  
  public func raiseError(error: Error) {
    if isRegisteredForError(error) { handleError(error) }
    else { parent?.raiseError(error) }
  }
  
  //Override to achieve custom behavior
  
  public func handleError(error: Error) {
    errorSignal.sendNext(error)
  }
  
  //Global events
  
  private var registeredGlobalEvents = Set<String>()
  
  public final func registerForEvent(name: GlobalEventName) {
    registeredGlobalEvents.insert(name.rawValue)
  }
  
  public final func unregisterFromEvent(name: GlobalEventName) {
    registeredGlobalEvents.remove(name.rawValue)
  }
  
  public final func isRegisteredForEvent(name: GlobalEventName) -> Bool {
    return registeredGlobalEvents.contains(name.rawValue)
  }
  
  public final func raiseGlobalEvent(
    name: GlobalEventName,
    withObject object: Any? = nil,
    userInfo: [String: Any] = [:]) {
    let event = GlobalEvent(name: name, object: object, userInfo: userInfo)
    session()?.propagateGlobalEvent(event)
  }
  
  private func propagateGlobalEvent(event: GlobalEvent) {
    if isRegisteredForEvent(event.name) {
      handleSessionEvent(event)
    }
    childModels().forEach { $0.propagateGlobalEvent(event) }
  }
  
  public func handleSessionEvent(event: GlobalEvent) {}
  
}

extension Model: Hashable, Equatable {
  
  public var hashValue: Int { get { return hash.hash } }
  
}

public func ==(lhs: Model, rhs: Model) -> Bool {
  return lhs.hash == rhs.hash
}

extension Model {
  
  public enum TreeInfoOptions {
    case Representation
    case GlobalEvents
    case BubbleNotifications
    case Errors
    case ErrorsVerbous
  }
  
  public final func printSubtree(params: [TreeInfoOptions] = []) {
    print("\n")
    printTreeLevel(0, params: params)
    print("\n")
  }
  
  public final func printSessionTree(withOptions params: [TreeInfoOptions] = []) {
    session()?.printSubtree(params)
  }
  
  private func printTreeLevel(level: Int, params: [TreeInfoOptions] = []) {
    var output = "|"
    let indent = "  |"
    
    for _ in 0..<level {
      output += indent
    }
    
    output += "\(String(self).componentsSeparatedByString(".").last!)"
    
    if params.contains(.Representation) && representationDeinitDisposable != nil {
      output += "  | (R)"
    }
    
    if params.contains(.GlobalEvents) && !registeredGlobalEvents.isEmpty {
      output += "  | (E):"
      registeredGlobalEvents.forEach { output += " \($0)" }
    }
    
    if params.contains(.BubbleNotifications) && !registeredBubbles.isEmpty {
      output += "  | (B):"
      registeredBubbles.forEach { output += " \($0)" }
    }
    
    if params.contains(.ErrorsVerbous) && !registeredErrors.isEmpty {
      output += "  | (Err): "
      for (domain, codes) in registeredErrors {
        codes.forEach { output += "[\(NSLocalizedString("\(domain).\($0)", comment: ""))] " }
      }
    } else if params.contains(.Errors) && !registeredErrors.isEmpty {
      output += "  | (Err): "
      for (domain, codes) in registeredErrors {
        output += "\(domain) > "
        codes.forEach { output += "\($0) " }
      }
    }

    print(output)
    
    childModels().forEach { $0.printTreeLevel(level + 1, params:  params) }
  }
  
}

extension Model: DeinitObservable { }

class SomeClass {
  func registerForBubble<U where U: BooleanType>(param: U) {
    //    registeredBubbles.insert(domain + "." + name.rawValue)
  }
  
}