// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import Foundation
import SwiftUI
import Shared

enum CreditCardInputType {
    case name, number, expiration
}

struct CreditCardInputField: View {
    let inputType: CreditCardInputType
    var fieldHeadline: String = ""
    var errorString: String = ""
    var delimiterCharacter: String?
    var userInputLimit: Int = 0
    var formattedTextLimit: Int = 0
    var keyboardType: UIKeyboardType = .numberPad
    var showError = false
    var disableEditing: Bool {
        return viewModel.state == .view
    }
    @ObservedObject var viewModel: CreditCardInputViewModel
    let inputFieldHelper: CreditCardInputFieldHelper
    @State var text: String = ""
    @State var shouldReveal = true {
        willSet(val) {
            if inputType == .number {
                text = val ? revealCardNum() : concealedCardNum()
            }
        }
    }

    // Theming
    @Environment(\.themeType)
    var themeVal
    @State var errorColor: Color = .clear
    @State var titleColor: Color = .clear
    @State var textFieldColor: Color = .clear
    @State var backgroundColor: Color = .clear

    // MARK: Init

    init(inputType: CreditCardInputType,
         showError: Bool,
         inputViewModel: CreditCardInputViewModel
    ) {
        self.inputType = inputType
        self.showError = showError
        self.viewModel = inputViewModel
        self.inputFieldHelper = CreditCardInputFieldHelper(inputType: inputType)

        self._shouldReveal = viewModel.state == .view ? State(initialValue: false) : State(initialValue: true)

        switch self.inputType {
        case .name:
            fieldHeadline = .CreditCard.EditCard.NameOnCardTitle
            errorString = .CreditCard.ErrorState.NameOnCardSublabel
            delimiterCharacter = nil
            userInputLimit = 100
            formattedTextLimit = 100
            keyboardType = .alphabet
        case .number:
            fieldHeadline = .CreditCard.EditCard.CardNumberTitle
            errorString = .CreditCard.ErrorState.CardNumberSublabel
            delimiterCharacter = "-"
            userInputLimit = 19
            formattedTextLimit = 23
            keyboardType = .numberPad
        case .expiration:
            fieldHeadline = .CreditCard.EditCard.CardExpirationDateTitle
            errorString = .CreditCard.ErrorState.CardExpirationDateSublabel
            delimiterCharacter = " / "
            userInputLimit = 4
            formattedTextLimit = 7
            keyboardType = .numberPad
        }
    }

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 0) {
                provideInputField().onAppear {
                    updateFields(inputType: inputType)
                }.onChange(of: viewModel.state) { val in
                    switch val {
                    case .edit, .add:
                        shouldReveal = true
                    case.view:
                        updateFields(inputType: .name)
                        updateFields(inputType: .expiration)
                        shouldReveal = false
                    }
                }

                if showError {
                    errorViewWith(errorString: errorString)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(backgroundColor.edgesIgnoringSafeArea(.bottom))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 20)
        .onAppear {
            applyTheme(theme: themeVal.theme)
        }
        .onChange(of: themeVal) { val in
            applyTheme(theme: val.theme)
        }
    }

    // MARK: Theming

    func applyTheme(theme: Theme) {
        let color = theme.colors
        errorColor = Color(color.textWarning)
        titleColor = Color(color.textSecondary)
        textFieldColor = Color(color.textPrimary)
        backgroundColor = Color(color.layer2)
    }

    // MARK: Views

    @ViewBuilder
    private func provideInputField() -> some View {
        Text(fieldHeadline)
            .preferredBodyFont(size: 15)
            .foregroundColor(titleColor)
            .frame(maxWidth: .infinity, alignment: .leading)
        if viewModel.state == .view {
            Menu {
                Button(String.CreditCard.EditCard.CopyLabel) {
                    UIPasteboard.general.string = viewModel.getCopyValueFor(inputType)
                }

                // We conceal and reveal credit card number for only view state
                if viewModel.state == .view &&
                    inputType == .number {
                    if shouldReveal {
                        Button(String.CreditCard.EditCard.ConcealLabel) {
                            shouldReveal = false
                        }
                    } else {
                        Button(String.CreditCard.EditCard.RevealLabel) {
                            shouldReveal = true
                        }
                    }
                }
            } label: {
                getTextField(editMode: disableEditing)
            }.disabled(!disableEditing)
        } else {
            getTextField(editMode: disableEditing)
        }
    }

    @ViewBuilder
    private func errorViewWith(errorString: String) -> some View {
        HStack(spacing: 0) {
            Image(ImageIdentifiers.errorAutofill)
                .renderingMode(.template)
                .foregroundColor(errorColor)
                .accessibilityHidden(true)
            Text(errorString)
                .errorTextStyle(color: errorColor)
        }
        .padding(.top, 7.4)
    }

    private func getTextField(editMode: Bool) -> some View {
        TextField(text, text: $text)
            .preferredBodyFont(size: 17)
            .disabled(editMode)
            .padding(.top, 7.5)
            .foregroundColor(textFieldColor)
            .multilineTextAlignment(.leading)
            .keyboardType(keyboardType)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .onChange(of: text) { [oldValue = text] newValue in
                    handleTextInputWith(oldValue, and: newValue)
            }
    }

    // MARK: Helper

    private func updateFields(inputType: CreditCardInputType) {
        switch self.inputType {
        case .name:
            text = viewModel.nameOnCard
        case .number:
            let state = viewModel.state
            shouldReveal = state == .edit || state == .add
        case .expiration:
            text = viewModel.expirationDate
        }
    }

    func handleTextInputWith(_ oldValue: String, and newValue: String) {
        switch inputType {
        case .name:
            guard !newValue.isEmpty else {
                viewModel.nameIsValid = false
                return
            }

            viewModel.nameOnCard = newValue
        case .number:
            // Do not process concealed numbers
            guard shouldReveal else { return }
            // Credit card text with `-` delimiter
            let maxAllowedNumbers = 19
            let val = inputFieldHelper.sanitizeInputOn(newValue)
            guard val.count <= maxAllowedNumbers else {
                text = oldValue
                return
            }
            let formattedText = inputFieldHelper.addCreditCardDelimiter(sanitizedCCNum: val)
            text = formattedText
            viewModel.cardNumber = "\(val)"
        case .expiration:
            guard newValue.removingOccurrences(of: " / ") != oldValue else { return }

            let newSanitizedValue = inputFieldHelper.sanitizeInputOn(newValue)
            let numbersCount = inputFieldHelper.countNumbersIn(text: newSanitizedValue)

            guard !(newValue.count > formattedTextLimit) || !(numbersCount > 4) else {
                text = oldValue
                return
            }

            guard numbersCount % 4 == 0 else {
                text = newSanitizedValue.removingOccurrences(of: " / ")
                viewModel.expirationIsValid = false
                return
            }

            viewModel.expirationDate = newSanitizedValue.removingOccurrences(of: " / ")

            let formattedText = inputFieldHelper.formatExpiration(for: newSanitizedValue.removingOccurrences(of: " / "))

            text = formattedText
        }
    }

    func concealedCardNum() -> String {
        let sanitizedCardNum =  inputFieldHelper.sanitizeInputOn(viewModel.cardNumber)
        guard !sanitizedCardNum.isEmpty else { return "" }
        let concealedString = String(repeating: "•", count: sanitizedCardNum.count - 4)
        let lastFour = sanitizedCardNum.suffix(4)
        return concealedString + lastFour
    }

    func revealCardNum() -> String {
        let sanitizedCardNum =  inputFieldHelper.sanitizeInputOn(viewModel.cardNumber)
        guard !sanitizedCardNum.isEmpty else { return "" }
        return inputFieldHelper.addCreditCardDelimiter(sanitizedCCNum: sanitizedCardNum)
    }
}
