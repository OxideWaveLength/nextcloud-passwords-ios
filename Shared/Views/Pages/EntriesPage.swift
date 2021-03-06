import SwiftUI


struct EntriesPage: View {
    
    @ObservedObject var entriesController: EntriesController
    @ObservedObject var folder: Folder
    
    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject private var autoFillController: AutoFillController
    @EnvironmentObject private var biometricAuthenticationController: BiometricAuthenticationController
    @EnvironmentObject private var credentialsController: CredentialsController
    @EnvironmentObject private var tipController: TipController
    
    @State private var showServerSetupView = CredentialsController.default.credentials == nil
    @State private var showSettingsView = false
    @State private var folderForEditing: Folder?
    @State private var passwordForEditing: Password?
    @State private var folderForDeletion: Folder?
    @State private var passwordForDeletion: Password?
    @State private var searchTerm = ""
    @State private var showErrorAlert = false
    
    init(entriesController: EntriesController, folder: Folder? = nil) {
        self.entriesController = entriesController
        self.folder = folder ?? Folder()
    }
    
    // MARK: Views
    
    var body: some View {
        let entries = EntriesController.processEntries(passwords: entriesController.passwords, folders: entriesController.folders, folder: folder, searchTerm: searchTerm, filterBy: entriesController.filterBy, sortBy: entriesController.sortBy, reversed: entriesController.reversed)
        let suggestions = EntriesController.processSuggestions(passwords: entriesController.passwords, serviceURLs: autoFillController.serviceURLs)
        return mainStack(entries: entries, suggestions: suggestions)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    leadingToolbarView()
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if let entries = entries {
                        trailingToolbarView(entries: entries)
                    }
                }
            }
            .navigationTitle(folder.label)
    }
    
    private func mainStack(entries: [Entry]?, suggestions: [Password]?) -> some View {
        VStack {
            if credentialsController.credentials == nil {
                connectView()
            }
            else if entriesController.error {
                errorView()
            }
            else if let entries = entries {
                listView(entries: entries, suggestions: suggestions)
                    .searchBar(term: $searchTerm)
            }
            else {
                ProgressView()
            }
            EmptyView()
                .sheet(isPresented: $showSettingsView) {
                    SettingsNavigation()
                        .environmentObject(autoFillController)
                        .environmentObject(biometricAuthenticationController)
                        .environmentObject(credentialsController)
                        .environmentObject(tipController)
                }
        }
    }
    
    private func connectView() -> some View {
        VStack {
            Button("_connectToServer") {
                showServerSetupView = true
            }
            .frame(maxWidth: 600)
            .buttonStyle(ActionButtonStyle())
            EmptyView()
                .sheet(isPresented: $showServerSetupView) {
                    ServerSetupNavigation()
                        .environmentObject(autoFillController)
                        .environmentObject(biometricAuthenticationController)
                        .environmentObject(credentialsController)
                        .environmentObject(tipController)
                }
        }
        .padding()
    }
    
    private func listView(entries: [Entry], suggestions: [Password]?) -> some View {
        VStack {
            if entries.isEmpty && suggestions?.isEmpty ?? true {
                Text("_nothingToSeeHere")
                    .foregroundColor(.gray)
                    .padding()
            }
            else {
                List {
                    if folder.isBaseFolder,
                       let suggestions = suggestions,
                       !suggestions.isEmpty {
                        Section(header: Text("_suggestions")) {
                            suggestionRows(suggestions: suggestions)
                        }
                        Section(header: Text("_all")) {
                            entryRows(entries: entries)
                        }
                    }
                    else {
                        entryRows(entries: entries)
                    }
                }
                .listStyle(PlainListStyle())
            }
            EmptyView()
                .sheet(item: $folderForEditing) {
                    folder in
                    EditFolderNavigation(folder: folder, addFolder: {
                        entriesController.add(folder: folder)
                    }, updateFolder: {
                        entriesController.update(folder: folder)
                    })
                    .environmentObject(autoFillController)
                    .environmentObject(biometricAuthenticationController)
                    .environmentObject(credentialsController)
                    .environmentObject(tipController)
                }
                .actionSheet(item: $folderForDeletion) {
                    folder in
                    ActionSheet(title: Text("_confirmAction"), buttons: [.cancel(), .destructive(Text("_deleteFolder")) {
                        entriesController.delete(folder: folder)
                    }])
                }
            EmptyView()
                .sheet(item: $passwordForEditing) {
                    password in
                    EditPasswordNavigation(password: password, addPassword: {
                        entriesController.add(password: password)
                    }, updatePassword: {
                        entriesController.update(password: password)
                    })
                    .environmentObject(autoFillController)
                    .environmentObject(biometricAuthenticationController)
                    .environmentObject(credentialsController)
                    .environmentObject(tipController)
                }
                .actionSheet(item: $passwordForDeletion) {
                    password in
                    ActionSheet(title: Text("_confirmAction"), buttons: [.cancel(), .destructive(Text("_deletePassword")) {
                        entriesController.delete(password: password)
                    }])
                }
        }
    }
    
    private func suggestionRows(suggestions: [Password]) -> some View {
        ForEach(suggestions) {
            password in
            PasswordRow(entriesController: entriesController, password: password, showStatus: entriesController.sortBy == .status, editPassword: {
                passwordForEditing = password
            }, deletePassword: {
                passwordForDeletion = password
            })
        }
        .onDelete {
            indices in
            passwordForDeletion = suggestions[safe: indices.first]
        }
    }
    
    private func entryRows(entries: [Entry]) -> some View {
        ForEach(entries) {
            entry -> AnyView in
            switch entry {
            case .folder(let folder):
                return AnyView(FolderRow(entriesController: entriesController, folder: folder, editFolder: {
                    folderForEditing = folder
                }, deleteFolder: {
                    folderForDeletion = folder
                }))
            case .password(let password):
                return AnyView(PasswordRow(entriesController: entriesController, password: password, showStatus: entriesController.sortBy == .status, editPassword: {
                    passwordForEditing = password
                }, deletePassword: {
                    passwordForDeletion = password
                }))
            }
        }
        .onDelete {
            indices in
            onDeleteEntry(entry: entries[safe: indices.first])
        }
    }
    
    private func errorView() -> some View {
        VStack {
            Text("_anErrorOccurred")
                .foregroundColor(.gray)
                .padding()
        }
    }
    
    private func leadingToolbarView() -> some View {
        HStack {
            if folder.isBaseFolder {
                if let cancel = autoFillController.cancel {
                    Button("_cancel") {
                        cancel()
                    }
                }
                else {
                    Button("_settings") {
                        showSettingsView = true
                    }
                }
            }
        }
    }
    
    private func trailingToolbarView(entries: [Entry]) -> some View {
        HStack {
            if !folder.isBaseFolder,
               folder.revision.isEmpty {
                ProgressView()
                Spacer()
            }
            else if let error = folder.error {
                errorButton(error: error)
                Spacer()
            }
            filterSortMenu()
            createMenu()
        }
    }
    
    private func errorButton(error: Entry.EntryError) -> some View {
        Button {
            showErrorAlert = true
        }
        label: {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(error == .deleteError ? .gray : .red)
        }
        .buttonStyle(BorderlessButtonStyle())
        .alert(isPresented: $showErrorAlert) {
            switch error {
            case .createError:
                return Alert(title: Text("_error"), message: Text("_createFolderErrorMessage"))
            case .editError:
                return Alert(title: Text("_error"), message: Text("_editFolderErrorMessage"))
            case .deleteError:
                return Alert(title: Text("_error"), message: Text("_deleteFolderErrorMessage"))
            }
        }
    }
    
    private func filterSortMenu() -> some View {
        Menu {
            Picker("", selection: $entriesController.filterBy) {
                Label("_all", systemImage: "list.bullet")
                    .tag(EntriesController.Filter.all)
                Label("_folders", systemImage: "folder")
                    .tag(EntriesController.Filter.folders)
                Label("_favorites", systemImage: "star")
                    .tag(EntriesController.Filter.favorites)
            }
            Picker("", selection: $entriesController.sortBy) {
                Label("_name", systemImage: entriesController.reversed ? "chevron.down" : "chevron.up")
                    .showIcon(entriesController.sortBy == .label)
                    .tag(EntriesController.Sorting.label)
                Label("_updated", systemImage: entriesController.reversed ? "chevron.down" : "chevron.up")
                    .showIcon(entriesController.sortBy == .updated)
                    .tag(EntriesController.Sorting.updated)
                if entriesController.filterBy != .folders {
                    Label("_username", systemImage: entriesController.reversed ? "chevron.down" : "chevron.up")
                        .showIcon(entriesController.sortBy == .username)
                        .tag(EntriesController.Sorting.username)
                    Label("_url", systemImage: entriesController.reversed ? "chevron.down" : "chevron.up")
                        .showIcon(entriesController.sortBy == .url)
                        .tag(EntriesController.Sorting.url)
                    Label("_security", systemImage: entriesController.reversed ? "chevron.down" : "chevron.up")
                        .showIcon(entriesController.sortBy == .status)
                        .tag(EntriesController.Sorting.status)
                }
            }
        }
        label: {
            Spacer()
            Image(systemName: "arrow.up.arrow.down")
            Spacer()
        }
        .onChange(of: entriesController.filterBy, perform: didChange)
    }
    
    private func createMenu() -> some View {
        Menu {
            Button(action: {
                folderForEditing = Folder(parent: folder.id, client: Configuration.clientName, favorite: folder.isBaseFolder && entriesController.filterBy == .favorites)
            }, label: {
                Label("_createFolder", systemImage: "folder")
            })
            .disabled(folder.revision.isEmpty && !folder.isBaseFolder)
            Button(action: {
                passwordForEditing = Password(folder: folder.id, client: Configuration.clientName, favorite: folder.isBaseFolder && entriesController.filterBy == .favorites)
            }, label: {
                Label("_createPassword", systemImage: "key")
            })
            .disabled(folder.revision.isEmpty && !folder.isBaseFolder)
        }
        label: {
            Spacer()
            Image(systemName: "plus")
        }
    }
    
    // MARK: Functions
    
    private func onDeleteEntry(entry: Entry?) {
        switch entry {
        case .folder(let folder):
            folderForDeletion = folder
        case .password(let password):
            passwordForDeletion = password
        case .none:
            break
        }
    }
    
    private func didChange(filterBy: EntriesController.Filter) {
        if !folder.isBaseFolder,
           filterBy != .folders {
            presentationMode.wrappedValue.dismiss()
        }
    }
    
}


extension EntriesPage {
    
    struct FolderRow: View {
        
        @ObservedObject var entriesController: EntriesController
        @ObservedObject var folder: Folder
        let editFolder: () -> Void
        let deleteFolder: () -> Void
        
        @State private var showErrorAlert = false
        
        // MARK: Views
        
        var body: some View {
            entriesPageLink()
                .contextMenu {
                    Button {
                        toggleFavorite()
                    }
                    label: {
                        Label("_favorite", systemImage: folder.favorite ? "star.fill" : "star")
                    }
                    Button {
                        editFolder()
                    }
                    label: {
                        Label("_edit", systemImage: "pencil")
                    }
                    .disabled(folder.revision.isEmpty)
                    Divider()
                    Button {
                        deleteFolder()
                    }
                    label: {
                        Label("_delete", systemImage: "trash")
                    }
                }
        }
        
        private func entriesPageLink() -> some View {
            NavigationLink(destination: EntriesPage(entriesController: entriesController, folder: folder)) {
                mainStack()
            }
            .isDetailLink(false)
        }
        
        private func mainStack() -> some View {
            HStack {
                folderImage()
                labelText()
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack {
                    if folder.revision.isEmpty {
                        ProgressView()
                    }
                    else if let error = folder.error {
                        errorButton(error: error)
                    }
                    if folder.favorite {
                        favoriteImage()
                    }
                }
            }
        }
        
        private func folderImage() -> some View {
            Image(systemName: "folder")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 40, height: 40)
                .foregroundColor(Color.accentColor)
        }
        
        private func labelText() -> some View {
            VStack(alignment: .leading) {
                Text(folder.label)
                    .lineLimit(1)
            }
        }
        
        private func errorButton(error: Entry.EntryError) -> some View {
            Button {
                showErrorAlert = true
            }
            label: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(error == .deleteError ? .gray : .red)
            }
            .buttonStyle(BorderlessButtonStyle())
            .alert(isPresented: $showErrorAlert) {
                switch error {
                case .createError:
                    return Alert(title: Text("_error"), message: Text("_createFolderErrorMessage"))
                case .editError:
                    return Alert(title: Text("_error"), message: Text("_editFolderErrorMessage"))
                case .deleteError:
                    return Alert(title: Text("_error"), message: Text("_deleteFolderErrorMessage"))
                }
            }
        }
        
        private func favoriteImage() -> some View {
            Image(systemName: "star.fill")
                .foregroundColor(.gray)
        }
        
        // MARK: Functions
        
        private func toggleFavorite() {
            guard let credentials = CredentialsController.default.credentials else {
                return
            }
            folder.favorite.toggle()
            
            UpdateFolderRequest(credentials: credentials, folder: folder).send {
                response in
                guard let response = response else {
                    folder.favorite.toggle()
                    return
                }
                folder.error = nil
                folder.revision = response.revision
                folder.edited = Date()
                folder.updated = Date()
            }
            folder.revision = ""
        }
        
    }
    
}


extension EntriesPage {
    
    struct PasswordRow: View {
        
        @ObservedObject var entriesController: EntriesController
        @ObservedObject var password: Password
        let showStatus: Bool
        let editPassword: () -> Void
        let deletePassword: () -> Void
        
        @EnvironmentObject private var autoFillController: AutoFillController
        @EnvironmentObject private var credentialsController: CredentialsController
        
        @State private var favicon: UIImage?
        @State private var showPasswordDetailView = false
        @State private var showErrorAlert = false
        
        // MARK: Views
        
        var body: some View {
            wrapperStack()
                .contextMenu {
                    Button {
                        UIPasteboard.general.privateString = password.password
                    }
                    label: {
                        Label("_copyPassword", systemImage: "doc.on.doc")
                    }
                    if !password.username.isEmpty {
                        Button {
                            UIPasteboard.general.string = password.username
                        }
                        label: {
                            Label("_copyUsername", systemImage: "doc.on.doc")
                        }
                    }
                    if let url = URL(string: password.url),
                       let canOpenURL = UIApplication.safeCanOpenURL,
                       canOpenURL(url),
                       let open = UIApplication.safeOpen {
                        Button {
                            open(url)
                        }
                        label: {
                            Label("_openUrl", systemImage: "safari")
                        }
                    }
                    Divider()
                    Button {
                        toggleFavorite()
                    }
                    label: {
                        Label("_favorite", systemImage: password.favorite ? "star.fill" : "star")
                    }
                    if password.editable {
                        Button {
                            editPassword()
                        }
                        label: {
                            Label("_edit", systemImage: "pencil")
                        }
                        .disabled(password.revision.isEmpty)
                    }
                    Divider()
                    Button {
                        deletePassword()
                    }
                    label: {
                        Label("_delete", systemImage: "trash")
                    }
                }
        }
        
        private func wrapperStack() -> some View {
            HStack {
                if let complete = autoFillController.complete {
                    Button {
                        complete(password.username, password.password)
                    }
                    label: {
                        mainStack()
                    }
                    .buttonStyle(PlainButtonStyle())
                    .frame(maxWidth: .infinity)
                    Spacer()
                    Button {
                        showPasswordDetailView = true
                    }
                    label: {
                        Image(systemName: "info.circle")
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    NavigationLink(destination: PasswordDetailPage(password: password, updatePassword: {
                        entriesController.update(password: password)
                    }, deletePassword: {
                        entriesController.delete(password: password)
                    }), isActive: $showPasswordDetailView) {}
                    .isDetailLink(true)
                    .frame(width: 0, height: 0)
                    .opacity(0)
                }
                else {
                    NavigationLink(destination: PasswordDetailPage(password: password, updatePassword: {
                        entriesController.update(password: password)
                    }, deletePassword: {
                        entriesController.delete(password: password)
                    })) {
                        mainStack()
                    }
                    .isDetailLink(true)
                }
            }
        }
        
        private func mainStack() -> some View {
            HStack {
                faviconImage()
                labelStack()
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack {
                    if password.revision.isEmpty {
                        ProgressView()
                    }
                    else if let error = password.error {
                        errorButton(error: error)
                    }
                    if password.favorite {
                        favoriteImage()
                    }
                    if showStatus {
                        statusImage()
                    }
                }
            }
        }
        
        private func faviconImage() -> some View {
            Image(uiImage: favicon ?? UIImage())
                .resizable()
                .frame(width: 40, height: 40)
                .background(favicon == nil ? Color(white: 0.5, opacity: 0.2) : nil)
                .cornerRadius(3.75)
                .onAppear {
                    requestFavicon()
                }
        }
        
        private func labelStack() -> some View {
            VStack(alignment: .leading) {
                Text(password.label)
                    .lineLimit(1)
                Text(!password.username.isEmpty ? password.username : "-")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }
        }
        
        private func errorButton(error: Entry.EntryError) -> some View {
            Button {
                showErrorAlert = true
            }
            label: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(error == .deleteError ? .gray : .red)
            }
            .buttonStyle(BorderlessButtonStyle())
            .alert(isPresented: $showErrorAlert) {
                switch error {
                case .createError:
                    return Alert(title: Text("_error"), message: Text("_createPasswordErrorMessage"))
                case .editError:
                    return Alert(title: Text("_error"), message: Text("_editPasswordErrorMessage"))
                case .deleteError:
                    return Alert(title: Text("_error"), message: Text("_deletePasswordErrorMessage"))
                }
            }
        }
        
        private func favoriteImage() -> some View {
            Image(systemName: "star.fill")
                .foregroundColor(.gray)
        }
        
        private func statusImage() -> some View {
            switch password.statusCode {
            case .good:
                return Image(systemName: "checkmark.shield.fill")
                    .foregroundColor(.green)
            case .outdated, .duplicate:
                return Image(systemName: "exclamationmark.shield.fill")
                    .foregroundColor(.yellow)
            case .breached:
                return Image(systemName: "xmark.shield.fill")
                    .foregroundColor(.red)
            }
        }
        
        // MARK: Functions
        
        private func toggleFavorite() {
            guard let credentials = CredentialsController.default.credentials else {
                return
            }
            password.favorite.toggle()
            
            UpdatePasswordRequest(credentials: credentials, password: password).send {
                response in
                guard let response = response else {
                    password.favorite.toggle()
                    return
                }
                password.error = nil
                password.revision = response.revision
                password.updated = Date()
            }
            password.revision = ""
        }
        
        private func requestFavicon() {
            guard let url = URL(string: password.url),
                  let domain = url.host,
                  let credentials = credentialsController.credentials else {
                return
            }
            FaviconServiceRequest(credentials: credentials, domain: domain).send { favicon = $0 }
        }
        
    }
    
}


struct EntriesPagePreview: PreviewProvider {
    
    static var previews: some View {
        PreviewDevice.generate {
            NavigationView {
                EntriesPage(entriesController: EntriesController.mock)
            }
            .showColumns(true)
            .environmentObject(AutoFillController.mock)
            .environmentObject(BiometricAuthenticationController.mock)
            .environmentObject(CredentialsController.mock)
            .environmentObject(TipController.mock)
        }
    }
    
}
