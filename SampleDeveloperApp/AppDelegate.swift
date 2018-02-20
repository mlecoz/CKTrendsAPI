//
//  AppDelegate.swift
//  SampleDeveloperApp
//
//  Created by Marissa Le Coz on 9/23/17.
//  Copyright © 2017 Marissa Le Coz. All rights reserved.
//

import UIKit
import CloudKit
import UserNotifications
import Firebase
import FirebaseDatabase
import FirebaseAuth

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    var window: UIWindow?
    
    let db = CKContainer(identifier: "iCloud.com.MarissaLeCozz.SampleDeveloperApp").publicCloudDatabase
    
    var firebaseDBRef: DatabaseReference?
    
    var recordTypeToRecordListDict = [String:[CKRecord]]()

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        
        FirebaseApp.configure()
        firebaseDBRef = Database.database().reference()
        
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }

    // This function is called when another app on the device opens the URL for this app.
    func application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey : Any] = [:]) -> Bool {
        
        // which app opened you
        guard let sendingAppID = options[.sourceApplication] as? String else {
            return false
        }
        
        if sendingAppID == "com.MarissaLeCoz.AnalyticsApp" {
            logIn()
        }
        
        return true
    }
    
    func configureLoginAlert() -> UIAlertController {

        let popUp = UIAlertController(title: "CKTrends Login", message: "Please use your CKTrends username and password to log in and refresh your trend tracking!", preferredStyle: UIAlertControllerStyle.alert)
        popUp.addTextField() { emailField in
            emailField.placeholder = "email"
        }
        popUp.addTextField() { passwordField in
            passwordField.placeholder = "password"
            passwordField.isSecureTextEntry = true
        }
        
        popUp.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.default, handler: nil))
        popUp.addAction(UIAlertAction(title: "Login", style: UIAlertActionStyle.default) { alert in
            
            guard let email = popUp.textFields![0].text, let password = popUp.textFields![1].text else {
                return
            }
            
            Auth.auth().signIn(withEmail: email, password: password) { (user, error) in
                if (error != nil) {
                    self.presentErrorAlert(message: "Sign in failed. Please check your email and password. Tap the Refresh button in CKTrends to try again.")
                }
                else {
                    guard let uid = user?.uid else {
                        return
                    }
                    self.updateCKTrends(uid: uid)
                }
            }
        })
        return popUp
    }
    
    func logIn() {
        
        let popUp = self.configureLoginAlert()
        self.window?.rootViewController?.present(popUp, animated: true, completion: nil)
    }

    func updateCKTrends(uid: String) {
        
        let appID = "1"
        let recordTypesToTrack = ["Blah1", "Users", "Blah", "RecordTypeA", "RecordTypeB"] // add B later
        let listsToTrack = ["ListType", "list", "AListTypeThatDoesntExist", "list"]
        
        var recordTypesDict = [String:String]()
        for type in recordTypesToTrack {
            recordTypesDict[type] = "true"
        }
        for i in stride(from: 0, through: listsToTrack.count-1, by: 2) {
            recordTypesDict["\(listsToTrack[i])~\(listsToTrack[i+1])"] = "true" // represent lists to track as RecordType~listName (tildes aren't allowed in CloudKit RecordType names, so there shouldn't be a conflict; tildes are allowed in Firebase, which is necessary)
        }
        
        // "set" overrides everything in that path, which is what we want, like if the user decided to stop tracking a record type
        Database.database().reference().child("users").child("\(uid)").child("\(appID)").child("TRACKING").setValue(recordTypesDict, withCompletionBlock: { (error, ref) in
            
            if error == nil {
        
                for recordType in recordTypesToTrack {
            
                    // check to see whether the user has checked this record type before; if not, add it to tracking list
                    let pathString = "users/\(uid)/\(appID)/LAST_CHECK"
                    Database.database().reference().child(pathString).observeSingleEvent(of: .value) { snapshot, error in
                
                        if error == nil {
                            
                            let recordTypeToLastCheckDict = snapshot.value as? [String:Any]? // record type : last check date
                    
                            var isNewRecordType = false // default
                            if recordTypeToLastCheckDict == nil || recordTypeToLastCheckDict!?[recordType] == nil {
                                isNewRecordType = true
                            }

                            // if this is a new record type, query all records of this type
                            if isNewRecordType {
                                let predicate = NSPredicate(value: true)
                                let query = CKQuery(recordType: recordType, predicate: predicate)
                                let sort = NSSortDescriptor(key: "creationDate", ascending: true) // so the 0th result is the earliest
                                query.sortDescriptors = [sort]
                                let operation1 = CKQueryOperation(query: query)
                                operation1.resultsLimit = 5
                                operation1.queryCompletionBlock = { (cursor, error) in
                                    if error != nil {
                                        self.recordTypeErrorHandling(error: error as! CKError, uid: uid, appID: appID, recordType: recordType)
                                    }
                                    else {
                                        self.queryRecordsWithCursor(cursor: cursor, isFirstCheck: true, uid: uid, appID: appID, recordType: recordType)
                                    }
                                }

                                CKContainer.default().publicCloudDatabase.add(operation1)
                            }
                                
                            // if this isn't a new record type, query all record since the last time this type was tracked
                            // edge case: include that day itself. (Suppose that the user checked midday, and now they check again later in the
                            // day. To avoid overriding the count from earlier in the day, we need query for all records created on that day.)
                            else {
                            
                                guard let lastCheckAsStr = recordTypeToLastCheckDict!?[recordType] as? String else {
                                    return
                                }
                                // get all records from the day of the last check and after
                                let predicate = NSPredicate(format: "%K >= %@", "creationDate", self.dateFromString(stringDate: lastCheckAsStr)!)
                                let query = CKQuery(recordType: recordType, predicate: predicate)
                                let operation2 = CKQueryOperation(query: query)
                                operation2.resultsLimit = 5
                                operation2.queryCompletionBlock = { (cursor, error) in
                                    if error != nil {
                                        self.recordTypeErrorHandling(error: error as! CKError, uid: uid, appID: appID, recordType: recordType)
                                    }
                                    else {
                                        self.queryRecordsWithCursor(cursor: cursor, isFirstCheck: false, uid: uid, appID: appID, recordType: recordType)
                                    }
                                }
                                CKContainer.default().publicCloudDatabase.add(operation2)
                            }
                        }
                        else {
                            self.presentErrorAlert(message: "CKTrends refresh failed. Go back to the CKTrends app and tap Refresh to try again.")
                        }
                    }
                }
                
                // go through lists to track [recordType, list, recordType, list...]
                for i in stride(from: 0, through: listsToTrack.count-1, by: 2) {
                            
                    let predicate = NSPredicate(value: true)
                    let query = CKQuery(recordType: listsToTrack[i], predicate: predicate) // ith element is the record that has the list to track
                    self.db.perform(query, inZoneWith: nil) { records, error in // only care about 0th, so no need to use a cursor
                        if error == nil {
                            guard let records = records, records.count > 0 else {
                                return
                            }
                            self.saveListCount(record: records[0], uid: uid, appID: appID, recordType: listsToTrack[i], listName: listsToTrack[i+1], isFirstCheck: true)
                        }
                        else {
                            self.recordTypeErrorHandling(error: error as! CKError, uid: uid, appID: appID, recordType: "\(listsToTrack[i])~\(listsToTrack[i+1])")
                        }
                    }
                }
            }
            else {
                self.presentErrorAlert(message: "CKTrends refresh failed. Go back to the CKTrends app and tap Refresh to try again.")
            }
        })
    }
    
    func saveRecordCounts(records: [CKRecord], uid: String, appID: String, recordType: String, isFirstCheck: Bool) {
        
        let dateToCountDict = dateToCountDictionary(records: records)
        
        // if it's the first time checking, record the earliest date
        if isFirstCheck {
            guard records.count > 0, let date = records[0].creationDate else { return }
            let dateStr = stringFromDate(date: date)
            Database.database().reference().child("users").child("\(uid)").child("\(appID)").child("EARLIEST_DATE").updateChildValues([recordType: dateStr], withCompletionBlock: { (error, ref) in
                if error != nil {
                    self.presentErrorAlert(message: "CKTrends refresh failed. Go back to the CKTrends app and tap Refresh to try again.")
                }
            })
        }

        // No new records, then just update the last check time
        if dateToCountDict.count == 0 {
            Database.database().reference().child("users").child("\(uid)").child("\(appID)").child("LAST_CHECK").updateChildValues([recordType: self.formattedDateForToday()], withCompletionBlock: { (error, ref) in
                if error != nil {
                    self.presentErrorAlert(message: "CKTrends refresh failed. Go back to the CKTrends app and tap Refresh to try again.")
                }
            })
        }
        
        // get previous max count, if it exists
        let appID = "1"
        let pathString = "users/\(uid)/\(appID)/MAX_COUNT"
        Database.database().reference().child(pathString).observeSingleEvent(of: .value) { snapshot, error in
            
            if error == nil {
                
                let recordTypeToMaxCountDict = snapshot.value as? [String:Any]?
                
                // set the current max count (or else initialize to -Inf)
                var maxCount: Double
                // this path doesn't exist yet
                if recordTypeToMaxCountDict == nil || recordTypeToMaxCountDict!?[recordType] == nil {
                    maxCount = -Double.infinity
                }
                else {
                    guard let count = Double(recordTypeToMaxCountDict!?[recordType] as! String) else { return }
                    maxCount = count
                }
                
                // add new record counts to firebase and keep track of the max count as we go
                for (date, count) in dateToCountDict {
                    if Double(count) > maxCount {
                        maxCount = Double(count)
                    }
                    Database.database().reference().child("users").child("\(uid)").child("\(appID)").child("\(date)").updateChildValues([recordType: "\(count)"], withCompletionBlock: { (error, ref) in
                        if error == nil {
                            // record LAST_CHECK
                            Database.database().reference().child("users").child("\(uid)").child("\(appID)").child("LAST_CHECK").updateChildValues([recordType: self.formattedDateForToday()], withCompletionBlock : { (error2, ref) in
                                if error2 != nil {
                                    self.presentErrorAlert(message: "CKTrends refresh failed. Go back to the CKTrends app and tap Refresh to try again.")
                                }
                                else {
                                    if self.recordTypeToRecordListDict[recordType] != nil {
                                        self.recordTypeToRecordListDict[recordType]?.removeAll()
                                    }
                                }
                            })
                        }
                        else {
                            self.presentErrorAlert(message: "CKTrends refresh failed. Go back to the CKTrends app and tap Refresh to try again.")
                        }
                    })
                }
                
                // Save the max count
                Database.database().reference().child("users").child("\(uid)").child("\(appID)").child("MAX_COUNT").updateChildValues([recordType: String(maxCount)], withCompletionBlock: { (error, ref) in
                    if error != nil {
                        self.presentErrorAlert(message: "CKTrends refresh failed. Go back to the CKTrends app and tap Refresh to try again.")
                    }
                })
                
            }
            else {
                self.presentErrorAlert(message: "CKTrends refresh failed. Go back to the CKTrends app and tap Refresh to try again.")
            }
        }
    }
    
    func saveListCount(record: CKRecord, uid: String, appID: String, recordType: String, listName: String, isFirstCheck: Bool) {
        
        var count: Int?
        
        // either that list field doesn't exist or else it's never been added to before, so it's nil
        if record.object(forKey: listName) == nil {
            // don't track this
            let pathString = "users/\(uid)/\(appID)/TRACKING/\("\(recordType)~\(listName)")"
            // shouldn't be tracking this
            Database.database().reference().child(pathString).removeValue(completionBlock: { (error, ref) in
                if error != nil {
                    self.presentErrorAlert(message: "CKTrends refresh failed. Go back to the CKTrends app and tap Refresh to try again.")
                }
            })
            count = 0 // to appease the system
        }
        // get current total
        else {
            let list = record.object(forKey: listName) as! NSArray
            count = list.count
        }
        
        // get previous total, if it exists
        let appID = "1"
        let pathString = "users/\(uid)/\(appID)/TOTALS"
        Database.database().reference().child(pathString).observeSingleEvent(of: .value) { [count] snapshot, error in
            
            if error == nil {
                
                let recordTypeToTotalsDict = snapshot.value as? [String:Any]?
                var oldCount: Int
                
                // this path doesn't exist yet
                if recordTypeToTotalsDict == nil || recordTypeToTotalsDict!?["\(recordType)~\(listName)"] == nil {
                    oldCount = 0
                }
                else {
                    guard let oldListCount = Int(recordTypeToTotalsDict!?["\(recordType)~\(listName)"] as! String) else { return }
                    oldCount = oldListCount
                }
                
                // update total
                Database.database().reference().child("users").child("\(uid)").child("\(appID)").child("TOTALS").updateChildValues(["\(recordType)~\(listName)": "\(count!)"], withCompletionBlock: { (error, ref) in
                    if error == nil {
                        // record LAST_CHECK
                        Database.database().reference().child("users").child("\(uid)").child("\(appID)").child("LAST_CHECK").updateChildValues(["\(recordType)~\(listName)": self.formattedDateForToday()], withCompletionBlock : { (error2, ref) in
                            if error2 == nil {
                                // save the delta from the last time
                                Database.database().reference().child("users").child("\(uid)").child("\(appID)").child("DELTAS").updateChildValues(["\(recordType)~\(listName)": count! - oldCount], withCompletionBlock : { (error3, ref) in
                                    if error3 != nil {
                                        self.presentErrorAlert(message: "CKTrends refresh failed. Go back to the CKTrends app and tap Refresh to try again.")
                                    }
                                })
                            }
                            else {
                                self.presentErrorAlert(message: "CKTrends refresh failed. Go back to the CKTrends app and tap Refresh to try again.")
                            }
                        })
                    }
                    else {
                        self.presentErrorAlert(message: "CKTrends refresh failed. Go back to the CKTrends app and tap Refresh to try again.")
                    }
                })
            }
            else {
                self.presentErrorAlert(message: "CKTrends refresh failed. Go back to the CKTrends app and tap Refresh to try again.")
            }
        }
    }
    
    func dateToCountDictionary(records: [CKRecord]) -> [String:Int] {
        
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
    
    func formattedDateForToday() -> String {
        let date = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm:ss"
        return formatter.string(from: date)
    }
    
    func stringFromDate(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter.string(from: date)
    }
    
    func dateFromString(stringDate: String) -> NSDate? {
        
        let cal = Calendar(identifier: .gregorian)
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy/MM/dd HH:mm:ss"
        dateFormatter.timeZone = TimeZone.current
        var date = dateFormatter.date(from: stringDate)
        
        // set to the beginning of the day
        var components = cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date!)
        components.hour = 0
        components.minute = 0
        components.second = 0
        
        date = cal.date(from: components)!
        
        return date as NSDate?
    }
    
    func presentErrorAlert(message: String) {
        guard let vc = self.window?.rootViewController else {
            return
        }
        CKTrendsUtilities.presentAlert(title: "Uh Oh!", message: message, vc: vc)
    }
    
    // adapted from: https://gist.github.com/evermeer/5df7ad1f8db529893f40
    func queryRecordsWithCursor(cursor: CKQueryCursor?, isFirstCheck: Bool, uid: String, appID: String, recordType: String) {
        
        guard let theCursor = cursor else { return }
        let operation = CKQueryOperation(cursor: theCursor)
        
        // happens each time a record is received
        operation.recordFetchedBlock = { [recordType] record in
            if self.recordTypeToRecordListDict[recordType] == nil {
                self.recordTypeToRecordListDict[recordType] = [record]
            }
            else {
                self.recordTypeToRecordListDict[recordType]?.append(record)
            }
        }
        // happens when all records are done
        operation.queryCompletionBlock = { [recordType] cursor, error in
            if error == nil {
                if cursor == nil { // cursor is nil => we've gotten all records, so save them
                    self.saveRecordCounts(records: self.recordTypeToRecordListDict[recordType]!, uid: uid, appID: appID, recordType: recordType, isFirstCheck: isFirstCheck) // use isFirstCheck, not the value in the dictionary
                }
                else if self.recordTypeToRecordListDict[recordType] != nil {
                    self.queryRecordsWithCursor(cursor: cursor, isFirstCheck: isFirstCheck, uid: uid, appID: appID, recordType: recordType) // recursive call. if we've gotten here, there's definitely a non-nil cursor
                }
            }
            else {
                self.recordTypeErrorHandling(error: error as! CKError, uid: uid, appID: appID, recordType: recordType)
            }
        }
        CKContainer.default().publicCloudDatabase.add(operation)
    }
    
    func recordTypeErrorHandling(error: CKError, uid: String, appID: String, recordType: String) {
        // 10 - system defined record type
        // 11 - record type not found
        if error.errorCode == 10 || error.errorCode == 11 {
            let pathString = "users/\(uid)/\(appID)/TRACKING/\(recordType)"
            // shoudn't be tracking this
            Database.database().reference().child(pathString).removeValue(completionBlock: { (error, ref) in
                if error != nil {
                    self.presentErrorAlert(message: "CKTrends refresh failed. One of the record types you desire to track does not exist, or you are trying to track a system record type, like User.")
                }
            })
        }
        else if error.errorCode == 12 {
            self.presentErrorAlert(message: "CKTrends refresh failed. Make sure that the Record Types you wish to track have a queryable recordName and a queryable & sortable createdAt. (See API documentation for help.)")
        }
        else {
            self.presentErrorAlert(message: "CKTrends refresh failed. Go back to the CKTrends app and tap Refresh to try again.")
        }
    }
}

