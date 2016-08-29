/*

 ValidatableInterfaceElement.swift
 Validator

 Created by @adamwaite.

 Copyright (c) 2015 Adam Waite. All rights reserved.

 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.

*/

import Foundation
import ObjectiveC

public protocol ValidatableInterfaceElement: AnyObject {
    
    associatedtype InputType: Validatable
    
    var inputValue: InputType? { get }
    
    func validate<R: ValidationRule>(rule r: R) -> ValidationResult where R.InputType == InputType
    
    func validate(rules rs: ValidationRuleSet<InputType>) -> ValidationResult

    func validate() -> ValidationResult
    
    func validateOnInputChange(validationEnabled: Bool)
    
}

private var ValidatableInterfaceElementRulesKey: UInt8 = 0
private var ValidatableInterfaceElementHandlerKey: UInt8 = 0

private final class Box<T>: NSObject {
    let thing: T
    init(thing t: T) { thing = t }
}

extension ValidatableInterfaceElement {

    public typealias ValidationHandler = (ValidationResult, Self) -> ()

    public var validationRules: ValidationRuleSet<InputType>? {
        get {
            return objc_getAssociatedObject(self, &ValidatableInterfaceElementRulesKey) as? ValidationRuleSet<InputType>
        }
        set(newValue) {
            if let n = newValue {
                objc_setAssociatedObject(self, &ValidatableInterfaceElementRulesKey, n, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            }
        }
    }
    
    public var validationHandler: ValidationHandler? {
        get {
            if let boxed = objc_getAssociatedObject(self, &ValidatableInterfaceElementHandlerKey) as! Box<ValidationHandler>? {
                return boxed.thing
            }
            return nil
        }
        set(newValue) {
            if let n = newValue {
                let boxed = Box<ValidationHandler>(thing: n)
                objc_setAssociatedObject(self, &ValidatableInterfaceElementHandlerKey, boxed, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            }
        }
    }
    
    public func validate<R: ValidationRule>(rule r: R) -> ValidationResult where R.InputType == InputType {
        let result = Validator.validate(input: inputValue, rule: r)
        if let h = validationHandler { h(result, self) }
        return result
    }
    
    public func validate(rules rs: ValidationRuleSet<InputType>) -> ValidationResult {
        let result = Validator.validate(input: inputValue, rules: rs)
        if let h = validationHandler {
            // This is the method that is causing a crash.
            // We've received the handler closure as an associated object,
            // but calling it causes exc_bad_access.
            h(result, self)
        }
        return result
    }
    
    public func validate() -> ValidationResult {
        guard let attachedRules = validationRules else { fatalError("Validator Error: attempted to validate without attaching rules") }
        return validate(rules: attachedRules)
    }
    
}
