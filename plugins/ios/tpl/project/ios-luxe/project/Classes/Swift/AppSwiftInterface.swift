//
//  AppSwiftInterface.swift
//
//  Created by ceramic.
//  Copyright © 2018 My Company. All rights reserved.
//

import UIKit

/** Swift interface */
@objcMembers public class AppSwiftInterface: NSObject {
    
    /** Get shared instance */
    public static let sharedInterface = AppSwiftInterface()
    
    /** If provided, will be called when root view controller is visible on screen */
    public var viewDidAppear: ((_ animated: Bool) -> Void)?
    
    /** Define a last name for hello() */
    public var lastName: String?
    
    /** Say hello to `name` with a native iOS dialog. Add a last name if any is known. */
    public func hello(_ name: String, done: (() -> Void)?) -> Void {
        
        var sentence = "Hello \(name)"
        
        if let lastName = self.lastName {
            sentence = "\(sentence) \(lastName)"
        }
        
        let alert = UIAlertController(title: "Native iOS (Swift)", message: sentence, preferredStyle: UIAlertControllerStyle.alert)
        
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: { (action: UIAlertAction) in
            // Pressed OK
            if done != nil {
                done!()
            }
        }))
        
        if let viewController = UIApplication.shared.keyWindow?.rootViewController {
            viewController.present(alert, animated: true, completion: nil)
        }
        
    }
    
    /** Get iOS version string */
    public func iosVersionString() -> String {
        
        return UIDevice.current.systemVersion
        
    }
    
    /** Get iOS version number */
    public func iosVersionNumber() -> Float {
        
        let result = Float(UIDevice.current.systemVersion)
        if result != nil {
            return result!
        }
        
        return 0
        
    }
    
    /** Dummy method to get Haxe types converted to Swift types that then get returned back as an array. */
    public func testTypes(_ aBool: Bool, anInt: Int, aFloat: Float, anArray: Array<Any>, aDict: Dictionary<String,Any>) -> Array<Any> {
        
        print("Swift types:");
        print("  Bool: \(aBool)");
        print("  Int: \(anInt)");
        print("  Float: \(aFloat)");
        print("  Array: \(anArray)");
        print("  Dict: \(aDict)");
        
        return [aBool,
                anInt,
                aFloat,
                anArray,
                aDict];
        
    }
    
}

