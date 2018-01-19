//
//  CKTrendsUtilities.swift
//  SampleDeveloperApp
//
//  Created by Marissa Le Coz on 1/18/18.
//  Copyright © 2018 Marissa Le Coz. All rights reserved.
//

import Foundation
import UIKit

class CKTrendsUtilities {
    
    static func presentAlert(title: String, message: String, vc: UIViewController) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil))
        vc.present(alert, animated: true, completion: nil)
    }
}
