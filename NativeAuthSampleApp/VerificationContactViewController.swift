//
// Copyright (c) Microsoft Corporation.
// All rights reserved.
//
// This code is licensed under the MIT License.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files(the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and / or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions :
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import UIKit
import MSAL

class VerificationContactViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    var onAuthMethodSelection: ((_ authMethod: MSALAuthMethod?) -> Void)?
    var onContinue: ((_ verificationContact: String?) -> Void)?
    var onCancel: (() -> Void)?

    var authMethods: [MSALAuthMethod]!
    var verifyAuthMethodDetailViewController : VerifyAuthMethodDetailViewController?
    @IBOutlet weak var tableView: UITableView!

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.delegate = self
        tableView.dataSource = self
    }

    @IBAction func dismissButtonPressed(_ sender: Any) {
        onCancel?()
        self.dismiss(animated: true, completion: nil)
    }

    func setDetailErrorMessage(_ error: String) {
        verifyAuthMethodDetailViewController?.errorLabel.text = error
    }

    // MARK: - Table View

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return authMethods.count
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 64
    }
    
    internal func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "AuthMethodCell", for: indexPath) as! AuthMethodCell
        let authMethod = authMethods[indexPath.row]
        cell.authMethod = authMethod
        cell.setup()
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let cell = tableView.cellForRow(at: indexPath) as! AuthMethodCell
        verifyAuthMethodDetailViewController = storyboard?.instantiateViewController(withIdentifier: "VerifyAuthMethodDetailViewController") as? VerifyAuthMethodDetailViewController
        verifyAuthMethodDetailViewController?.onCancel = onCancel
        verifyAuthMethodDetailViewController?.onContinue = onContinue
        verifyAuthMethodDetailViewController?.authMethod = cell.authMethod
        onAuthMethodSelection?(cell.authMethod)

        self.present(verifyAuthMethodDetailViewController!, animated: true, completion: nil)
    }
}
