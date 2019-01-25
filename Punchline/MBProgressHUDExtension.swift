//
//  MBProgressHUDExtension.swift
//  Punchline
//
//  Created by Justin Heo on 1/24/19.
//  Copyright © 2019 jstnheo. All rights reserved.
//

import Foundation
import MBProgressHUD

extension MBProgressHUD {
    static func showSpinner() {
        if let window = UIApplication.shared.windows.last {
            MBProgressHUD.showAdded(to: window, animated: true)
        }
    }
    
    static func hideSpinner() {
        if let window = UIApplication.shared.windows.last {
            MBProgressHUD.hide(for: window, animated: true)
        }
    }
}
