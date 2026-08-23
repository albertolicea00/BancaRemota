import SwiftUI
import LocalAuthentication

struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}

enum ActiveScreen: String {
    case home, bank, info, tutorial, config, cuentasBanco, cuentasNauta, misClaves, tasaCambio, cuentasServicios
}

// MARK: - Navigation Hub View
struct MainView: View {
    @State private var config: BankConfig?
    @AppStorage("selectedBankID") private var selectedBankID: String = ""
    @State private var isMenuOpen = false
    @AppStorage("activeScreen") private var activeScreen: ActiveScreen = .home
    @ObservedObject private var operationRunner = OperationRunner.shared
    
    private var selectedBank: Bank? {
        config?.banks.first { $0.id == selectedBankID }
    }
    
    var body: some View {
        ZStack(alignment: .leading) {
            // Main Content Area
            VStack(spacing: 0) {
                if let config = config {
                    switch activeScreen {
                    case .info:
                        HelpView(onMenuTap: { withAnimation { isMenuOpen.toggle() } })
                    case .tutorial:
                        TutorialView(onMenuTap: { withAnimation { isMenuOpen.toggle() } })
                    case .config:
                        ConfigView(banks: config.banks, onMenuTap: { withAnimation { isMenuOpen.toggle() } })
                    case .bank:
                        if let bank = selectedBank {
                            OperationsListView(bank: bank, allBanks: config.banks, onMenuTap: { withAnimation { isMenuOpen.toggle() } })
                        }
                    case .home:
                        BankSelectionView(banks: config.banks, onSelectBank: { bank in
                            selectedBankID = bank.id
                            activeScreen = .bank
                        }, onSelectScreen: { screen in
                            selectedBankID = ""
                            activeScreen = screen
                        }, onMenuTap: { withAnimation { isMenuOpen.toggle() } })
                    case .cuentasNauta:
                        NautaListView(onMenuTap: { withAnimation { isMenuOpen.toggle() } })
                    case .cuentasBanco:
                        BankAccountsListView(onMenuTap: { withAnimation { isMenuOpen.toggle() } })
                    case .misClaves:
                        KeysListView(onMenuTap: { withAnimation { isMenuOpen.toggle() } })
                    case .tasaCambio:
                        UnderConstructionView(title: "Tasa de Cambio", onMenuTap: { withAnimation { isMenuOpen.toggle() } })
                    case .cuentasServicios:
                        BillsListView(onMenuTap: { withAnimation { isMenuOpen.toggle() } })
                    }
                } else {
                    ProgressView("Loading Configuration...")
                        .onAppear {
                            // Initial configuration load
                            if let loadedConfig = DataService.shared.loadConfiguration() {
                                self.config = loadedConfig
                                
                                // Setup default favorites if it's the first run
                                if !UserDefaults.standard.bool(forKey: "didSetupDefaultFavorites") {
                                    FavoritesManager.shared.loadDefaults(from: loadedConfig.banks)
                                    UserDefaults.standard.set(true, forKey: "didSetupDefaultFavorites")
                                }
                            }
                        }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Side Drawer Overlay
            if isMenuOpen {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation {
                            isMenuOpen = false
                        }
                    }
                
                SideMenuView(
                    banks: config?.banks ?? [],
                    selectedBank: selectedBank,
                    activeScreen: activeScreen,
                    onSelectHome: {
                        selectedBankID = ""
                        activeScreen = .home
                        withAnimation { isMenuOpen = false }
                    },
                    onSelectBank: { bank in
                        selectedBankID = bank.id
                        activeScreen = .bank
                        withAnimation { isMenuOpen = false }
                    },
                    onSelectHelp: {
                        activeScreen = .info
                        withAnimation { isMenuOpen = false }
                    },
                    onSelectTutorial: {
                        activeScreen = .tutorial
                        withAnimation { isMenuOpen = false }
                    },
                    onSelectConfig: {
                        activeScreen = .config
                        withAnimation { isMenuOpen = false }
                    },
                    onSelectScreen: { screen in
                        selectedBankID = ""
                        activeScreen = screen
                        withAnimation { isMenuOpen = false }
                    }
                )
                .frame(width: 280)
                .transition(.move(edge: .leading))
            }
        }
        // Prefill picker for operations that need a saved value. Swiping it away cancels the operation.
        .sheet(item: $operationRunner.pendingSelection) { request in
            PrefillSelectionView(request: request) { option in
                operationRunner.completeSelection(option)
            }
        }
    }
}

// MARK: - Favorite Drop Delegate
struct FavoriteDropDelegate: DropDelegate {
    let item: FavoriteOperation
    @Binding var items: [FavoriteOperation]
    @Binding var draggedItem: FavoriteOperation?

    func performDrop(info: DropInfo) -> Bool {
        draggedItem = nil
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let draggedItem = draggedItem,
              draggedItem != item,
              let from = items.firstIndex(of: draggedItem),
              let to = items.firstIndex(of: item) else { return }
        
        if from != to {
            withAnimation(.default) {
                items.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
            }
        }
    }
}

// MARK: - Bank Selection Screen
struct BankSelectionView: View {
    let banks: [Bank]
    let onSelectBank: (Bank) -> Void
    let onSelectScreen: (ActiveScreen) -> Void
    let onMenuTap: () -> Void
    
    @AppStorage("showBanksInFavorites") private var showBanksInFavorites = true
    @AppStorage("useBanksAsLogin") private var useBanksAsLogin = true
    @AppStorage("showShortcutsInFavorites") private var showShortcutsInFavorites = false
    @AppStorage("useCustomFavoriteColor") private var useCustomFavoriteColor = true
    @AppStorage("favoriteCustomColorHex") private var favoriteCustomColorHex = "B38B4D"
    @ObservedObject private var favoritesManager = FavoritesManager.shared
    @State private var isShowingAddFavorite = false
    @State private var draggedItem: FavoriteOperation?
    
    var body: some View {
        VStack(spacing: 0) {
            TopNavBar(themeColor: Color(UIColor.systemBackground), onMenuTap: onMenuTap, isHome: true)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 30) {

                    // if showShortcutsInFavorites {
                    //     VStack(alignment: .leading, spacing: 15) {
                    //         Text("Atajos de Menú")
                    //             .font(.headline)
                    //             .foregroundColor(.secondary)
                    //             .padding(.horizontal)
                            
                    //         ScrollViewReader { proxy in
                    //             ScrollView(.horizontal, showsIndicators: false) {
                    //                 HStack(spacing: 20) {
                    //                     MenuShortcutCard(iconName: "doc.text.fill", title: "Servicios", themeColor: .appPrimary) { onSelectScreen(.cuentasServicios) }.id(1)
                    //                     MenuShortcutCard(iconName: "wifi", title: "Nauta", themeColor: .appPrimary) { onSelectScreen(.cuentasNauta) }.id(2)
                    //                     MenuShortcutCard(iconName: "building.columns.fill", title: "Cuentas", themeColor: .appPrimary) { onSelectScreen(.cuentasBanco) }.id(3)
                    //                     MenuShortcutCard(iconName: "key.fill", title: "Claves", themeColor: .appPrimary) { onSelectScreen(.misClaves) }.id(4)
                    //                     MenuShortcutCard(iconName: "arrow.left.arrow.right", title: "Cambio", themeColor: .appPrimary) { onSelectScreen(.tasaCambio) }.id(5)
                    //                 }
                    //                 .padding(.horizontal)
                    //                 .padding(.bottom, 10)
                    //             }
                    //             .onAppear {
                    //                 DispatchQueue.main.async {
                    //                     proxy.scrollTo(2, anchor: .center)
                    //                 }
                    //             }
                    //         }
                    //     }
                    //     .padding(.top, showBanksInFavorites ? 0 : 20)
                    // }

                    // if showBanksInFavorites { 
                        VStack(alignment: .leading, spacing: 15) {
                            HStack(alignment: .bottom) {
                                Text("Mis Bancos")
                                    .font(.headline)
                                
                                if useBanksAsLogin {
                                    Text("(toque para autenticarse)")
                                        .font(.caption)
                                        .italic()
                                }
                            }
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                            
                            if banks.count <= 3 {
                                HStack(spacing: 15) {
                                    ForEach(banks) { bank in
                                        BankSelectionCard(bank: bank) {
                                            if useBanksAsLogin,
                                               let authOp = bank.categories.flatMap({ $0.operations }).first(where: { $0.isLogin == true }) {
                                                OperationRunner.shared.run(authOp, bankId: bank.id)
                                            } else {
                                                onSelectBank(bank)
                                            }
                                        }
                                        .frame(maxWidth: .infinity)
                                        .aspectRatio(1, contentMode: .fit)
                                    }
                                }
                                .padding(.horizontal)
                            } else {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 15) {
                                        ForEach(banks) { bank in
                                            BankSelectionCard(bank: bank) {
                                                if useBanksAsLogin,
                                                   let authOp = bank.categories.flatMap({ $0.operations }).first(where: { $0.isLogin == true }) {
                                                    OperationRunner.shared.run(authOp, bankId: bank.id)
                                                } else {
                                                    onSelectBank(bank)
                                                }
                                            }
                                            .frame(width: 100)
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                        }
                        .padding(.top, 20)
                    // }
                    
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Operaciones Favoritas")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                        
                        if !favoritesManager.favoriteOperations.isEmpty {
                            LazyVStack(spacing: 12) {
                                ForEach(favoritesManager.favoriteOperations) { fav in
                                    if banks.contains(where: { $0.id == fav.bankId }) {
                                        let theme = Color.appPrimary
                                        let textColor = Color.white
                                        OperationCard(operation: fav.operation, themeColor: theme, textColor: textColor) {
                                            OperationRunner.shared.run(fav.operation, bankId: fav.bankId)
                                        }
                                        .onDrag {
                                            self.draggedItem = fav
                                            return NSItemProvider(object: fav.id as NSString)
                                        }
                                        .onDrop(of: [.plainText], delegate: FavoriteDropDelegate(item: fav, items: Binding(
                                            get: { favoritesManager.favoriteOperations },
                                            set: { favoritesManager.favoriteOperations = $0 }
                                        ), draggedItem: $draggedItem))
                                    }
                                }
                            }
                            .padding(.horizontal)
                        } else {
                            // Empty state
                            VStack(spacing: 10) {
                                Image(systemName: "star.slash")
                                    .font(.system(size: 40))
                                    .foregroundColor(.gray)
                                Text("No tienes operaciones favoritas")
                                    .font(.headline)
                                    .foregroundColor(.gray)
                                Text("Añade las operaciones que más usas para acceder rápido.")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 40)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                        }
                        
                        Button(action: { isShowingAddFavorite = true }) {
                            HStack {
                                Image(systemName: "pencil.circle.fill")
                                Text("Editar operaciones favoritas")
                            }
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.appPrimary)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                    }
                    .padding(.top, showShortcutsInFavorites ? 0 : 20)
                    .padding(.bottom, 30)
                    
                    Spacer()
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
            .sheet(isPresented: $isShowingAddFavorite) {
                AddFavoriteOperationView(banks: banks)
            }
        }
    }
}

// MARK: - Bank Specific Operations List
struct OperationsListView: View {
    let bank: Bank
    let allBanks: [Bank]
    let onMenuTap: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            TopNavBar(themeColor: bank.themeColor, onMenuTap: onMenuTap, bank: bank)
            
            ScrollView {
                VStack(spacing: 0) {
                    Spacer().frame(height: 20)
                    
                    // Categorized Operations
                    LazyVStack(spacing: 20, pinnedViews: [.sectionHeaders]) {
                        ForEach(bank.categories) { category in
                            Section(header: 
                                Text(category.name.uppercased())
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.gray)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal)
                                    .background(Color(UIColor.systemGroupedBackground))
                            ) {
                                VStack(spacing: 12) {
                                    ForEach(category.operations) { operation in
                                        OperationCard(operation: operation, themeColor: bank.themeColor, textColor: bank.textColor) {
                                            // Prepare whatever the USSD will ask for (if any), then dial
                                            OperationRunner.shared.run(operation, bankId: bank.id)
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
        }
    }
}

// MARK: - Main Side Drawer Menu
struct SideMenuView: View {
    let banks: [Bank]
    let selectedBank: Bank?
    let activeScreen: ActiveScreen
    let onSelectHome: () -> Void
    let onSelectBank: (Bank) -> Void
    let onSelectHelp: () -> Void
    let onSelectTutorial: () -> Void
    let onSelectConfig: () -> Void
    let onSelectScreen: (ActiveScreen) -> Void
    
    var body: some View {
        ZStack(alignment: .leading) {
            Color(UIColor.systemBackground).ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 30) {
                // App Logo Large
                Button(action: onSelectHome) {
                    Image("AppLogoL")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 20)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.top, 30)
                                
                // Link Items
                VStack(alignment: .leading, spacing: 25) {
                    MenuRow(iconColor: .appPrimary, imageName: nil, systemImageName: "star.fill", title: "Favoritos", isSelected: activeScreen == .home) {
                        onSelectHome()
                    }
                    
                    Divider().padding(.trailing, 40)
                    
                    ForEach(banks) { bank in
                        MenuRow(iconColor: .appPrimary, imageName: bank.iconImg, systemImageName: nil, title: bank.shortName.uppercased(), isSelected: activeScreen == .bank && selectedBank?.id == bank.id) {
                            onSelectBank(bank)
                        }
                    }
                    
                    Divider().padding(.trailing, 40)
                    MenuRow(iconColor: .appPrimary, imageName: nil, systemImageName: "doc.text.fill", title: "Cuentas de Servicios", isSelected: activeScreen == .cuentasServicios) { onSelectScreen(.cuentasServicios) }
                    MenuRow(iconColor: .appPrimary, imageName: nil, systemImageName: "wifi", title: "Cuentas de Nauta", isSelected: activeScreen == .cuentasNauta) { onSelectScreen(.cuentasNauta) }
                    MenuRow(iconColor: .appPrimary, imageName: nil, systemImageName: "building.columns.fill", title: "Cuentas de Banco", isSelected: activeScreen == .cuentasBanco) { onSelectScreen(.cuentasBanco) }

                    
                    Divider().padding(.trailing, 40)
                    MenuRow(iconColor: .appPrimary, imageName: nil, systemImageName: "key.fill", title: "Mis Claves", isSelected: activeScreen == .misClaves) { onSelectScreen(.misClaves) }

                    Divider().padding(.trailing, 40)
                    MenuRow(iconColor: .appPrimary, imageName: nil, systemImageName: "arrow.left.arrow.right", title: "Tasa de Cambio", isSelected: activeScreen == .tasaCambio) { onSelectScreen(.tasaCambio) }

                    Divider().padding(.trailing, 40)
                    MenuRow(iconColor: .appPrimary, imageName: nil, systemImageName: "info.circle", title: "Información", isSelected: activeScreen == .info) {
                        onSelectHelp()
                    }
                    MenuRow(iconColor: .appPrimary, imageName: nil, systemImageName: "questionmark.circle", title: "Ayuda", isSelected: activeScreen == .tutorial) {
                        onSelectTutorial()
                    }
                    MenuRow(iconColor: .appPrimary, imageName: nil, systemImageName: "gearshape", title: "Configuración", isSelected: activeScreen == .config) {
                        onSelectConfig()
                    }

                }
                .padding(.leading, 30)
                
                Spacer()
            }
        }
        .gesture(
            DragGesture()
                .onEnded { value in
                    if value.translation.width < -50 {
                        onSelectHome()
                    }
                }
        )
    }
}

// MARK: - Help and About View
struct HelpView: View {
    let onMenuTap: () -> Void
    @State private var showingShareSheet = false
    @State private var shareURL: URL? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            TopNavBar(themeColor: Color(UIColor.systemBackground), onMenuTap: onMenuTap, title: "Información")
            
            ScrollView {
                VStack(alignment: .leading, spacing: 25) {
                    Group {
                        HelpSection(title: "Sobre la Aplicación", content: "Banca Remota es una utilidad nativa para iPhone que permite ejecutar operaciones bancarias en Cuba mediante códigos USSD sin necesidad de internet. Incluye un gestor local para tarjetas, cuentas nauta, cuentas de servicios y contraseñas.")

                        HelpSection(title: "¿Qué es USSD?", content: "USSD (Servicio Suplementario de Datos No Estructurados) es un protocolo de telefonía que permite interactuar con el banco marcando códigos especiales como *5#. No requiere datos móviles ni Wi-Fi, funciona con cualquier señal de voz.\n\nAl tocar una operación en la app, se abre automáticamente el marcador del sistema con el código correspondiente listo para marcar.")

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Contacto y Colaboración")
                                .font(.headline)
                                .foregroundColor(.appPrimary)

                            Link(destination: URL(string: "https://www.linkedin.com/in/albertolicea00")!) {
                                Label("Alberto Licea (Desarrollador)", systemImage: "person.circle")
                            }
                            .foregroundColor(.blue)

                            Link(destination: URL(string: "https://github.com/albertolicea00/BancaRemota")!) {
                                Label("Código Fuente en GitHub", systemImage: "terminal")
                            }
                            .foregroundColor(.blue)
                            .padding(.top, 2)

                            Text("Puedes colaborar sugiriendo mejoras, reportando errores o aportando actualizaciones de los códigos USSD.")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .padding(.top, 2)

                            Divider().padding(.top, 5)
                        }

                        HelpSection(title: "Nuestro Compromiso", content: "Esta aplicación se mantendrá ligera, sencilla y rápida. El objetivo es que funcione en todos los dispositivos Apple, incluso en los más antiguos, sin requerir actualizaciones de hardware para acceder a tu banco.")

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Créditos")
                                .font(.headline)
                                .foregroundColor(.appPrimary)

                            Link(destination: URL(string: "https://www.linkedin.com/in/henrycruzmederos")!) {
                                Label("Henry Cruz (Creador de la app original)", systemImage: "link")
                            }
                            .font(.body)
                            .foregroundColor(.gray)

                            Divider().padding(.top, 5)
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Datos de la Aplicación")
                                .font(.headline)
                                .foregroundColor(.appPrimary)

                            Text("La aplicación utiliza una base de datos local para los códigos USSD. Puedes descargar este archivo para revisarlo o compartirlo.")
                                .font(.caption)
                                .foregroundColor(.gray)

                            Button(action: {
                                if let url = Bundle.main.url(forResource: "codes", withExtension: "json") {
                                    shareURL = url
                                    showingShareSheet = true
                                }
                            }) {
                                Label("Exportar BBDD de códigos USSD", systemImage: "square.and.arrow.up")
                                    .font(.body)
                                    .foregroundColor(.blue)
                            }
                            .padding(.top, 2)

                            Divider().padding(.top, 10)
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Privacidad y Seguridad")
                                .font(.headline)
                                .foregroundColor(.appPrimary)

                            VStack(alignment: .leading, spacing: 8) {
                                Label("Cifrado militar (AES-GCM) para la nube", systemImage: "lock.shield")
                                Label("Sin servidores ni cuentas externas", systemImage: "server.rack")
                                Label("Tú controlas tus archivos de respaldo", systemImage: "archivebox")
                                Label("Sin publicidad ni rastreo", systemImage: "eye.slash")
                                Label("Acceso protegido por Face ID / Touch ID", systemImage: "faceid")
                            }
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                            Text("Tus datos están protegidos localmente por iOS. Si habilitas la sincronización con iCloud, la app cifra tu información con tu contraseña personal de forma que solo tú (y nadie más, ni siquiera Apple) pueda ver tus datos.")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .padding(.top, 4)

                            Divider().padding(.top, 5)
                        }
                    }

                    Spacer(minLength: 20)

                    Text("Versión \(AppVersion) (\(AppBuild))")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity)
                }
                .padding(25)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .sheet(isPresented: $showingShareSheet) {
                if let url = shareURL {
                    ActivityView(activityItems: [url])
                }
            }
        }
    }
}

struct HelpSection: View {
    let title: String
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .foregroundColor(.appPrimary)
            
            Text(content)
                .font(.body)
                .foregroundColor(.primary.opacity(0.8))
                .lineSpacing(4)
            
            Divider().padding(.top, 5)
        }
    }
}

// MARK: - Reusable Menu Item Component
struct MenuRow: View {
    let iconColor: Color
    let imageName: String?
    let systemImageName: String?
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 15) {
                if let imageName = imageName {
                    Image(imageName)
                        .resizable()
                        .renderingMode(.template)
                        .foregroundColor(isSelected ? .primary : iconColor)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24)
                        .cornerRadius(6)
                } else if let systemName = systemImageName {
                    Image(systemName: systemName)
                        .font(.system(size: 20))
                        .foregroundColor(isSelected ? .primary : iconColor)
                        .frame(width: 24, height: 24)
                } else {
                    Circle()
                        .fill(isSelected ? .primary : iconColor)
                        .frame(width: 24, height: 24)
                }
                
                Text(title)
                    .font(.system(size: 18))
                    .foregroundColor(isSelected ? .primary : Color.gray.opacity(0.8))
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Tutorial View (Ayuda)
struct TutorialView: View {
    let onMenuTap: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            TopNavBar(themeColor: Color(UIColor.systemBackground), onMenuTap: onMenuTap, title: "Ayuda")
            
            ScrollView {
                VStack(alignment: .leading, spacing: 25) {
                    Text("Cómo usar la aplicación")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.appPrimary)
                        .padding(.bottom, 10)

                    HelpSection(title: "Operaciones bancarias", content: "Selecciona tu banco desde la pantalla de inicio o el menú lateral. Verás las operaciones organizadas por categorías: Sesión, Consultas, Transferencias, etc. Al tocar cualquiera, se abre el marcador del teléfono con el código USSD listo. Solo confirma la llamada.")

                    HelpSection(title: "Primera vez: Sesión", content: "Antes de consultar saldo o hacer transferencias, debes autenticarte en el banco. Busca la categoría 'Sesión' o 'Inicio de sesión' dentro de tu banco y ejecuta esa operación primero. Cada banco puede requerir tu número de tarjeta o móvil durante el proceso USSD.")

                    HelpSection(title: "Favoritos", content: "Desde Inicio puedes agregar operaciones frecuentes a Favoritos para acceder a ellas sin navegar por el banco. Mantén pulsado y arrastra para reordenarlas. Puedes personalizar el color de las tarjetas favoritas desde Configuración.")

                    HelpSection(title: "Gestión de Tarjetas", content: "En 'Cuentas de Banco' puedes guardar los datos de tus tarjetas (número, titular, móvil asociado). Los números se muestran enmascarados pero puedes copiarlos al portapapeles. Toca una tarjeta para ver todos los detalles.")

                    HelpSection(title: "Cuentas Nauta", content: "Guarda tus usuarios de Nauta (Nacional e Internacional) organizados por grupos. Útil para tener a mano los usuarios al recargar o consultar saldo mediante USSD.")

                    HelpSection(title: "Facturas de Servicios", content: "En 'Cuentas de Servicios' puedes guardar los números de contrato de electricidad, agua, gas y teléfono. Cópialos fácilmente cuando los necesites para una operación USSD de pago.")

                    HelpSection(title: "Mis Claves", content: "Guarda PINs, contraseñas y claves de forma local. Esta sección solo está disponible si tienes activada la autenticación biométrica en Configuración, como medida de seguridad adicional.")

                    HelpSection(title: "Autenticación", content: "Desde Configuración puedes activar Face ID / Touch ID para proteger la entrada a la app. También puedes ajustar el tiempo de expiración de sesión (desde inmediato hasta 15 minutos).")
                    
                    HelpSection(title: "Respaldo de Datos", content: "En Configuración puedes generar archivos de respaldo (.json) para exportar tus cuentas y claves. Puedes guardar estos archivos en tu dispositivo o compartirlos. Para restaurar tu información, utiliza el botón 'Importar' y selecciona tu archivo de respaldo.")

                    HelpSection(title: "Sincronización y Cifrado", content: "Activa 'Sincronización con iCloud' en Configuración para mantener tus datos sincronizados entre todos tus dispositivos Apple. Deberás configurar una contraseña de cifrado: tus datos se cifran localmente antes de subirse a la nube, garantizando que solo tú puedas acceder a ellos.")

                    Spacer()

                    Text("Versión \(AppVersion) (\(AppBuild))")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity)
                }
                .padding(25)
            }
            .background(Color(UIColor.systemGroupedBackground))
        }
    }
}

// MARK: - Config View
struct ConfigView: View {
    let banks: [Bank]
    let onMenuTap: () -> Void
    @ObservedObject var userData = UserDataManager.shared
    
    @AppStorage("darkModePreference") private var darkMode: Int = 0 // 0 = Default, 1 = Light, 2 = Dark
    @AppStorage("liquidGlassEnabled") private var liquidGlass = false
    @AppStorage("authEnabled") private var authEnabled: Bool = false
    @AppStorage("authExpiration") private var authExpiration: Double = 1.0 // 1 min, 5 min, etc.
    @AppStorage("lastAuthTime") private var lastAuthTime: Double = 0
    
    @AppStorage("showNetworkStatus") private var showNetworkStatus = false
    @AppStorage("useBankNameInsteadOfIcon") private var useBankNameInsteadOfIcon = false
    @AppStorage("showBanksInFavorites") private var showBanksInFavorites = true
    @AppStorage("useBanksAsLogin") private var useBanksAsLogin = true
    @AppStorage("showShortcutsInFavorites") private var showShortcutsInFavorites = true
    
    @AppStorage("useCustomFavoriteColor") private var useCustomFavoriteColor = true
    @AppStorage("favoriteCustomColorHex") private var favoriteCustomColorHex = "B38B4D"
    @AppStorage("authKeyCopyMode") private var authKeyCopyMode: Int = PrefillCopyMode.copyAndNotify.rawValue
    @AppStorage("billCopyMode") private var billCopyMode: Int = PrefillCopyMode.copyAndNotify.rawValue
    @AppStorage("nautaCopyMode") private var nautaCopyMode: Int = PrefillCopyMode.copyAndNotify.rawValue
    @AppStorage("cardCopyMode") private var cardCopyMode: Int = PrefillCopyMode.copyAndNotify.rawValue
    @AppStorage("contactCopyMode") private var contactCopyMode: Int = PrefillCopyMode.copyAndNotify.rawValue

    @State private var pendingAuthEnabled: Bool = false
    @State private var selectedFavoriteColor: Color = .appPrimary
    
    @State private var showingResetAlert = false
    @State private var isResetting = false
    @State private var showResetSuccess = false
    
    @State private var showingBackupSheet = false
    @State private var showingFilePicker = false
    @State private var showingImportAlert = false
    @State private var backupURL: IdentifiableURL? = nil
    
    @State private var includeNauta = true
    @State private var includeBanks = true
    @State private var includeBills = true
    @State private var includeKeys = true
    
    @State private var isImporting = false
    @State private var showImportSuccess = false
    @State private var showImportError = false
    
    @State private var showingPasswordSheet = false
    @State private var tempPassword = ""
    @State private var showSyncPassword = false
    @State private var showingDisableICloudAlert = false
    
    var body: some View {
        VStack(spacing: 0) {
            TopNavBar(themeColor: Color(UIColor.systemBackground), onMenuTap: onMenuTap, title: "Configuración")
            
            Form {
                Section(header: Text("Apariencia")) {
                    Picker("Tema Visual", selection: $darkMode) {
                        Text("Por defecto").tag(0)
                        Text("Modo Claro").tag(1)
                        Text("Modo Oscuro").tag(2)
                    }
                    
                    // Toggle("Modo Liquid Glass", isOn: $liquidGlass)
                    
                    Toggle("Usar color de acento personalizado", isOn: $useCustomFavoriteColor)
                    if useCustomFavoriteColor {
                        ColorPicker("Color de acento global", selection: $selectedFavoriteColor)
                            .onChange(of: selectedFavoriteColor) { newColor in
                                if let hex = newColor.toHex() {
                                    favoriteCustomColorHex = hex
                                }
                            }
                    }
                }
                
                Section(header: Text("General y Preferencias")) {
                    Toggle("Aviso de estado de conexión", isOn: $showNetworkStatus)
                    Toggle("Mostrar nombre de banco en vez de icono", isOn: $useBankNameInsteadOfIcon)
                    // Toggle("Mostrar atajos de menú en favoritos", isOn: $showShortcutsInFavorites)
                    // Toggle("Mostrar bancos en favoritos", isOn: $showBanksInFavorites)
                    // Toggle("Usar bancos en favoritos como inicio de sesión", isOn: $useBanksAsLogin)
                    //     .disabled(!showBanksInFavorites)
                }
                
                Section(header: Text("Autenticación en el banco"), footer: Text("Al ejecutar una operación de autenticación, la app copia al portapapeles la clave especial de ese banco (categorías «PIN BPA», «PIN BANDEC» y «PIN BM» en Mis Claves) para que la pegues cuando el USSD la pida. La copia se borra sola a los 2 minutos y no se sincroniza con otros dispositivos.")) {
                    Picker("Clave al autenticarse", selection: $authKeyCopyMode) {
                        ForEach(PrefillCopyMode.allCases) { mode in
                            Text(mode.directLabel).tag(mode.rawValue)
                        }
                    }
                }

                Section(header: Text("Pago de facturas"), footer: Text("Al pagar electricidad, teléfono, agua o gas, la app lista tus cuentas de servicio guardadas de ese tipo para copiar el número al portapapeles antes de marcar. Siempre puedes elegir «Ninguno» y marcar sin copiar.")) {
                    Picker("Cuentas guardadas", selection: $billCopyMode) {
                        ForEach(PrefillCopyMode.allCases) { mode in
                            Text(mode.pickerLabel).tag(mode.rawValue)
                        }
                    }
                }

                Section(header: Text("Recarga Nauta"), footer: Text("Al recargar Nauta, la app lista tus cuentas Nauta guardadas para copiar el usuario al portapapeles antes de marcar.")) {
                    Picker("Cuentas guardadas", selection: $nautaCopyMode) {
                        ForEach(PrefillCopyMode.allCases) { mode in
                            Text(mode.pickerLabel).tag(mode.rawValue)
                        }
                    }
                }

                Section(header: Text("Transferencias"), footer: Text("Al transferir, la app lista tus tarjetas guardadas para copiar el número al portapapeles antes de marcar.")) {
                    Picker("Tarjetas guardadas", selection: $cardCopyMode) {
                        ForEach(PrefillCopyMode.allCases) { mode in
                            Text(mode.pickerLabel).tag(mode.rawValue)
                        }
                    }
                }

                Section(header: Text("Recarga de móvil"), footer: Text("Al recargar un móvil, la app lista tus contactos dentro de la propia app, con buscador, para copiar el número antes de marcar. Requiere permiso de Contactos; se leen solo en ese momento, no se guardan ni se envían a ningún sitio.")) {
                    Picker("Contactos del teléfono", selection: $contactCopyMode) {
                        ForEach(PrefillCopyMode.allCases) { mode in
                            Text(mode.pickerLabel).tag(mode.rawValue)
                        }
                    }
                }

                Section(header: Text("Seguridad y Autenticación"), footer: Text("Protege el acceso a la aplicación usando la seguridad nativa de tu dispositivo (Face ID, Touch ID o Código).")) {
                    Toggle("Requerir Autenticación", isOn: $pendingAuthEnabled)
                    
                    if authEnabled {
                        Picker("Expirar Sesión", selection: $authExpiration) {
                            Text("Inmediato").tag(0.0)
                            Text("En 30 segundos").tag(0.5)
                            Text("En 1 minuto").tag(1.0)
                            Text("En 5 minutes").tag(5.0)
                            Text("En 15 minutes").tag(15.0)
                        }
                    }
                }
                
                Section(header: Text("Respaldo y Privacidad"), footer: Text(authEnabled ? "Mantén tus datos sincronizados y seguros. Exporta tus datos para tener una copia de seguridad o impórtalos para restaurar tu información." : "⚠️ Debes activar 'Requerir Autenticación' en la sección de Seguridad para usar las funciones de respaldo y sincronización.")) {
                    Group {
                        Toggle(isOn: $userData.iCloudSyncEnabled) {
                            VStack(alignment: .leading, spacing: 4) {
                                Label("Sincronización con iCloud", systemImage: "cloud.fill")
                                Text("Sincroniza tus cuentas y claves entre dispositivos de forma automática.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .onChange(of: userData.iCloudSyncEnabled) { newValue in
                            if newValue && userData.iCloudEncryptionPassword.isEmpty {
                                showingPasswordSheet = true
                            } else if !newValue {
                                showingDisableICloudAlert = true
                            }
                        }

                        if userData.iCloudSyncEnabled {
                            Button(action: { showingPasswordSheet = true }) {
                                HStack {
                                    Label("Contraseña de Cifrado", systemImage: "lock.shield.fill")
                                    Spacer()
                                    Text(userData.iCloudEncryptionPassword.isEmpty ? "No configurada" : "••••••••")
                                        .foregroundColor(.secondary)
                                }
                            }
                            .foregroundColor(.red)
                        }

                        Button(action: { showingBackupSheet = true }) {
                            Label("Exportar Mis Datos (Backup)", systemImage: "square.and.arrow.up")
                        }
                        .foregroundColor(authEnabled ? .appPrimary : .secondary)

                        Button(action: { showingImportAlert = true }) {
                            HStack {
                                Label("Importar Datos desde Archivo", systemImage: "square.and.arrow.down")
                                Spacer()
                                if isImporting {
                                    ProgressView()
                                } else if showImportSuccess {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                }
                            }
                        }
                        .foregroundColor(authEnabled ? .appPrimary : .secondary)
                        .disabled(isImporting)
                    }
                    .disabled(!authEnabled)
                    .opacity(authEnabled ? 1.0 : 0.6)
                }

                Section(header: Text("Gestión de Datos"), footer: Text("Al importar un archivo o restablecer favoritos, se sobrescribirán los datos actuales correspondientes.")) {
                    Button(action: {
                        showingResetAlert = true
                    }) {
                        HStack {
                            Label("Cargar Favoritos por Defecto", systemImage: "arrow.counterclockwise.circle")
                            Spacer()
                            if isResetting {
                                ProgressView()
                            } else if showResetSuccess {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }
                        .foregroundColor(.appPrimary)
                    }
                    .disabled(isResetting)
                }

                Section(footer: Text("Versión \(AppVersion) (\(AppBuild))")
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                ) {}
            }
            .alert(isPresented: $showingResetAlert) {
                Alert(
                    title: Text("¿Restablecer favoritos?"),
                    message: Text("Se perderán los favoritos actuales y se reemplazarán por la distribución por defecto."),
                    primaryButton: .destructive(Text("Restablecer")) {
                        resetFavorites()
                    },
                    secondaryButton: .cancel(Text("Cancelar"))
                )
            }
            .alert("¿Importar datos?", isPresented: $showingImportAlert) {
                Button("Cancelar", role: .cancel) {}
                Button("Seleccionar Archivo", role: .destructive) {
                    showingFilePicker = true
                }
            } message: {
                Text("Esta acción sobrescribirá tus cuentas y claves actuales con los datos del archivo de respaldo. ¿Deseas continuar?")
            }
            .sheet(isPresented: $showingBackupSheet) {
                NavigationView {
                    Form {
                        Section(header: Text("Selecciona qué incluir")) {
                            Toggle("Cuentas Nauta", isOn: $includeNauta)
                            Toggle("Cuentas Bancarias", isOn: $includeBanks)
                            Toggle("Cuentas de Servicios", isOn: $includeBills)
                            Toggle("Mis Claves (PINs/Passwords)", isOn: $includeKeys)
                        }
                        
                        Section(footer: Text("Se generará un archivo JSON con los datos seleccionados que podrás guardar o compartir.")) {
                            Button(action: {
                                if let url = UserDataManager.shared.createBackup(includeNauta: includeNauta, includeBanks: includeBanks, includeBills: includeBills, includeKeys: includeKeys) {
                                    backupURL = IdentifiableURL(url: url)
                                    showingBackupSheet = false
                                }
                            }) {
                                Label("Generar Archivo de Respaldo", systemImage: "doc.badge.plus")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.appPrimary)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                        }
                    }
                    .navigationTitle("Exportar Datos")
                    .navigationBarItems(trailing: Button("Cerrar") { showingBackupSheet = false })
                }
            }
            .sheet(item: $backupURL) { item in
                ActivityView(activityItems: [item.url])
            }
            .sheet(isPresented: $showingFilePicker) {
                DocumentPicker { url in
                    isImporting = true
                    showImportSuccess = false
                    showImportError = false
                    
                    // Small delay to simulate processing and give visual feedback
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        let success = UserDataManager.shared.importBackup(from: url)
                        isImporting = false
                        if success {
                            showImportSuccess = true
                            // Clear success icon after a few seconds
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                showImportSuccess = false
                            }
                        } else {
                            showImportError = true
                        }
                    }
                }
            }
            .sheet(isPresented: $showingPasswordSheet) {
                NavigationView {
                    Form {
                        Section(header: Text("Cifrado Extremo a Extremo"), footer: Text("Esta contraseña se usará para cifrar tus datos antes de enviarlos a iCloud. Deberás introducir la misma contraseña en tus otros dispositivos para poder sincronizar los datos.")) {
                            HStack {
                                Text("Servicio")
                                Spacer()
                                TextField("", text: .constant("BancaRemota_CloudSync"))
                                    .textContentType(.username)
                                    .disabled(true)
                                    .multilineTextAlignment(.trailing)
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack {
                                ZStack(alignment: .leading) {
                                    TextField("Contraseña de Sincronización", text: $tempPassword)
                                        .textContentType(.password)
                                        .autocapitalization(.none)
                                        .disableAutocorrection(true)
                                        .opacity(showSyncPassword ? 1 : 0)
                                        .disabled(!showSyncPassword)
                                    
                                    SecureField("Contraseña de Sincronización", text: $tempPassword)
                                        .textContentType(.password)
                                        .opacity(showSyncPassword ? 0 : 1)
                                        .disabled(showSyncPassword)
                                }
                                
                                Button(action: { showSyncPassword.toggle() }) {
                                    Image(systemName: showSyncPassword ? "eye.slash" : "eye")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        
                        Button("Guardar Contraseña") {
                            userData.iCloudEncryptionPassword = tempPassword
                            showingPasswordSheet = false
                            // Trigger a save to push encrypted data to iCloud
                            UserDataManager.shared.iCloudSyncEnabled = true 
                        }
                        .disabled(tempPassword.count < 4)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                    }
                    .navigationTitle("Configurar Cifrado")
                    .navigationBarItems(leading: Button("Cancelar") { 
                        if userData.iCloudEncryptionPassword.isEmpty {
                            userData.iCloudSyncEnabled = false
                        }
                        showingPasswordSheet = false 
                    })
                }
            }
            .alert("Sincronización desactivada", isPresented: $showingDisableICloudAlert) {
                Button("Entendido", role: .cancel) {}
            } message: {
                Text("La aplicación dejará de enviar y recibir cambios de iCloud. Tus datos actuales se mantendrán en este dispositivo, pero no se actualizarán en otros dispositivos hasta que vuelvas a activarla.")
            }
            .alert("Error de Importación", isPresented: $showImportError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("No se pudo leer el archivo de respaldo. Asegúrate de que sea un archivo válido generado por esta aplicación.")
            }
            .onChange(of: pendingAuthEnabled) { newValue in
                guard newValue != authEnabled else { return }
                
                let context = LAContext()
                var error: NSError?
                
                if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
                    context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Confirma para cambiar la seguridad") { success, _ in
                        DispatchQueue.main.async {
                            if success {
                                authEnabled = newValue
                                lastAuthTime = Date().timeIntervalSince1970
                                AuthManager.shared.isAuthenticated = true
                            } else {
                                pendingAuthEnabled = authEnabled // Revert
                            }
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        authEnabled = newValue
                        lastAuthTime = Date().timeIntervalSince1970
                    }
                }
            }
            .onChange(of: authExpiration) { _ in
                lastAuthTime = Date().timeIntervalSince1970
            }
            .onAppear {
                pendingAuthEnabled = authEnabled
                selectedFavoriteColor = Color(hex: favoriteCustomColorHex)
            }
        }
    }

    private func resetFavorites() {
        isResetting = true
        
        // Simulate short loading
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            FavoritesManager.shared.loadDefaults(from: banks)
            isResetting = false
            showResetSuccess = true
            
            // Hide success checkmark after 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                showResetSuccess = false
            }
        }
    }
}

// MARK: - Under Construction View
struct UnderConstructionView: View {
    let title: String
    let onMenuTap: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            TopNavBar(themeColor: Color(UIColor.systemBackground), onMenuTap: onMenuTap, title: title)
            
            VStack(spacing: 20) {
                Spacer()
                Image(systemName: "hammer.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.appPrimary)
                Text("En Construcción")
                    .font(.title)
                    .fontWeight(.bold)
                Text("Esta sección estará disponible en futuras actualizaciones de la aplicación. ¡Gracias por la espera!")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 40)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(UIColor.systemGroupedBackground))
        }
    }
}

// MARK: - Add Favorite Operation View
struct AddFavoriteOperationView: View {
    @Environment(\.presentationMode) var presentationMode
    let banks: [Bank]
    @ObservedObject var favoritesManager = FavoritesManager.shared
    @State private var searchText = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Help text
                Text("Toca una operación para marcarla o desmarcarla como favorita.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                    .padding(.top, 5)
                    .padding(.leading, -5)

                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Buscar operación o banco...", text: $searchText)
                        .disableAutocorrection(true)
                    
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(10)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.vertical, 10)
                
                List {
                    ForEach(banks) { bank in
                        ForEach(bank.categories) { category in
                            let filteredOperations = category.operations.filter { operation in
                                searchText.isEmpty || 
                                operation.name.localizedCaseInsensitiveContains(searchText) ||
                                operation.description.localizedCaseInsensitiveContains(searchText) ||
                                bank.shortName.localizedCaseInsensitiveContains(searchText)
                            }
                            
                            if !filteredOperations.isEmpty {
                                Section(header: Text("\(bank.shortName.uppercased()) - \(category.name)")) {
                                    ForEach(filteredOperations) { operation in
                                        let isFavorite = favoritesManager.favoriteOperations.contains(where: { $0.id == "\(bank.id)_\(operation.id)" })
                                        
                                        Button(action: {
                                            if isFavorite {
                                                favoritesManager.favoriteOperations.removeAll(where: { $0.id == "\(bank.id)_\(operation.id)" })
                                            } else {
                                                favoritesManager.favoriteOperations.append(FavoriteOperation(bankId: bank.id, operation: operation))
                                            }
                                        }) {
                                            HStack(spacing: 15) {
                                                Image(systemName: operation.iconName)
                                                    .foregroundColor(bank.themeColor)
                                                    .frame(width: 25)
                                                
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text(operation.name)
                                                        .foregroundColor(.primary)
                                                    Text(operation.description)
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                        .lineLimit(1)
                                                }
                                                
                                                Spacer()
                                                
                                                if isFavorite {
                                                    Image(systemName: "star.fill")
                                                        .foregroundColor(.appPrimary)
                                                } else {
                                                    Image(systemName: "plus.circle")
                                                        .foregroundColor(.secondary)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Editar Favoritos")
            .navigationBarItems(trailing: Button("Cerrar") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

// MARK: - Nauta Accounts List
struct NautaListView: View {
    let onMenuTap: () -> Void
    @ObservedObject var userData = UserDataManager.shared
    @State private var showingAddAccount = false
    @State private var accountToEdit: NautaAccount?
    @State private var accountToDelete: NautaAccount?
    @State private var showingDeleteAlert = false
    
    var body: some View {
        VStack(spacing: 0) {
            TopNavBar(themeColor: .appPrimary, onMenuTap: onMenuTap, title: "Cuentas Nauta")
            
            List {
                if userData.nautaAccounts.isEmpty {
                    EmptyStateView(title: "Sin cuentas Nauta", message: "Agrega tus cuentas para tenerlas a mano.", iconName: "wifi")
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                } else {
                    let grouped = Dictionary(grouping: userData.nautaAccounts, by: { $0.group.isEmpty ? "General" : $0.group })
                    
                    ForEach(grouped.keys.sorted(), id: \.self) { groupName in
                        Section(header: Text(groupName.uppercased())
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.secondary)) {
                            
                            ForEach(grouped[groupName] ?? []) { account in
                                DataCard(
                                    id: account.id,
                                    title: account.label,
                                    subtitle: account.type,
                                    value: account.account,
                                    iconName: "person.crop.circle",
                                    backgroundColor: .appPrimary,
                                    onEdit: { accountToEdit = account },
                                    onDelete: { 
                                        accountToDelete = account
                                        showingDeleteAlert = true
                                    }
                                )
                                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .background(Color(UIColor.systemGroupedBackground))
            
            Button(action: { showingAddAccount = true }) {
                Label("Nueva Cuenta Nauta", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.appPrimary)
                    .cornerRadius(12)
                    .padding()
            }
        }
        .sheet(isPresented: $showingAddAccount) {
            AddNautaAccountView()
        }
        .sheet(item: $accountToEdit) { account in
            AddNautaAccountView(accountToEdit: account)
        }
        .alert("¿Eliminar cuenta?", isPresented: $showingDeleteAlert) {
            Button("Cancelar", role: .cancel) {}
            Button("Eliminar", role: .destructive) {
                if let account = accountToDelete {
                    userData.nautaAccounts.removeAll { $0.id == account.id }
                }
            }
        } message: {
            Text("Esta acción no se puede deshacer.")
        }
    }
}

// MARK: - Bank Accounts List
struct BankAccountsListView: View {
    let onMenuTap: () -> Void
    @ObservedObject var userData = UserDataManager.shared
    @State private var showingAddAccount = false
    @State private var accountToEdit: BankAccount?
    @State private var accountToDelete: BankAccount?
    @State private var showingDeleteAlert = false
    @State private var selectedAccountForDetail: BankAccount?
    
    var body: some View {
        VStack(spacing: 0) {
            TopNavBar(themeColor: .appPrimary, onMenuTap: onMenuTap, title: "Cuentas de Banco")
            
            ScrollView {
                if userData.bankAccounts.isEmpty {
                    EmptyStateView(title: "Sin cuentas bancarias", message: "Guarda tus números de tarjeta y móviles aquí.", iconName: "building.columns")
                        .padding(.top, 100)
                } else {
                    let grouped = Dictionary(grouping: userData.bankAccounts, by: { $0.group.isEmpty ? "Mis Tarjetas" : $0.group })
                    
                    VStack(spacing: 40) {
                        ForEach(grouped.keys.sorted(), id: \.self) { groupName in
                            VStack(alignment: .leading, spacing: 15) {
                                Text(groupName.uppercased())
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 20)
                                
                                let accounts = grouped[groupName] ?? []
                                VStack(spacing: 12) {
                                    ForEach(accounts) { account in
                                        WalletCard(account: account)
                                            .padding(.horizontal)
                                            .onTapGesture {
                                                selectedAccountForDetail = account
                                            }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical)
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
            
            Button(action: { showingAddAccount = true }) {
                Label("Nueva Cuenta Bancaria", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.appPrimary)
                    .cornerRadius(12)
                    .padding()
            }
        }
        .sheet(isPresented: $showingAddAccount) {
            AddBankAccountView()
        }
        .sheet(item: $selectedAccountForDetail) { account in
            BankAccountDetailView(
                account: account,
                onEdit: {
                    selectedAccountForDetail = nil
                    accountToEdit = account
                },
                onDelete: {
                    selectedAccountForDetail = nil
                    accountToDelete = account
                    showingDeleteAlert = true
                }
            )
        }
        .sheet(item: $accountToEdit) { account in
            AddBankAccountView(accountToEdit: account)
        }
        .alert("¿Eliminar tarjeta?", isPresented: $showingDeleteAlert) {
            Button("Cancelar", role: .cancel) {}
            Button("Eliminar", role: .destructive) {
                if let account = accountToDelete {
                    userData.bankAccounts.removeAll { $0.id == account.id }
                }
            }
        } message: {
            Text("Esta acción eliminará los datos de esta tarjeta permanentemente.")
        }
    }
}

// MARK: - Bills List
struct BillsListView: View {
    let onMenuTap: () -> Void
    @ObservedObject var userData = UserDataManager.shared
    @State private var showingAddBill = false
    @State private var billToEdit: Bill?
    @State private var billToDelete: Bill?
    @State private var showingDeleteAlert = false
    
    var body: some View {
        VStack(spacing: 0) {
            TopNavBar(themeColor: .appPrimary, onMenuTap: onMenuTap, title: "Cuentas de Servicios")
            
            List {
                if userData.bills.isEmpty {
                    EmptyStateView(title: "Sin cuentas", message: "Guarda tus números de servicio (electricidad, agua, etc).", iconName: "doc.text")
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                } else {
                    let grouped = Dictionary(grouping: userData.bills, by: { $0.group.isEmpty ? "General" : $0.group })
                    
                    ForEach(grouped.keys.sorted(), id: \.self) { groupName in
                        Section(header: Text(groupName.uppercased())
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.secondary)) {
                            
                            ForEach(grouped[groupName] ?? []) { bill in
                                DataCard(
                                    id: bill.id,
                                    title: bill.label,
                                    subtitle: bill.type.rawValue,
                                    value: bill.billNumber,
                                    iconName: bill.type.iconName,
                                    backgroundColor: .appPrimary,
                                    onEdit: { billToEdit = bill },
                                    onDelete: { 
                                        billToDelete = bill
                                        showingDeleteAlert = true
                                    }
                                )
                                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .background(Color(UIColor.systemGroupedBackground))
            
            Button(action: { showingAddBill = true }) {
                Label("Nueva Cuenta de Servicio", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.appPrimary)
                    .cornerRadius(12)
                    .padding()
            }
        }
        .sheet(isPresented: $showingAddBill) {
            AddBillView()
        }
        .sheet(item: $billToEdit) { bill in
            AddBillView(billToEdit: bill)
        }
        .alert("¿Eliminar cuenta?", isPresented: $showingDeleteAlert) {
            Button("Cancelar", role: .cancel) {}
            Button("Eliminar", role: .destructive) {
                if let bill = billToDelete {
                    userData.bills.removeAll { $0.id == bill.id }
                }
            }
        } message: {
            Text("Esta acción no se puede deshacer.")
        }
    }
}

// MARK: - Keys List
struct KeysListView: View {
    let onMenuTap: () -> Void
    @ObservedObject var userData = UserDataManager.shared
    @State private var showingAddKey = false
    @State private var keyToEdit: UserKey?
    @State private var keyToDelete: UserKey?
    @State private var showingDeleteAlert = false
    @AppStorage("authEnabled") private var authEnabled: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            TopNavBar(themeColor: .appPrimary, onMenuTap: onMenuTap, title: "Mis Claves")

            if !authEnabled {
                VStack(spacing: 20) {
                    Spacer()
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.appPrimary)
                    Text("Sección protegida")
                        .font(.title3)
                        .fontWeight(.bold)
                    Text("Para acceder a tus claves debes activar la autenticación en Configuración.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(UIColor.systemGroupedBackground))
            } else {
                List {
                    if userData.userKeys.isEmpty {
                        EmptyStateView(title: "Sin claves", message: "Guarda tus PINs y contraseñas de forma segura.", iconName: "key.fill")
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    } else {
                        let grouped = Dictionary(grouping: userData.userKeys, by: { $0.group.isEmpty ? "General" : $0.group })

                        ForEach(grouped.keys.sorted(), id: \.self) { groupName in
                            Section(header: Text(groupName.uppercased())
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.secondary)) {

                                ForEach(grouped[groupName] ?? []) { key in
                                    // Special keys wear their bank's icon and colour instead of the global accent.
                                    let bank = key.category.bankId.flatMap { DataService.shared.bank(id: $0) }
                                    DataCard(
                                        id: key.id,
                                        title: key.label,
                                        subtitle: key.category == .other ? (key.customCategory ?? "Otros") : key.category.displayName,
                                        value: key.value,
                                        iconName: key.category.iconName,
                                        assetIconName: bank?.iconImg,
                                        backgroundColor: bank?.themeColor ?? .appPrimary,
                                        onEdit: { keyToEdit = key },
                                        onDelete: {
                                            keyToDelete = key
                                            showingDeleteAlert = true
                                        }
                                    )
                                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .background(Color(UIColor.systemGroupedBackground))

                Button(action: { showingAddKey = true }) {
                    Label("Nueva Clave", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.appPrimary)
                        .cornerRadius(12)
                        .padding()
                }
            }
        }
        .sheet(isPresented: $showingAddKey) {
            AddKeyView()
        }
        .sheet(item: $keyToEdit) { key in
            AddKeyView(keyToEdit: key)
        }
        .alert("¿Eliminar clave?", isPresented: $showingDeleteAlert) {
            Button("Cancelar", role: .cancel) {}
            Button("Eliminar", role: .destructive) {
                if let key = keyToDelete {
                    userData.userKeys.removeAll { $0.id == key.id }
                }
            }
        } message: {
            Text("Esta acción no se puede deshacer.")
        }
    }
}

// MARK: - Prefill Selection Sheet (pick a saved value, then dial)
struct PrefillSelectionView: View {
    let request: PrefillSelectionRequest
    let onSelect: (PrefillOption?) -> Void

    @State private var searchText = ""

    private var visibleOptions: [PrefillOption] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return request.options }

        return request.options.filter {
            $0.label.localizedCaseInsensitiveContains(query) || $0.value.contains(query)
        }
    }

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Toca para copiar al portapapeles"), footer: Text("Queda en el portapapeles listo para pegar cuando el USSD lo pida. Se borra solo a los 2 minutos.")) {
                    ForEach(visibleOptions) { option in
                        Button(action: { onSelect(option) }) {
                            HStack(spacing: 14) {
                                ZStack {
                                    Circle()
                                        .fill(Color.appPrimary.opacity(0.15))
                                        .frame(width: 42, height: 42)
                                    Image(systemName: option.iconName)
                                        .font(.system(size: 17, weight: .bold))
                                        .foregroundColor(.appPrimary)
                                }

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(option.label)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.primary)
                                    Text(option.value)
                                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                                        .foregroundColor(.appPrimary)
                                    if !option.detail.isEmpty {
                                        Text(option.detail)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }

                                Spacer()

                                Image(systemName: "doc.on.clipboard")
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                if visibleOptions.isEmpty {
                    Text("Sin resultados para «\(searchText)»")
                        .foregroundColor(.secondary)
                }

                Section {
                    Button(action: { onSelect(nil) }) {
                        HStack {
                            Image(systemName: "xmark.circle")
                            Text("Ninguno, solo marcar")
                        }
                        .foregroundColor(.secondary)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(request.title)
            .navigationBarTitleDisplayMode(.inline)
            .modifier(SearchFieldIfNeeded(isSearchable: request.isSearchable, text: $searchText))
        }
        .modifier(PrefillSheetHeight(startsExpanded: request.isSearchable))
    }
}

/// `.searchable` only when the list is long enough to justify it (the address book).
private struct SearchFieldIfNeeded: ViewModifier {
    let isSearchable: Bool
    @Binding var text: String

    func body(content: Content) -> some View {
        if isSearchable {
            content.searchable(text: $text, placement: .navigationBarDrawer(displayMode: .always), prompt: "Buscar contacto")
        } else {
            content
        }
    }
}

/// Half-height sheet the user can drag up to full screen. Contacts start expanded because
/// the search field plus a long list needs the room. iOS 15 has no detents API: full sheet there.
private struct PrefillSheetHeight: ViewModifier {
    let startsExpanded: Bool

    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content.presentationDetents(startsExpanded ? [.large] : [.medium, .large])
        } else {
            content
        }
    }
}

// MARK: - Empty State Helper
struct EmptyStateView: View {
    let title: String
    let message: String
    let iconName: String
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 50)
            Image(systemName: iconName)
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.3))
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Add/Edit Nauta View
struct AddNautaAccountView: View {
    @Environment(\.presentationMode) var presentationMode
    var accountToEdit: NautaAccount? = nil
    
    @State private var label = ""
    @State private var account = ""
    @State private var type = "Nacional"
    @State private var group = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Información de la Cuenta")) {
                    TextField("Etiqueta (ej: Mi Cuenta)", text: $label)
                    TextField("Usuario / Cuenta", text: $account)
                    Picker("Tipo", selection: $type) {
                        Text("Nacional").tag("Nacional")
                        Text("Internacional").tag("Internacional")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Section(header: Text("Organización"), footer: Text("Agrupa tus cuentas para encontrarlas más rápido (ej: Trabajo, Casa).")) {
                    TextField("Nombre del Grupo (opcional)", text: $group)
                }
            }
            .navigationTitle(accountToEdit == nil ? "Nueva Cuenta" : "Editar Cuenta")
            .navigationBarItems(
                leading: Button("Cancelar") { presentationMode.wrappedValue.dismiss() },
                trailing: Button("Guardar") {
                    let newAccount = NautaAccount(id: accountToEdit?.id ?? UUID(), type: type, account: account, label: label, group: group)
                    if let index = UserDataManager.shared.nautaAccounts.firstIndex(where: { $0.id == accountToEdit?.id }) {
                        UserDataManager.shared.nautaAccounts[index] = newAccount
                    } else {
                        UserDataManager.shared.nautaAccounts.append(newAccount)
                    }
                    presentationMode.wrappedValue.dismiss()
                }
                .disabled(label.isEmpty || account.isEmpty)
            )
            .onAppear {
                if let edit = accountToEdit {
                    label = edit.label
                    account = edit.account
                    type = edit.type
                    group = edit.group
                }
            }
        }
    }
}

// MARK: - Add/Edit Bank Account View
struct AddBankAccountView: View {
    @Environment(\.presentationMode) var presentationMode
    var accountToEdit: BankAccount? = nil
    
    @State private var label = ""
    @State private var name = ""
    @State private var cardNumber = ""
    @State private var mobile = ""
    @State private var group = ""
    @State private var selectedColor: Color = .black
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Información Bancaria")) {
                    TextField("Etiqueta (ej: Mi Tarjeta BPA)", text: $label)
                    TextField("Nombre del Titular", text: $name)
                    TextField("Número de Tarjeta", text: $cardNumber)
                        .keyboardType(.numberPad)
                    TextField("Móvil asociado (opcional)", text: $mobile)
                        .keyboardType(.phonePad)
                }
                
                Section(header: Text("Apariencia")) {
                    ColorPicker("Color de la Tarjeta", selection: $selectedColor)
                }
                
                Section(header: Text("Organización")) {
                    TextField("Nombre del Grupo (ej: Ahorros, Negocio)", text: $group)
                }
            }
            .navigationTitle(accountToEdit == nil ? "Nueva Tarjeta" : "Editar Tarjeta")
            .navigationBarItems(
                leading: Button("Cancelar") { presentationMode.wrappedValue.dismiss() },
                trailing: Button("Guardar") {
                    let colorHex = selectedColor.toHex() ?? "1A1A1A"
                    let newAccount = BankAccount(id: accountToEdit?.id ?? UUID(), name: name, cardNumber: cardNumber, mobile: mobile, label: label, group: group, colorHex: colorHex)
                    if let index = UserDataManager.shared.bankAccounts.firstIndex(where: { $0.id == accountToEdit?.id }) {
                        UserDataManager.shared.bankAccounts[index] = newAccount
                    } else {
                        UserDataManager.shared.bankAccounts.append(newAccount)
                    }
                    presentationMode.wrappedValue.dismiss()
                }
                .disabled(label.isEmpty || cardNumber.isEmpty)
            )
            .onAppear {
                if let edit = accountToEdit {
                    label = edit.label
                    name = edit.name
                    cardNumber = edit.cardNumber
                    mobile = edit.mobile
                    group = edit.group
                    selectedColor = Color(hex: edit.colorHex)
                }
            }
        }
    }
}

// MARK: - Add/Edit Bill View
struct AddBillView: View {
    @Environment(\.presentationMode) var presentationMode
    var billToEdit: Bill? = nil
    
    @State private var label = ""
    @State private var billNumber = ""
    @State private var type: BillType = .electricity
    @State private var group = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Detalles de Factura")) {
                    TextField("Etiqueta (ej: Casa de la Playa)", text: $label)
                    TextField("Número de Factura", text: $billNumber)
                        .keyboardType(.numberPad)
                    Picker("Tipo de Servicio", selection: $type) {
                        ForEach(BillType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                }
                
                Section(header: Text("Organización")) {
                    TextField("Nombre del Grupo (ej: Casas Familia)", text: $group)
                }
            }
            .navigationTitle(billToEdit == nil ? "Nueva Cuenta" : "Editar Cuenta")
            .navigationBarItems(
                leading: Button("Cancelar") { presentationMode.wrappedValue.dismiss() },
                trailing: Button("Guardar") {
                    let newBill = Bill(id: billToEdit?.id ?? UUID(), label: label, billNumber: billNumber, type: type, group: group)
                    if let index = UserDataManager.shared.bills.firstIndex(where: { $0.id == billToEdit?.id }) {
                        UserDataManager.shared.bills[index] = newBill
                    } else {
                        UserDataManager.shared.bills.append(newBill)
                    }
                    presentationMode.wrappedValue.dismiss()
                }
                .disabled(label.isEmpty || billNumber.isEmpty)
            )
            .onAppear {
                if let edit = billToEdit {
                    label = edit.label
                    billNumber = edit.billNumber
                    type = edit.type
                    group = edit.group
                }
            }
        }
    }
}

// MARK: - Add/Edit Key View
struct AddKeyView: View {
    @Environment(\.presentationMode) var presentationMode
    var keyToEdit: UserKey? = nil
    
    @State private var label = ""
    @State private var value = ""
    @State private var category: KeyCategory = .bank
    @State private var customCategory = ""
    @State private var group = ""

    @ObservedObject private var userData = UserDataManager.shared

    /// Special categories hold a single key: hide the ones already taken by another key.
    private var availableCategories: [KeyCategory] {
        KeyCategory.allCases.filter { userData.canUseSpecialCategory($0, excluding: keyToEdit?.id) }
    }

    private var isCategoryAvailable: Bool {
        userData.canUseSpecialCategory(category, excluding: keyToEdit?.id)
    }

    /// Advisory only — never blocks saving.
    private var valueWarning: String? {
        category.warning(forValue: value)
    }

    /// Special categories own their label: it is fixed, not editable, and always wins over `label`.
    private var effectiveLabel: String {
        category.defaultLabel ?? label
    }

    /// onAppear assigns `category`, which would fire the auto-label onChange and clobber
    /// the label of the key being edited. Skip that first programmatic change.
    @State private var didLoadInitialValues = false

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Detalles de la Clave"), footer: Text(category.isSpecial
                    ? "Clave especial: la app la copia sola al portapapeles cuando ejecutas la operación de autenticación de ese banco. Solo puede existir una de cada tipo."
                    : "")) {
                    if category.isSpecial {
                        HStack {
                            Text("Etiqueta")
                            Spacer()
                            Text(effectiveLabel)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        TextField("Etiqueta (ej: PIN BPA)", text: $label)
                    }

                    TextField("Clave / Contraseña", text: $value)
                        .keyboardType(category.maxPinLength != nil ? .numberPad : .default)

                    if let valueWarning = valueWarning {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                            Text(valueWarning)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .font(.caption)
                        .foregroundColor(.orange)
                    }

                    Picker("Categoría", selection: $category) {
                        ForEach(availableCategories, id: \.self) { cat in
                            Text(cat.displayName).tag(cat)
                        }
                    }
                    .onChange(of: category) { newCategory in
                        guard didLoadInitialValues else { return }
                        applyDefaultLabel(for: newCategory)
                    }

                    if category == .other {
                        TextField("¿Qué tipo de clave es?", text: $customCategory)
                    }
                }

                Section(header: Text("Organización")) {
                    TextField("Nombre del Grupo (opcional)", text: $group)
                }
            }
            .navigationTitle(keyToEdit == nil ? "Nueva Clave" : "Editar Clave")
            .navigationBarItems(
                leading: Button("Cancelar") { presentationMode.wrappedValue.dismiss() },
                trailing: Button("Guardar") {
                    guard userData.canUseSpecialCategory(category, excluding: keyToEdit?.id) else { return }
                    let newKey = UserKey(id: keyToEdit?.id ?? UUID(), label: effectiveLabel, value: value, category: category, customCategory: category == .other ? customCategory : nil, group: group)
                    if let index = UserDataManager.shared.userKeys.firstIndex(where: { $0.id == keyToEdit?.id }) {
                        UserDataManager.shared.userKeys[index] = newKey
                    } else {
                        UserDataManager.shared.userKeys.append(newKey)
                    }
                    presentationMode.wrappedValue.dismiss()
                }
                .disabled(effectiveLabel.isEmpty || value.isEmpty || (category == .other && customCategory.isEmpty) || !isCategoryAvailable)
            )
            .onAppear {
                if let edit = keyToEdit {
                    label = edit.label
                    value = edit.value
                    category = edit.category
                    customCategory = edit.customCategory ?? ""
                    group = edit.group
                }
                didLoadInitialValues = true
            }
        }
    }

    /// A special category supplies its own fixed label through `effectiveLabel`, so nothing to fill in.
    /// Leaving one only has to drop that fixed label so the editable field does not start out with it.
    private func applyDefaultLabel(for newCategory: KeyCategory) {
        guard newCategory.defaultLabel == nil else { return }

        let specialLabels = KeyCategory.allCases.compactMap { $0.defaultLabel }
        if specialLabels.contains(label) {
            label = ""
        }
    }
}

// MARK: - Bank Account Detail View
struct BankAccountDetailView: View {
    @Environment(\.presentationMode) var presentationMode
    let account: BankAccount
    var onEdit: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            // Header with dismiss
            HStack {
                Text("Detalles de Tarjeta")
                    .font(.headline)
                Spacer()
                HStack(spacing: 16) {
                    if let onEdit = onEdit {
                        Button(action: { presentationMode.wrappedValue.dismiss(); DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { onEdit() } }) {
                            Image(systemName: "pencil.circle.fill")
                                .font(.title2)
                                .foregroundColor(.appPrimary)
                        }
                    }
                    if let onDelete = onDelete {
                        Button(action: { presentationMode.wrappedValue.dismiss(); DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { onDelete() } }) {
                            Image(systemName: "trash.circle.fill")
                                .font(.title2)
                                .foregroundColor(.red)
                        }
                    }
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding()
            
            ScrollView {
                VStack(spacing: 24) {
                    WalletCard(account: account)
                        .padding(.horizontal)
                    
                    VStack(spacing: 16) {
                        DetailRow(label: "Etiqueta", value: account.label)
                        DetailRow(label: "Nombre en Tarjeta", value: account.name)
                        DetailRow(label: "Número Completo", value: account.cardNumber, isMonospaced: true, canCopy: true)
                        
                        if !account.mobile.isEmpty {
                            DetailRow(label: "Móvil Asociado", value: account.mobile, canCopy: true)
                        }
                        
                        if !account.group.isEmpty {
                            DetailRow(label: "Grupo", value: account.group)
                        }
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .cornerRadius(16)
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
        }
        .background(Color(UIColor.systemGroupedBackground))
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    var isMonospaced: Bool = false
    var canCopy: Bool = false
    
    @State private var showCopied = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.secondary)
            
            HStack {
                Text(value)
                    .font(isMonospaced ? .system(.body, design: .monospaced) : .body)
                    .fontWeight(isMonospaced ? .bold : .regular)
                
                Spacer()
                
                if canCopy {
                    Button(action: {
                        UIPasteboard.general.string = value
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        withAnimation { showCopied = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            withAnimation { showCopied = false }
                        }
                    }) {
                        if showCopied {
                            Text("Copiado")
                                .font(.caption2)
                                .foregroundColor(.green)
                        } else {
                            Image(systemName: "doc.on.doc")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 8)
        Divider()
    }
}
