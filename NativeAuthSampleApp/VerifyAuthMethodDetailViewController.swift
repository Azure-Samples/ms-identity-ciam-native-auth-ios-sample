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

class VerifyAuthMethodDetailViewController: UIViewController {
    var onContinue: ((_ verificationContact: String?) -> Void)?
    var onCancel: (() -> Void)?
    var authMethod: MSALAuthMethod?

    @IBOutlet weak var errorLabel: UILabel!
    @IBOutlet weak var messageLabel: UILabel!
    @IBOutlet weak var challengeChannelName: UILabel!
    @IBOutlet weak var verificationContactValue: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if authMethod?.channelTargetType.isEmailType == true {
            messageLabel.text = "For Multi-factor authentication, you can enter a separate email address (optional). If you don't provide one, we will use your primary email address " + (authMethod?.loginHint ?? "")
            challengeChannelName.text = "Email"
            verificationContactValue.keyboardType = .emailAddress
        } else if authMethod?.channelTargetType.isSMSType == true {
            messageLabel.text = "For Multi-factor authentication using SMS please enter your phone number. The format needs to be \"+<country code> <number>\", for example \"+1 000111222\""
            challengeChannelName.text = "Phone"
            verificationContactValue.keyboardType = .phonePad
        } else {
            messageLabel.text = "The authentication method selected is not supported in this sample app."
            challengeChannelName.text = "N/A"
            verificationContactValue.keyboardType = .default
        }
    }

    @IBAction func cancelPressed(_ sender: Any) {
        verificationContactValue.resignFirstResponder()
        onCancel?()

        dismiss(animated: true)
    }


    @IBAction func continuePressed(_ sender: Any) {
        guard let optionalContact = verificationContactValue.text else {
            return
        }

        verificationContactValue.resignFirstResponder()
        onContinue?(optionalContact)
    }
}
