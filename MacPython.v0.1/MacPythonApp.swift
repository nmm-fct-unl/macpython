import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct TerminalPythonView: View {
    @StateObject private var motor = MotorPython()
    @StateObject private var gestorBotoes = GestorBotoes()
    
    @State private var comando: String = ""
    @State private var isMPEditActive: Bool = false
    @FocusState private var inputIsFocused: Bool
    
    // NOVO: Memória do histórico de input para as setas
    @State private var historicoInput: [String] = []
    @State private var indiceHistorico: Int = -1
    
    var body: some View {
        HSplitView {
            
            // --- PALETA LATERAL (VERTICAL) ---
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(gestorBotoes.botoes) { botao in
                        if botao.comando == "::swift::sys::toggle_edit" {
                            Toggle(isOn: $isMPEditActive) {
                                HStack {
                                    if let icone = botao.icone, !icone.isEmpty {
                                        Image(systemName: icone).frame(width: 20)
                                    }
                                    Text(botao.titulo).font(.callout)
                                }
                            }
                            .toggleStyle(.switch)
                            .tint(.orange)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(NSColor.controlBackgroundColor).opacity(0.4))
                            .cornerRadius(8)
                        } else {
                            Button(action: { processarClique(botao: botao) }) {
                                HStack {
                                    if let icone = botao.icone, !icone.isEmpty {
                                        Image(systemName: icone).frame(width: 20)
                                    }
                                    Text(botao.titulo).font(.callout)
                                    Spacer()
                                }
                                .padding(.vertical, 6)
                                .padding(.horizontal, 4)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                .padding(10)
            }
            .frame(minWidth: 140, idealWidth: 180, maxWidth: 220)
            .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("CriarBotaoPython"))) { notif in
                if let info = notif.userInfo as? [String: String],
                   let t = info["titulo"], let c = info["comando"], let i = info["icone"] {
                    gestorBotoes.adicionarBotao(titulo: t, comando: c, icone: i)
                }
            }
            
            // --- ÁREA DE TERMINAL + CANVAS ---
            VStack(spacing: 0) {
                ZStack(alignment: .topLeading) {
                    Color.black.opacity(0.9).ignoresSafeArea()
                    
                    ScrollViewReader { scroll in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 0) {
                                let linhas = motor.historia.components(separatedBy: "\n")
                                ForEach(Array(linhas.enumerated()), id: \.offset) { index, linha in
                                    LinhaTextoView(linha: linha, comandoAtual: $comando)
                                }
                                Color.clear.frame(height: 1).id("FUNDO")
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .onChange(of: motor.historia) {
                            withAnimation { scroll.scrollTo("FUNDO", anchor: .bottom) }
                        }
                    }
                    
                    ForEach(motor.itensCanvas) { item in
                        ItemCanvasView(item: item, motor: motor, isMPEditActive: $isMPEditActive)
                    }
                }
                .clipped()
                
                Divider()
                
                // --- BARRA DE INPUT COM NAVEGAÇÃO POR SETAS ---
                HStack(spacing: 12) {
                    TextField("Comando Python...", text: $comando)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.system(size: 14, design: .monospaced))
                        .focused($inputIsFocused)
                        .onKeyPress(.upArrow) { // SETA PARA CIMA
                            if !historicoInput.isEmpty && indiceHistorico > 0 {
                                indiceHistorico -= 1
                                comando = historicoInput[indiceHistorico]
                                return .handled
                            }
                            return .ignored
                        }
                        .onKeyPress(.downArrow) { // SETA PARA BAIXO
                            if !historicoInput.isEmpty && indiceHistorico < historicoInput.count - 1 {
                                indiceHistorico += 1
                                comando = historicoInput[indiceHistorico]
                                return .handled
                            } else if indiceHistorico == historicoInput.count - 1 {
                                indiceHistorico += 1
                                comando = ""
                                return .handled
                            }
                            return .ignored
                        }
                        .onSubmit { enviarComando() }
                    
                    Button("Enviar") { enviarComando() }
                        .keyboardShortcut(.defaultAction)
                }
                .padding()
                .background(Color(NSColor.windowBackgroundColor))
            }
            .frame(minWidth: 400, maxWidth: .infinity, minHeight: 300, maxHeight: .infinity)
            
        }
        .frame(minWidth: 700, idealWidth: 900, minHeight: 500, idealHeight: 600)
    }
    
    // --- LÓGICA DE CLIQUES DO SISTEMA ---
    func processarClique(botao: ComandoPaleta) {
        switch botao.comando {
        case "::swift::sys::load":
            abrirFicheiro()
        case "::swift::sys::edit_json":
            gestorBotoes.abrirJSON()
        case "::swift::sys::reload_json":
            gestorBotoes.carregarBotoes()
            motor.historia += "🔄 Botões recarregados do JSON.\n"
        default:
            motor.executar(comando: botao.comando)
        }
    }
    
    func enviarComando() {
        guard !comando.isEmpty else { return }
        
        // NOVO: Adiciona ao histórico e reseta o índice para o fim da lista
        historicoInput.append(comando)
        indiceHistorico = historicoInput.count
        
        motor.executar(comando: comando)
        comando = ""
        inputIsFocused = true
    }
    
    func abrirFicheiro() {
        let painel = NSOpenPanel()
        painel.allowedContentTypes = [.pythonScript, .plainText]
        painel.allowsMultipleSelection = false
        
        if painel.runModal() == .OK, let url = painel.url {
            motor.historia += "\n📂 A carregar script: \(url.lastPathComponent)\n"
            motor.executar(comando: "exec(open('\(url.path)').read())")
        }
    }
}

// MARK: - ARRANQUE DA APLICAÇÃO
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { return true }
}

@main
struct MacPythonApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene {
        WindowGroup { TerminalPythonView() }
            .windowStyle(.hiddenTitleBar)
    }
}