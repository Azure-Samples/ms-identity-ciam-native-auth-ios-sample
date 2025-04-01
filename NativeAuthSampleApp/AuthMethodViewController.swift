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

class AuthMethodViewController: UIViewController, UIPickerViewDelegate, UIPickerViewDataSource {
    var onSubmit: ((_ authMethod: MSALAuthMethod?, _ verificationContact: String?) -> Void)?
    var onCancel: (() -> Void)?
    
    @IBOutlet weak var authMethodPicker: UIPickerView!
    @IBOutlet weak var errorLabel: UILabel!
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var challengeTypeLabel: UILabel!
    
    var authMethods: [MSALAuthMethod] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
            
        authMethodPicker.delegate = self
        authMethodPicker.dataSource = self
            
        // Hide error label initially
        errorLabel.isHidden = true
        
        // Update UI based on available auth methods
        updateUIForAuthMethods()
    }
    
    // Helper method to update UI based on available auth methods
    private func updateUIForAuthMethods() {
        if authMethods.isEmpty {
            // If no auth methods available, hide picker and show text field only
            authMethodPicker.isHidden = true
            emailTextField.placeholder = "Enter your email address as the auth method"
        } else {
            // If auth methods are available, show picker
            authMethodPicker.isHidden = false
            authMethodPicker.reloadAllComponents()
            
            // Select first method by default and update text field
            if !authMethods.isEmpty {
                authMethodPicker.selectRow(0, inComponent: 0, animated: false)
                updateTextFieldForSelectedMethod(row: 0)
            }
        }
    }
    
    // Helper to update text field based on selected auth method
    private func updateTextFieldForSelectedMethod(row: Int) {
        guard row < authMethods.count else { return }
        
        let method = authMethods[row]
        switch method.challengeType {
        case "email":
            challengeTypeLabel.text = "Email"
            emailTextField.text = method.loginHint
            emailTextField.keyboardType = .emailAddress
        case "sms":
            challengeTypeLabel.text = "SMS"
            emailTextField.text = method.loginHint
            emailTextField.keyboardType = .phonePad
        default:
            emailTextField.placeholder = "Unknown"
            emailTextField.text = method.loginHint
            emailTextField.keyboardType = .default
        }
    }
    
    // MARK: - UIPickerViewDataSource

    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1 // One column
    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return authMethods.count
    }

    // MARK: - UIPickerViewDelegate

    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        guard row < authMethods.count else {
            return nil
        }
        
        // Display the challenge type with the first letter capitalized
        return authMethods[row].challengeType.capitalized
    }

    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        updateTextFieldForSelectedMethod(row: row)
        
        // Clear any previous errors
        errorLabel.isHidden = true
    }
    
    @IBAction func cancelPressed(_ sender: Any) {
        emailTextField.resignFirstResponder()
        onCancel?()
        
        dismiss(animated: true)
    }
    

    @IBAction func submitPressed(_ sender: Any) {
        // If auth methods list is empty, just use whatever the user entered
        if authMethods.isEmpty {
            if let inputText = emailTextField.text, !inputText.isEmpty {
                // Cannot access MSALAuthMethod
                onSubmit?(nil, emailTextField.text)
                dismiss(animated: true)
            } else {
                errorLabel.text = "Please enter an authentication method"
                errorLabel.isHidden = false
            }
            return
        }
        
        // Get the selected authentication method if picker is visible
        let selectedRow = authMethodPicker.selectedRow(inComponent: 0)
        
        if selectedRow >= 0 && selectedRow < authMethods.count {
            let method = authMethods[selectedRow]
            
            if let userInput = emailTextField.text, !userInput.isEmpty {
                onSubmit?(method, emailTextField.text)
                dismiss(animated: true)
            } else {
                errorLabel.text = "Please enter the required information"
                errorLabel.isHidden = false
            }
        } else {
            errorLabel.text = "Please select an authentication method"
            errorLabel.isHidden = false
        }
    }
}
