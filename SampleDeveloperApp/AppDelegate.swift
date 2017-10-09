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

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    var window: UIWindow?
    
    let db = CKContainer(identifier: "iCloud.com.MarissaLeCozz.SampleDeveloperApp").publicCloudDatabase;

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        
        registerForRemoteNotification()
        
        // configures notif settings for alert message, sound, and badge
        if #available(iOS 10.0, *) {
            UNUserNotificationCenter.current().requestAuthorization(options: [[.alert, .sound, .badge]], completionHandler: { (granted, error) in
                UIApplication.shared.registerForRemoteNotifications()
            })
        }
        
        let predicate = NSPredicate(value: true)
        let subscription = CKQuerySubscription(recordType: "RecordTypeA", predicate: predicate, options: .firesOnRecordCreation)
        
        let info = CKNotificationInfo()
        info.alertLocalizationKey = "NEW_RECORD_A_INSTANCE_ALERT"
        info.soundName = nil
        info.shouldBadge = false
        
        subscription.notificationInfo = info
        
        db.save(subscription) { subscription, error in
            if (error != nil) {
                guard let error = error as? CKError else {
                    return
                }
                if (error.errorCode == 15) {
                    // do nothing; subscription already created; TODO - clean up this inefficiency?
                }
                else {
                    print("Error saving subscription")
                }
            }
        }
        
        return true
    }
    
    func registerForRemoteNotification() {
        if #available(iOS 10.0, *) {
            let center  = UNUserNotificationCenter.current()
            center.delegate = self
            center.requestAuthorization(options: [.sound, .alert, .badge]) { (granted, error) in
                if error == nil{
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
        else {
            UIApplication.shared.registerUserNotificationSettings(UIUserNotificationSettings(types: [.sound, .alert, .badge], categories: nil))
            UIApplication.shared.registerForRemoteNotifications()
        }
    }
    
    // Called when a notification is delivered to a foreground, background, or quit app.
    @available(iOS 10.0, *)
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        
        let ckNotification = CKNotification(fromRemoteNotificationDictionary: notification.request.content.userInfo as! [String : NSObject])
        
        //let ckNotification = CKNotification(fromRemoteNotificationDictionary: userInfo as! [String : NSObject])
        if ckNotification.notificationType == .query, let queryNotification = ckNotification as? CKQueryNotification {
            let recordID = queryNotification.recordID
            
            guard let rID = recordID else {
                return
            }
            
            
//            // to show that this code was reached, change the string field in this record
//            let record = CKRecord(recordType: "RecordTypeA", recordID: rID)
//            record["aString"] = "The app received a notification that this record was created and, in turn, gave aString the value you are now reading." as CKRecordValue
//            
//            db.save(record) { record, error in
//                if (error != nil) {
//                    print("Error saving updating record")
//                }
//            }
        
        print("detected a change: record with id \(rID) was created")
        
        }
        
        // THIS DOES NOT WORK
        
//        let otherDB = CKContainer(identifier: "iCloud.com.MarissaLeCoz.AnalyticsApp").publicCloudDatabase;
//        
//        let recordTypeTrackerRecord = CKRecord(recordType: "RecordTypeTracker")
//        recordTypeTrackerRecord["appID"] = 1 as CKRecordValue
//        recordTypeTrackerRecord["type"] = "RecordTypeA" as CKRecordValue
//        recordTypeTrackerRecord["count"] = 1 as CKRecordValue
//        recordTypeTrackerRecord["date"] = Date() as CKRecordValue
//        
//        otherDB.save(recordTypeTrackerRecord) { record, err in
//            if (err != nil) {
//                print("problem saving record to other db")
//            }
//        }
    }
    
    @available(iOS 10.0, *)
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        //print("User Info = ",response.notification.request.content.userInfo)
        completionHandler()
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


}

