//
//  HomeView.swift
//  EGO
//
//  Landing tab: a large stop-number field. Every stop has a 5-digit code, so a
//  complete code navigates straight to that stop's screen.
//

import SwiftUI

struct HomeView: View {
    @State private var stopCode = ""
    @State private var path: [String] = []
    @FocusState private var isFieldFocused: Bool

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 40) {
                Spacer()

                Image(.logoTypeRed)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 72)

                VStack(spacing: 12) {
                    TextField("00000", text: $stopCode)
                        .keyboardType(.numberPad)
                        .font(.system(size: 44, weight: .semibold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .padding(.vertical, 16)
                        .background(Color(.systemGray6), in: .rect(cornerRadius: 16))
                        .focused($isFieldFocused)

                    Text("Enter the 5-digit stop number")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 32)

                Spacer()
                Spacer()
            }
            .onChange(of: stopCode) { _, newValue in
                handleInput(newValue)
            }
            // Not a keyboard toolbar: that bar sits flush against the keyboard,
            // while a bottom safe-area inset floats above it with its own gap.
            .safeAreaInset(edge: .bottom) {
                if isFieldFocused {
                    HStack {
                        Spacer()
                        Button("Done") { isFieldFocused = false }
                            .buttonStyle(.glass)
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 8)
                }
            }
            .animation(.default, value: isFieldFocused)
            .navigationDestination(for: String.self) { code in
                StopView(stopCode: code)
            }
        }
    }

    private func handleInput(_ newValue: String) {
        let digits = String(newValue.filter(\.isNumber).prefix(5))
        guard digits == newValue else {
            stopCode = digits
            return
        }
        if digits.count == 5 {
            isFieldFocused = false
            path.append(digits)
            // Clear so coming back presents a fresh field.
            stopCode = ""
        }
    }
}
