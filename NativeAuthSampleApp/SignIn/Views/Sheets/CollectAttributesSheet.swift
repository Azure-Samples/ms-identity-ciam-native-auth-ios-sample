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

import SwiftUI
import MSAL

struct CollectAttributesSheet: View
{
    @ObservedObject var viewModel: SignInViewModel
    @State private var values: [String: String] = [:]

    var body: some View
    {
        VStack(alignment: .leading, spacing: 16)
        {
            Text("Additional information required")
                .font(.title2)
                .fontWeight(.semibold)

            if let statusMessage = viewModel.statusMessage
            {
                Text(statusMessage)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 12)
            {
                ForEach(Array(viewModel.requiredAttributes.enumerated()), id: \.offset)
                { _, attribute in
                    VStack(alignment: .leading, spacing: 6)
                    {
                        Text(label(for: attribute))
                            .font(.footnote)
                            .foregroundColor(.secondary)

                        TextField(attribute.name, text: binding(for: attribute.name))
                            .textFieldStyle(.roundedBorder)
                    }
                }
            }

            HStack
            {
                Button("Cancel")
                {
                    viewModel.cancelFlow()
                }

                Spacer()

                Button("Submit")
                {
                    let attributes = values.reduce(into: [String: Any]())
                    { result, entry in
                        if !entry.value.isEmpty
                        {
                            result[entry.key] = entry.value
                        }
                    }

                    viewModel.onSubmitAttributes?(attributes)
                }
            }
        }
        .padding()
        .frame(maxWidth: 480)
    }

    private func binding(for name: String) -> Binding<String>
    {
        Binding(
            get:
            {
                values[name] ?? ""
            },
            set:
            { newValue in
                values[name] = newValue
            }
        )
    }

    private func label(for attribute: MSALNativeAuthRequiredAttribute) -> String
    {
        attribute.required ? "\(attribute.name) (required)" : attribute.name
    }
}
