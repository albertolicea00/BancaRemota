import SwiftUI

// MARK: - Top Nav Bar
struct TopNavBar: View {
    var themeColor: Color
    var onMenuTap: () -> Void
    var showMenuBtn: Bool = true
    var bank: Bank? = nil
    var title: String? = nil
    var isHome: Bool = false
    
    @AppStorage("useBankNameInsteadOfIcon") private var useBankNameInsteadOfIcon = false
    @AppStorage("showNetworkStatus") private var showNetworkStatus = false
    
    var body: some View {
        let contentColor = bank?.textColor ?? .primary
        
        VStack(spacing: 0) {
            HStack {
            if showMenuBtn {
                Button(action: onMenuTap) {
                    Image(systemName: "line.horizontal.3")
                        .font(.title2)
                        .foregroundColor(contentColor)
                }
            } else {
                Spacer().frame(width: 30) // placeholder
            }
            
            Spacer()
            
            // Center Content
            Group {
                if let bank = bank {
                    if useBankNameInsteadOfIcon {
                        Text(bank.name)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(contentColor)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    } else {
                        Image(bank.iconImg)
                            .resizable()
                            .renderingMode(.template)
                            .foregroundColor(contentColor)
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 40, height: 40)
                    }
                } else if isHome {
                    Image("AppLogoL")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else if let title = title {
                    Text(title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(contentColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .frame(height: 40)
            
            Spacer()
            
            /*
            Button(action: {}) {
                Image(systemName: "gearshape")
                    .font(.title2)
                    .foregroundColor(.primary)
            }
            */
            Spacer().frame(width: 30) // placeholder to maintain centering
        }
        .padding(.horizontal)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .background(themeColor)
        
        if showNetworkStatus {
            ConnectionBannerView()
        }
        }
    }
}

// MARK: - Connection Banner View
struct ConnectionBannerView: View {
    @StateObject private var cellularMonitor = CellularMonitor.shared
    
    var statusText: String {
        if !cellularMonitor.hasService {
            return "Sin Señal (USSD no funcionará)"
        }
        switch cellularMonitor.signalQuality {
        case 3:
            return "Señal Óptima (\(cellularMonitor.networkType))"
        case 2:
            return "Señal Buena (\(cellularMonitor.networkType))"
        case 1:
            return "Señal Débil (Riesgo de fallo)"
        default:
            return "Buscando Red..."
        }
    }
    
    var statusColor: Color {
        if !cellularMonitor.hasService { return .red }
        switch cellularMonitor.signalQuality {
        case 3: return .green
        case 2: return .appPrimary
        case 1: return .orange
        default: return .gray
        }
    }
    
    var statusIcon: String {
        if !cellularMonitor.hasService { return "antenna.radiowaves.left.and.right.slash" }
        switch cellularMonitor.signalQuality {
        case 3: return "antenna.radiowaves.left.and.right"
        case 2: return "antenna.radiowaves.left.and.right"
        case 1: return "exclamationmark.triangle.fill"
        default: return "antenna.radiowaves.left.and.right"
        }
    }
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: statusIcon)
                .font(.system(size: 14, weight: .bold))
            
            Text(statusText)
                .font(.system(size: 13, weight: .bold))
        }
        .foregroundColor(statusColor)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(statusColor.opacity(0.15))
    }
}

// MARK: - Operation Card
struct OperationCard: View {
    let operation: BankOperation
    let themeColor: Color
    let textColor: Color
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(operation.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text(operation.description)
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                ZStack {
                    Circle()
                        .fill(themeColor)
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: operation.iconName)
                        .font(.system(size: 20))
                        .foregroundColor(textColor)
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            .shadow(color: Color.primary.opacity(0.1), radius: 5, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Bank Selection Card
struct BankSelectionCard: View {
    let bank: Bank
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                Image(bank.iconImg)
                    .resizable()
                    .renderingMode(.template)
                    .foregroundColor(bank.textColor)
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 40)
                
                Text(bank.shortName)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(bank.textColor)
            }
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(bank.themeColor)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 3)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Toast Banner
struct ToastBannerView: View {
    @ObservedObject private var toastCenter = ToastCenter.shared

    var body: some View {
        VStack {
            if let toast = toastCenter.current {
                HStack(spacing: 10) {
                    Image(systemName: toast.iconName)
                        .font(.system(size: 16, weight: .bold))
                    Text(toast.message)
                        .font(.system(size: 14, weight: .semibold))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundColor(toast.isWarning ? .orange : .appPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(14)
                .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 4)
                .padding(.horizontal)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            Spacer()
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: toastCenter.current)
        .allowsHitTesting(false)
    }
}

// MARK: - Menu Shortcut Card
struct MenuShortcutCard: View {
    let iconName: String
    let title: String
    let themeColor: Color
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                Image(systemName: iconName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 30)
                    .foregroundColor(.primary)
                
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
            }
            .frame(width: 110, height: 90)
            .background(themeColor)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 3)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Data Card (Swipeable with Rounded Buttons)
struct DataCard: View {
    let id: UUID
    let title: String
    let subtitle: String?
    let value: String
    let iconName: String
    /// Asset-catalog image used instead of the SF Symbol (e.g. a bank icon). Falls back to `iconName`.
    var assetIconName: String? = nil
    let backgroundColor: Color
    var onEdit: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    
    @ObservedObject var userData = UserDataManager.shared
    @State private var offset: CGFloat = 0
    @State private var showCopied = false
    
    private var isSwiped: Bool {
        userData.activeSwipeID == id
    }
    
    var body: some View {
        ZStack {
            /* Background Actions (Rounded Buttons)
            HStack(spacing: 12) {
                Spacer()
                
                if let onEdit = onEdit {
                    Button(action: {
                        withAnimation(.spring()) { 
                            offset = 0
                            userData.activeSwipeID = nil
                        }
                        onEdit()
                    }) {
                        Image(systemName: "pencil")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(Color.blue))
                    }
                }
                
                if let onDelete = onDelete {
                    Button(action: {
                        withAnimation(.spring()) { 
                            offset = 0
                            userData.activeSwipeID = nil
                        }
                        onDelete()
                    }) {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(Color.red))
                    }
                }
            }
            .padding(.horizontal, 10)
            */
            
            // Foreground Card
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(backgroundColor.opacity(0.15))
                        .frame(width: 50, height: 50)

                    if let assetIconName = assetIconName {
                        Image(assetIconName)
                            .resizable()
                            .renderingMode(.template)
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 24, height: 24)
                            .foregroundColor(backgroundColor)
                    } else {
                        Image(systemName: iconName)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(backgroundColor)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    
                    Text(value)
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundColor(backgroundColor)
                        .padding(.top, 2)
                }
                
                Spacer()
                
                if showCopied {
                    Text("Copiado!")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                } else {
                    Menu {
                        if let onEdit = onEdit {
                            Button(action: onEdit) {
                                Label("Editar", systemImage: "pencil")
                            }
                        }
                        if let onDelete = onDelete {
                            Button(role: .destructive, action: onDelete) {
                                Label("Eliminar", systemImage: "trash")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle.fill")
                            .font(.title3)
                            .foregroundColor(.gray.opacity(0.4))
                    }
                }
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(16)
            // .offset(x: isSwiped ? -130 : (userData.activeSwipeID == id ? offset : 0)) // DISABLED: card offset
            .contentShape(Rectangle())
            /* // DISABLED: drag gesture
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if value.translation.width < 0 {
                            offset = value.translation.width
                            if userData.activeSwipeID != id {
                                userData.activeSwipeID = id
                            }
                        }
                    }
                    .onEnded { value in
                        withAnimation(.spring()) {
                            if value.translation.width < -60 {
                                offset = -130
                                userData.activeSwipeID = id
                            } else {
                                offset = 0
                                userData.activeSwipeID = nil
                            }
                        }
                    }
            )
            */
            .onTapGesture {
                if isSwiped {
                    withAnimation(.spring()) { 
                        offset = 0
                        userData.activeSwipeID = nil
                    }
                } else {
                    UIPasteboard.general.string = value
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    withAnimation { showCopied = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation { showCopied = false }
                    }
                }
            }
            .onChange(of: userData.activeSwipeID) { newValue in
                if newValue != id && offset != 0 {
                    withAnimation(.spring()) {
                        offset = 0
                    }
                }
            }
        }
    }
}

// MARK: - Wallet Card
struct WalletCard: View {
    let account: BankAccount
    var onEdit: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    
    @State private var showCopied = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(account.label)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white.opacity(0.8))
                    Text(account.group.isEmpty ? "Banco" : account.group)
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(4)
                        .foregroundColor(.white)
                }
                Spacer()
                Image(systemName: "creditcard.fill")
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(.bottom, 30)
            
            Spacer()
            
            // Card Number
            Text(maskCardNumber(account.cardNumber))
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .tracking(2)
            
            Spacer()
            
            // Footer
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("TITULAR")
                        .font(.system(size: 8, weight: .black))
                        .foregroundColor(.white.opacity(0.5))
                    Text(account.name.uppercased())
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                HStack(spacing: 12) {
                    if showCopied {
                        Text("COPIADO")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.green)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white)
                            .cornerRadius(6)
                    } else {
                        Button(action: {
                            UIPasteboard.general.string = account.cardNumber
                            let generator = UIImpactFeedbackGenerator(style: .medium)
                            generator.impactOccurred()
                            withAnimation { showCopied = true }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                withAnimation { showCopied = false }
                            }
                        }) {
                            Image(systemName: "doc.on.doc.fill")
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                }
            }
        }
        .padding(24)
        .frame(height: 200)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(hex: account.colorHex))
                .overlay(
                    LinearGradient(
                        colors: [Color.clear, Color.black.opacity(0.25)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.25), radius: 8, x: 0, y: 4)
    }
    
    private func maskCardNumber(_ number: String) -> String {
        let last4 = number.suffix(4)
        return "**** **** **** \(last4)"
    }
}

// MARK: - Activity View (Share Sheet Wrapper)
struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}


// MARK: - Document Picker (File Importer Wrapper)
import UniformTypeIdentifiers

struct DocumentPicker: UIViewControllerRepresentable {
    var onPick: (URL) -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.json])
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        var onPick: (URL) -> Void
        init(onPick: @escaping (URL) -> Void) { self.onPick = onPick }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            if url.startAccessingSecurityScopedResource() { onPick(url); url.stopAccessingSecurityScopedResource() }
        }
    }
}
