//
//  ViewController.swift
//  EmailToCalendarApp2
//
//  Created by Madhumita Mazumder on 12/4/17.
//  Copyright © 2017 Madhumita Mazumder. All rights reserved.
//

import UIKit

class AccountViewController: UIViewController {
    
    let service = OutlookService.shared()

   
    @IBAction func log(_ sender: Any) {
        if (service.isLoggedIn) {
            // Logout
            service.logout()
        } else {
            // Login
            service.login(from: self) {
                error in
                if let unwrappedError = error {
                    NSLog("Error logging in: \(unwrappedError)")
                } else {
                    NSLog("Successfully logged in.")
                }
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
 


}

