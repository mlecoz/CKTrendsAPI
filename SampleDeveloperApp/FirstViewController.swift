//
//  FirstViewController.swift
//  SampleDeveloperApp
//
//  Created by Marissa Le Coz on 9/23/17.
//  Copyright © 2017 Marissa Le Coz. All rights reserved.
//

import UIKit

class FirstViewController: UIViewController {
    
    private let db = CKContainer.default().publicCloudDatabase
    private let container = CKContainer.default()

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

