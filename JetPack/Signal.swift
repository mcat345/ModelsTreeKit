//
//  Signal.swift
//  SessionSwift
//
//  Created by aleksey on 14.10.15.
//  Copyright © 2015 aleksey chernish. All rights reserved.
//

import Foundation

precedencegroup Chaining { higherThan: MultiplicationPrecedence }
infix operator >>> : Chaining

public func >>><T> (signal: Signal<T>, handler: @escaping ((T) -> Void)) -> Disposable {
  return signal.subscribeNext(handler)
}

public class Signal<T> {
  
  public var hashValue = ProcessInfo.processInfo.globallyUniqueString.hash
  
  public typealias SignalHandler = (T) -> Void
  public typealias StateHandler = (Bool) -> Void
    
  var nextHandlers = [Invocable]()
  var completedHandlers = [Invocable]()
  
  //Destructor is executed before the signal's deallocation. A good place to cancel your network operation.
  
  var destructor: ((Void) -> Void)?
  
  var pool = AutodisposePool()
    
  deinit {
    destructor?()
    pool.drain()
  }
    
  public func sendNext(_ newValue: T) {
    nextHandlers.forEach { $0.invoke(newValue) }
  }
  
  public func sendCompleted() {
    completedHandlers.forEach { $0.invokeState(true) }
  }
  
  //Adds handler to signal and returns subscription
  
  public func subscribeNext(_ handler: @escaping SignalHandler) -> Disposable {
    let wrapper = Subscription(handler: handler, signal: self)
    nextHandlers.append(wrapper)
    
    return wrapper
  }
  
}

extension Signal: Hashable, Equatable {}

public func ==<T>(lhs: Signal<T>, rhs: Signal<T>) -> Bool {
  return lhs.hashValue == rhs.hashValue
}
