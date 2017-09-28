//
//  FirstViewController.swift
//  SampleDeveloperApp
//
//  Created by Marissa Le Coz on 9/23/17.
//  Copyright © 2017 Marissa Le Coz. All rights reserved.
//

import UIKit
import CloudKit

class FirstViewController: UIViewController {
    
    @IBOutlet weak var successMessage: UILabel!

    let db = CKContainer(identifier: "iCloud.com.MarissaLeCozz.SampleDeveloperApp").publicCloudDatabase;
    

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func createRecordAInstance(_ sender: UIButton) {
        let record = CKRecord(recordType: "RecordTypeA")
        db.save(record) { savedRecord, error in
            if (error == nil) {
                let randRed = CGFloat(Float(arc4random()) / Float(UINT32_MAX))
                let randGreen = CGFloat(Float(arc4random()) / Float(UINT32_MAX))
                let randBlue = CGFloat(Float(arc4random()) / Float(UINT32_MAX))
                self.successMessage.textColor = UIColor(red: randRed, green: randGreen, blue: randBlue, alpha: 1.0)
                self.successMessage.isHidden = false
            }
            else {
                print("Error saving to record to CloudKit!")
                self.successMessage.isHidden = true
            }
        }
    }
    

}

