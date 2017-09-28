//
//  SecondViewController.swift
//  SampleDeveloperApp
//
//  Created by Marissa Le Coz on 9/23/17.
//  Copyright © 2017 Marissa Le Coz. All rights reserved.
//

import UIKit
import CloudKit

class SecondViewController: UIViewController {
    
    let db = CKContainer(identifier: "iCloud.com.MarissaLeCozz.SampleDeveloperApp").publicCloudDatabase;

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func createRecordBInstance(_ sender: UIButton) {
        let record = CKRecord(recordType: "RecordTypeB")
        db.save(record) { savedRecord, error in
            print("Error saving to record to CloudKit!");
        }
    }

}

