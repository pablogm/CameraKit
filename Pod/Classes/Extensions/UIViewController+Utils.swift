/*
Copyright (c) 2015 Pablo GM <invanzert@gmail.com>

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
*/


import Foundation
import UIKit

public typealias CancelActionPerformed = (UIAlertAction) -> ()
public typealias OkActionPerformed     = (UIAlertAction) -> ()
public typealias AlertPerformed        = () -> ()

extension UIViewController {
    
    public func showAlert(title: String, message: String, ok: String, cancel: String,
        cancelAction: CancelActionPerformed?,
        okAction: OkActionPerformed?,
        completion: AlertPerformed?) {
            
            let alertController = UIAlertController(title: title, message: message, preferredStyle: .Alert)
            
            if cancelAction != nil {
                let cancelAction = UIAlertAction(title: cancel, style: .Cancel) { (action) in
                    if let a = cancelAction {
                        a(action)
                    }
                }
                alertController.addAction(cancelAction)
            }
            
            let OKAction = UIAlertAction(title: ok, style: .Default) { (action) in
                if let a = okAction {
                    a(action)
                }
            }
            alertController.addAction(OKAction)
            
            self.presentViewController(alertController, animated: true) {
                if let a = completion {
                    a()
                }
            }
    }
}