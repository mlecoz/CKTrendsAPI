//
//  CKTrendsUtilities.swift
//  SampleDeveloperApp
//
//  Created by Marissa Le Coz on 1/18/18.
//  Copyright © 2018 Marissa Le Coz. All rights reserved.
//

import Foundation
import UIKit
import CloudKit

class CKTrendsUtilities {
    
    static func presentAlert(title: String, message: String, vc: UIViewController) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil))
        vc.present(alert, animated: true, completion: nil)
    }
    
    static func dateToCountDictionary(records: [CKRecord]) -> [String:Int] {
        
        var dateToCountDict = [String:Int]()
        
        for record in records {
            if let date = record["creationDate"] as? Date {
                let formatter = DateFormatter()
                formatter.dateFormat = "MM-dd-yy"
                let formattedDate = formatter.string(from: date)
                
                if dateToCountDict[formattedDate] != nil {
                    dateToCountDict[formattedDate] = dateToCountDict[formattedDate]! + 1
                }
                else {
                    dateToCountDict[formattedDate] = 1
                }
            }
        }
        
        return dateToCountDict
    }
    
    static func formattedDateForToday() -> String {
        let date = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm:ss"
        return formatter.string(from: date)
    }
    
    static func stringFromDate(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter.string(from: date)
    }
    
    static func dateFromString(stringDate: String) -> NSDate? {
        
        let cal = Calendar(identifier: .gregorian)
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy/MM/dd HH:mm:ss"
        dateFormatter.timeZone = TimeZone(identifier: "GMT")
        var date = dateFormatter.date(from: stringDate)
        
        // set to the beginning of the day
        var components = cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date!)
        components.hour = 0
        components.minute = 0
        components.second = 0
        
        date = cal.date(from: components)!
        
        return date as NSDate?
    }
    
    static func presentErrorAlert(message: String, vc: UIViewController) {
        CKTrendsUtilities.presentAlert(title: "Uh Oh!", message: message, vc: vc)
    }
    
}
