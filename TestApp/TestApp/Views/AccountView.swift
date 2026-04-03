import SwiftUI
import ManagedNavigation

struct AccountView: View {
  @Environment(\.navigator) private var navigator
  @Environment(\.dismiss) var dismiss
  
  var body: some View {
    ScrollView {
      VStack(spacing: 24) {
        // MARK: - Breadcrumbs
        NavigationBreadcrumbs()
        
        // MARK: - Header
        VStack(spacing: 8) {
          Image(systemName: "person.crop.square.fill")
            .font(.system(size: 64))
            .foregroundStyle(.orange.gradient)
          Text("Jane Doe")
            .font(.title.bold())
          Text("Premium Member")
            .font(.subheadline)
            .foregroundStyle(.orange)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(.orange.opacity(0.15), in: .capsule)
        }
        .padding(.top)
        
        // MARK: - Subscription
        GroupBox("Subscription") {
          VStack(spacing: 12) {
            HStack {
              Text("Plan")
              Spacer()
              Text("Pro Annual")
                .foregroundStyle(.secondary)
            }
            Divider()
            HStack {
              Text("Renewal")
              Spacer()
              Text("Dec 15, 2026")
                .foregroundStyle(.secondary)
            }
            Divider()
            HStack {
              Text("Price")
              Spacer()
              Text("$99.99/year")
                .foregroundStyle(.secondary)
            }
          }
        }
        .padding(.horizontal)
        
        // MARK: - Payment Methods
        GroupBox("Payment Methods") {
          VStack(spacing: 0) {
            PaymentRow(icon: "creditcard.fill", name: "Visa ending 4242", isDefault: true)
            Divider()
            PaymentRow(icon: "building.columns.fill", name: "Bank account ending 8910", isDefault: false)
          }
        }
        .padding(.horizontal)
        
        // MARK: - Security
        GroupBox("Security") {
          VStack(spacing: 0) {
            SecurityRow(icon: "lock.fill", title: "Change Password", color: .blue)
            Divider()
            SecurityRow(icon: "faceid", title: "Face ID", color: .green)
            Divider()
            SecurityRow(icon: "key.fill", title: "Two-Factor Auth", color: .purple)
          }
        }
        .padding(.horizontal)
        
        // MARK: - State Restoration
        StateRestorationGrid()
        
        // MARK: - Actions
        VStack(spacing: 12) {
          Button("Push Another Account") {
            navigator?.push(AccountDestination())
          }
          
          Button("Dismiss") {
            dismiss()
          }
          .tint(.red)
        }
        .buttonStyle(.glass)
        .padding(.horizontal)
        
        Spacer(minLength: 40)
      }
    }
    .navigationTitle("Account")
    .macOSModifiers()
  }
}

private struct PaymentRow: View {
  let icon: String
  let name: String
  let isDefault: Bool
  
  var body: some View {
    HStack {
      Image(systemName: icon)
        .foregroundStyle(.blue)
        .frame(width: 24)
      Text(name)
      Spacer()
      if isDefault {
        Text("Default")
          .font(.caption)
          .foregroundStyle(.green)
          .padding(.horizontal, 8)
          .padding(.vertical, 2)
          .background(.green.opacity(0.15), in: .capsule)
      }
    }
    .padding(.vertical, 8)
  }
}

private struct SecurityRow: View {
  let icon: String
  let title: String
  let color: Color
  
  var body: some View {
    HStack {
      Image(systemName: icon)
        .foregroundStyle(color)
        .frame(width: 24)
      Text(title)
      Spacer()
      Image(systemName: "chevron.right")
        .font(.caption)
        .foregroundStyle(.tertiary)
    }
    .padding(.vertical, 8)
  }
}
