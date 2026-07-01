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

class AttributeCollectionViewController: UIViewController {
    var onSubmit: ((_ attributes: [String: String]) -> Void)?
    var onCancel: (() -> Void)?
    var channelTargetType: MSALNativeAuthChannelType?

    /// The attributes the server requested. Set before presenting.
    var requiredAttributes: [MSALNativeAuthRequiredAttribute] = []

    @IBOutlet weak var errorLabel: UILabel!
    @IBOutlet weak var usernameTextField: UITextField!
    @IBOutlet weak var messageLabel: UILabel!
    @IBOutlet weak var fieldsStackView: UIStackView!

    private var attributeTextFields: [(name: String, textField: UITextField)] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        messageLabel.text = "Additional attributes are required, please enter them below."
        buildAttributeFields()
    }

    private func buildAttributeFields() {
        // Remove the placeholder rows defined in the storyboard.
        fieldsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        attributeTextFields.removeAll()

        // Fall back to a single free-form field if the server sent no attribute metadata.
        let attributes: [(name: String, required: Bool)] = requiredAttributes.isEmpty
            ? [(name: "username", required: true)]
            : requiredAttributes.map { ($0.name, $0.required) }

        for attribute in attributes {
            let row = UIStackView()
            row.axis = .horizontal
            row.spacing = 12
            row.alignment = .center

            let label = UILabel()
            label.text = attribute.required ? "\(attribute.name) *" : attribute.name
            label.setContentHuggingPriority(.required, for: .horizontal)

            let textField = UITextField()
            textField.borderStyle = .roundedRect
            textField.autocapitalizationType = .none
            textField.autocorrectionType = .no
            textField.placeholder = attribute.name

            row.addArrangedSubview(label)
            row.addArrangedSubview(textField)
            fieldsStackView.addArrangedSubview(row)

            attributeTextFields.append((attribute.name, textField))
        }
    }

    @IBAction func cancelPressed(_: Any) {
        view.endEditing(true)
        onCancel?()

        dismiss(animated: true)
    }

    @IBAction func submitPressed(_: Any) {
        view.endEditing(true)

        var collected: [String: String] = [:]
        for entry in attributeTextFields {
            collected[entry.name] = entry.textField.text ?? ""
        }

        onSubmit?(collected)
    }
}
