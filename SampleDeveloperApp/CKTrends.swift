//
//  CKTrends.swift
//  SampleDeveloperApp
//
//  Created by Marissa Le Coz on 3/10/18.
//  Copyright © 2018 Marissa Le Coz. All rights reserved.
//

import Foundation
import CloudKit
import FirebaseAuth
import FirebaseDatabase
import FirebaseCore

class CKTrends {
    
    private let firebaseDBRef: DatabaseReference
    private var recordTypeToRecordListDict = [String:[CKRecord]]()
    private var vc: UIViewController?
    private var appID: String
    private var recordTypesToTrack: [String]
    private var listsToTrack: [String]
    
    //    let appID = "1"
    //    let recordTypesToTrack = ["Blah1", "Users", "Blah", "RecordTypeA", "RecordTypeB"] // add B later
    //    let listsToTrack = ["ListType", "list"]
    // nil if none in either of these lists
    init(appID: String, recordTypesToTrack: [String]?, listsToTrack: [String]?) {
        FirebaseApp.configure()
        self.firebaseDBRef = Database.database().reference()
        self.appID = appID
        if recordTypesToTrack != nil {
            self.recordTypesToTrack = recordTypesToTrack!
        }
        else {
            self.recordTypesToTrack = [String]()
        }
        if listsToTrack != nil {
            self.listsToTrack = listsToTrack!
        }
        else {
            self.listsToTrack = [String]()
        }
    }
    
    // to be called in AppDelegate in application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey : Any] = [:]) -> Bool
    // return appWasOpened(...) [will return bool]
    func appWasOpened(options: [UIApplicationOpenURLOptionsKey : Any]) {
        
        // which app opened you
        guard let sendingAppID = options[.sourceApplication] as? String else {
            return
        }
        
        if sendingAppID == "com.MarissaLeCoz.AnalyticsApp" {
            
            // figuring out whether we are in the dev (2) or production (1) cloudkit db
            // from https://stackoverflow.com/questions/32464734/how-can-cloudkit-environment-be-determined-at-runtime
            // CKTrends should only work with Production.
            // This check is, albeit, hacky. If the API stops recording trends, Apple may have changed its environment numbers.
            let container = CKContainer.default()
            let containerID = container.value(forKey: "containerID") as! NSObject // CKContainerID
            let environment = containerID.value(forKey: "environment")! as! Int
            if environment == 1 { // production
                logIn()
            }
            else {
                guard let vc = self.vc else { return }
                CKTrendsUtilities.presentErrorAlert(message: "CKTrends has detected that your app is using its CloudKit development environment. CKTrends only works when your app is using its CloudKit production environment.", vc: vc)
            }
        }
        
    }
    
    private func configureLoginAlert() -> UIAlertController {
        
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
                    guard let vc = self.vc else { return }
                    CKTrendsUtilities.presentErrorAlert(message: "Sign in failed. Please check your email and password. Tap the Refresh button in CKTrends to try again.", vc: vc)
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
    
    private func logIn() {
        
        let popUp = self.configureLoginAlert()
        
        // NovNet hack (because the root vc of window was interpreted to be the Purple View Controller, which was quickly usurped by the
        // World View Controller. hence, the login prompt was hidden.)
        DispatchQueue.global(qos: .background).async {
            sleep(2) // wait for the World View Controller to come into view (after PurpleVC makes its appearance)
            DispatchQueue.main.async {
                if var topController = UIApplication.shared.keyWindow?.rootViewController {
                    while let presentedViewController = topController.presentedViewController {
                        topController = presentedViewController
                    }
                    self.vc = topController
                    topController.present(popUp, animated: true, completion: nil)
                }
                
            }
        }
    }
    
    private func updateCKTrends(uid: String) {
        
        var recordTypesDict = [String:String]()
        for type in self.recordTypesToTrack {
            recordTypesDict[type] = "true"
        }
        for i in stride(from: 0, through: self.listsToTrack.count-1, by: 2) {
            recordTypesDict["\(self.listsToTrack[i])~\(listsToTrack[i+1])"] = "true" // represent lists to track as RecordType~listName (tildes aren't allowed in CloudKit RecordType names, so there shouldn't be a conflict; tildes are allowed in Firebase, which is necessary)
        }
        
        // "set" overrides everything in that path, which is what we want, like if the user decided to stop tracking a record type
        Database.database().reference().child("users").child("\(uid)").child("\(appID)").child("TRACKING").setValue(recordTypesDict, withCompletionBlock: { (error, ref) in
            
            if error == nil {
                
                for recordType in self.recordTypesToTrack {
                    
                    // check to see whether the user has checked this record type before; if not, add it to tracking list
                    let pathString = "users/\(uid)/\(self.appID)/LAST_CHECK"
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
                                operation1.resultsLimit = 100
                                operation1.recordFetchedBlock = { [recordType] record in
                                    if self.recordTypeToRecordListDict[recordType] == nil {
                                        self.recordTypeToRecordListDict[recordType] = [record]
                                    }
                                    else {
                                        self.recordTypeToRecordListDict[recordType]?.append(record)
                                    }
                                }
                                operation1.queryCompletionBlock = { (cursor, error) in
                                    if error != nil {
                                        self.recordTypeErrorHandling(error: error as! CKError, uid: uid, appID: self.appID, recordType: recordType)
                                    }
                                    else {
                                        self.queryRecordsWithCursor(cursor: cursor, isFirstCheck: true, uid: uid, appID: self.appID, recordType: recordType)
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
                                let predicate = NSPredicate(format: "%K >= %@", "creationDate", CKTrendsUtilities.dateFromString(stringDate: lastCheckAsStr)!)
                                let query = CKQuery(recordType: recordType, predicate: predicate)
                                let operation2 = CKQueryOperation(query: query)
                                operation2.resultsLimit = 100
                                operation2.recordFetchedBlock = { [recordType] record in
                                    if self.recordTypeToRecordListDict[recordType] == nil {
                                        self.recordTypeToRecordListDict[recordType] = [record]
                                    }
                                    else {
                                        self.recordTypeToRecordListDict[recordType]?.append(record)
                                    }
                                }
                                operation2.queryCompletionBlock = { (cursor, error) in
                                    if error != nil {
                                        self.recordTypeErrorHandling(error: error as! CKError, uid: uid, appID: self.appID, recordType: recordType)
                                    }
                                    else if cursor == nil {
                                        self.saveRecordCounts(records: self.recordTypeToRecordListDict[recordType]!, uid: uid, appID: self.appID, recordType: recordType, isFirstCheck: false)
                                    }
                                    else {
                                        self.queryRecordsWithCursor(cursor: cursor, isFirstCheck: false, uid: uid, appID: self.appID, recordType: recordType)
                                    }
                                }
                                CKContainer.default().publicCloudDatabase.add(operation2)
                            }
                        }
                        else {
                            guard let vc = self.vc else { return }
                            CKTrendsUtilities.presentErrorAlert(message: "CKTrends refresh failed. Go back to the CKTrends app and tap Refresh to try again.", vc: vc)
                        }
                    }
                }
                
                // go through lists to track [recordType, list, recordType, list...]
                for i in stride(from: 0, through: self.listsToTrack.count-1, by: 2) {
                    
                    let predicate = NSPredicate(value: true)
                    let query = CKQuery(recordType: self.listsToTrack[i], predicate: predicate) // ith element is the record that has the list to track
                    CKContainer.default().publicCloudDatabase.perform(query, inZoneWith: nil) { records, error in // only care about 0th, so no need to use a cursor
                        if error == nil {
                            guard let records = records, records.count > 0 else {
                                return
                            }
                            self.saveListCount(record: records[0], uid: uid, appID: self.appID, recordType: self.listsToTrack[i], listName: self.listsToTrack[i+1], isFirstCheck: true)
                        }
                        else {
                            self.recordTypeErrorHandling(error: error as! CKError, uid: uid, appID: self.appID, recordType: "\(self.listsToTrack[i])~\(self.listsToTrack[i+1])")
                        }
                    }
                }
            }
            else {
                guard let vc = self.vc else { return }
                CKTrendsUtilities.presentErrorAlert(message: "CKTrends refresh failed. Go back to the CKTrends app and tap Refresh to try again.", vc: vc)
            }
        })
    }
    
    private func saveRecordCounts(records: [CKRecord], uid: String, appID: String, recordType: String, isFirstCheck: Bool) {
        
        let dateToCountDict = CKTrendsUtilities.dateToCountDictionary(records: records)
        
        // if it's the first time checking, record the earliest date
        if isFirstCheck {
            guard records.count > 0, let date = records[0].creationDate else { return }
            let dateStr = CKTrendsUtilities.stringFromDate(date: date)
            Database.database().reference().child("users").child("\(uid)").child("\(appID)").child("EARLIEST_DATE").updateChildValues([recordType: dateStr], withCompletionBlock: { (error, ref) in
                if error != nil {
                    guard let vc = self.vc else { return }
                    CKTrendsUtilities.presentErrorAlert(message: "CKTrends refresh failed. Go back to the CKTrends app and tap Refresh to try again.", vc: vc)
                }
            })
        }
        
        // No new records, then just update the last check time
        if dateToCountDict.count == 0 {
            Database.database().reference().child("users").child("\(uid)").child("\(appID)").child("LAST_CHECK").updateChildValues([recordType: CKTrendsUtilities.formattedDateForToday()], withCompletionBlock: { (error, ref) in
                if error != nil {
                    guard let vc = self.vc else { return }
                    CKTrendsUtilities.presentErrorAlert(message: "CKTrends refresh failed. Go back to the CKTrends app and tap Refresh to try again.", vc: vc)
                }
            })
        }
        
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
                            Database.database().reference().child("users").child("\(uid)").child("\(appID)").child("LAST_CHECK").updateChildValues([recordType: CKTrendsUtilities.formattedDateForToday()], withCompletionBlock : { (error2, ref) in
                                if error2 != nil {
                                    guard let vc = self.vc else { return }
                                    CKTrendsUtilities.presentErrorAlert(message: "CKTrends refresh failed. Go back to the CKTrends app and tap Refresh to try again.", vc: vc)
                                }
                                else {
                                    if self.recordTypeToRecordListDict[recordType] != nil {
                                        self.recordTypeToRecordListDict[recordType]?.removeAll()
                                    }
                                }
                            })
                        }
                        else {
                            guard let vc = self.vc else { return }
                            CKTrendsUtilities.presentErrorAlert(message: "CKTrends refresh failed. Go back to the CKTrends app and tap Refresh to try again.", vc: vc)
                        }
                    })
                }
                
                // Save the max count
                Database.database().reference().child("users").child("\(uid)").child("\(appID)").child("MAX_COUNT").updateChildValues([recordType: String(maxCount)], withCompletionBlock: { (error, ref) in
                    if error != nil {
                        guard let vc = self.vc else { return }
                        CKTrendsUtilities.presentErrorAlert(message: "CKTrends refresh failed. Go back to the CKTrends app and tap Refresh to try again.", vc: vc)
                    }
                })
                
            }
            else {
                guard let vc = self.vc else { return }
                CKTrendsUtilities.presentErrorAlert(message: "CKTrends refresh failed. Go back to the CKTrends app and tap Refresh to try again.", vc: vc)
            }
        }
    }
    
    private func saveListCount(record: CKRecord, uid: String, appID: String, recordType: String, listName: String, isFirstCheck: Bool) {
        
        var count: Int?
        
        // either that list field doesn't exist or else it's never been added to before, so it's nil
        if record.object(forKey: listName) == nil {
            // don't track this
            let pathString = "users/\(uid)/\(appID)/TRACKING/\("\(recordType)~\(listName)")"
            // shouldn't be tracking this
            Database.database().reference().child(pathString).removeValue(completionBlock: { (error, ref) in
                if error != nil {
                    guard let vc = self.vc else { return }
                    CKTrendsUtilities.presentErrorAlert(message: "CKTrends refresh failed. Go back to the CKTrends app and tap Refresh to try again.", vc: vc)
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
                        Database.database().reference().child("users").child("\(uid)").child("\(appID)").child("LAST_CHECK").updateChildValues(["\(recordType)~\(listName)": CKTrendsUtilities.formattedDateForToday()], withCompletionBlock : { (error2, ref) in
                            if error2 == nil {
                                // save the delta from the last time
                                Database.database().reference().child("users").child("\(uid)").child("\(appID)").child("DELTAS").updateChildValues(["\(recordType)~\(listName)": count! - oldCount], withCompletionBlock : { (error3, ref) in
                                    if error3 != nil {
                                        guard let vc = self.vc else { return }
                                        CKTrendsUtilities.presentErrorAlert(message: "CKTrends refresh failed. Go back to the CKTrends app and tap Refresh to try again.", vc: vc)
                                    }
                                })
                            }
                            else {
                                guard let vc = self.vc else { return }
                                CKTrendsUtilities.presentErrorAlert(message: "CKTrends refresh failed. Go back to the CKTrends app and tap Refresh to try again.", vc: vc)
                            }
                        })
                    }
                    else {
                        guard let vc = self.vc else { return }
                        CKTrendsUtilities.presentErrorAlert(message: "CKTrends refresh failed. Go back to the CKTrends app and tap Refresh to try again.", vc: vc)
                    }
                })
            }
            else {
                guard let vc = self.vc else { return }
                CKTrendsUtilities.presentErrorAlert(message: "CKTrends refresh failed. Go back to the CKTrends app and tap Refresh to try again.", vc: vc)
            }
        }
    }
    
    // adapted from: https://gist.github.com/evermeer/5df7ad1f8db529893f40
    private func queryRecordsWithCursor(cursor: CKQueryCursor?, isFirstCheck: Bool, uid: String, appID: String, recordType: String) {
        
        guard let theCursor = cursor else {
            self.saveRecordCounts(records: self.recordTypeToRecordListDict[recordType]!, uid: uid, appID: appID, recordType: recordType, isFirstCheck: isFirstCheck) // use isFirstCheck, not the value in the dictionary
            return
            
        }
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
        // happens when all records are done for that cursor
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
    
    private func recordTypeErrorHandling(error: CKError, uid: String, appID: String, recordType: String) {
        // 10 - system defined record type
        // 11 - record type not found
        if error.errorCode == 10 || error.errorCode == 11 {
            let pathString = "users/\(uid)/\(appID)/TRACKING/\(recordType)"
            // shoudn't be tracking this
            Database.database().reference().child(pathString).removeValue(completionBlock: { (error, ref) in
                if error != nil {
                    guard let vc = self.vc else { return }
                    CKTrendsUtilities.presentErrorAlert(message: "CKTrends refresh failed. One of the record types you desire to track does not exist, or you are trying to track a system record type, like User.", vc: vc)
                }
            })
        }
        else if error.errorCode == 12 {
            guard let vc = self.vc else { return }
            CKTrendsUtilities.presentErrorAlert(message: "CKTrends refresh failed. Make sure that the Record Types you wish to track have a queryable recordName and a queryable & sortable createdAt. (See API documentation for help.)", vc: vc)
        }
        else {
            guard let vc = self.vc else { return }
            CKTrendsUtilities.presentErrorAlert(message: "CKTrends refresh failed. Go back to the CKTrends app and tap Refresh to try again.", vc: vc)
        }
    }
    
}


