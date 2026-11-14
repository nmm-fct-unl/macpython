import SwiftUI
import AppKit
import Foundation
import UniformTypeIdentifiers

// ==========================================
// 1. DADOS DOS BOTÕES
// ==========================================
struct ComandoPaleta: Codable, Identifiable {
    var id = UUID()
    let titulo: String
    let comando: String
    let icone: String?
    
    enum CodingKeys: String, CodingKey { case titulo, comando, icone }
}

class GestorBotoes: ObservableObject {
    @Published var botoes: [ComandoPaleta] = []
    let caminhoFicheiro = URL(fileURLWithPath: "botoes.json")
    
    init() { carregarBotoes() }
    
    func carregarBotoes() {
        if let data = try? Data(contentsOf: caminhoFicheiro),
           let decodificados = try? JSONDecoder().decode([ComandoPaleta].self, from: data) {
            self.botoes = decodificados
            return
        }
        
        self.botoes = [
            ComandoPaleta(titulo: "Limpar Tudo", comando: "print('::swift::clear')", icone: "trash.fill"),
            ComandoPaleta(titulo: "Canvas", comando: "print('::swift::at::150::100::Olá MacPython 🐍🍏')", icone: "paintbrush.fill")
        ]
        salvarNoFicheiro()
    }
    
    func adicionarBotao(titulo: String, comando: String, icone: String) {
        botoes.append(ComandoPaleta(titulo: titulo, comando: comando, icone: icone))
        salvarNoFicheiro()
    }
    
    private func salvarNoFicheiro() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        if let jsonData = try? encoder.encode(botoes) {
            try? jsonData.write(to: caminhoFicheiro)
        }
    }
}

// ==========================================
// 2. DADOS DO CANVAS
// ==========================================
enum TipoConteudoCanvas {
    case texto(String)
    case imagem(String)
}

struct ItemCanvas: Identifiable {
    let id = UUID()
    let x: CGFloat
    let y: CGFloat
    let conteudo: TipoConteudoCanvas
}

// ==========================================
// 3. MOTOR PYTHON COM PROTOCOLO DE INTERCEPÇÃO
// ==========================================
class MotorPython: ObservableObject {
    @Published var historia: String = "Bem-vindo ao MacPython! 🐍🍏\n"
    @Published var itensCanvas: [ItemCanvas] = []
    
    private var processo = Process()
    private var pipeEntrada = Pipe()
    private var pipeSaida = Pipe()
    private var bufferSaida: String = ""
    
    let marcadorComando = "\u{200B}"
    
    init() {
        processo.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        let pythonScript = "import sys, code; sys.ps1=''; sys.ps2=''; code.interact(banner='', exitmsg='')"
        processo.arguments = ["-u", "-c", pythonScript]
        
        processo.standardInput = pipeEntrada
        processo.standardOutput = pipeSaida
        processo.standardError = pipeSaida
        
        pipeSaida.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let chunk = String(data: data, encoding: .utf8) else { return }
            DispatchQueue.main.async { self?.processarChunk(chunk) }
        }
        try? processo.run()
    }
    
    private func processarChunk(_ chunk: String) {
        bufferSaida += chunk
        while let range = bufferSaida.range(of: "\n") {
            let linha = String(bufferSaida[..<range.lowerBound])
            bufferSaida.removeSubrange(..<range.upperBound)
            interpretarLinhaProtocolo(linha)
        }
    }
    
    private func interpretarLinhaProtocolo(_ linha: String) {
        if linha.hasPrefix("::swift::") {
            let partes = linha.components(separatedBy: "::")
            if partes.count >= 3 {
                let comando = partes[2]
                switch comando {
                case "clear":
                    historia = ""
                    itensCanvas.removeAll()
                case "at":
                    if partes.count >= 6, let x = Double(partes[3]), let y = Double(partes[4]) {
                        let texto = partes[5...].joined(separator: "::")
                        itensCanvas.append(ItemCanvas(x: CGFloat(x), y: CGFloat(y), conteudo: .texto(texto)))
                    }
                case "image":
                    if partes.count >= 6, let x = Double(partes[3]), let y = Double(partes[4]) {
                        let caminho = partes[5...].joined(separator: "::")
                        itensCanvas.append(ItemCanvas(x: CGFloat(x), y: CGFloat(y), conteudo: .imagem(caminho)))
                    }
                case "button":
                    if partes.count >= 6 {
                        let info = ["titulo": partes[3], "comando": partes[4], "icone": partes[5]]
                        NotificationCenter.default.post(name: NSNotification.Name("CriarBotaoPython"), object: nil, userInfo: info)
                    }
                default: break
                }
            }
        } else {
            historia += linha + "\n"
        }
    }
    
    func executar(comando: String) {
        historia += "\(marcadorComando)\(comando)\n"
        let input = comando + "\n"
        if let data = input.data(using: .utf8) { pipeEntrada.fileHandleForWriting.write(data) }
    }
    
    func injetarCodigoSilencioso(_ codigo: String) {
        let input = codigo + "\n"
        if let data = input.data(using: .utf8) { pipeEntrada.fileHandleForWriting.write(data) }
    }
}

// ==========================================
// 4. COMPONENTES VISUAIS
// ==========================================
struct LinhaTextoView: View {
    let linha: String
    @Binding var comandoAtual: String
    @State private var isHovered: Bool = false
    let marcador = "\u{200B}"
    
    var isComando: Bool { linha.hasPrefix(marcador) }
    var textoLimpo: String { linha.replacingOccurrences(of: marcador, with: "") }
    
    var body: some View {
        Text(textoLimpo)
            .font(.system(.body, design: .monospaced))
            .foregroundColor(isComando ? .yellow : .green)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(isHovered && isComando ? Color.white.opacity(0.15) : Color.clear)
            .cornerRadius(4)
            .onHover { hover in isHovered = hover }
            .onTapGesture { if isComando { comandoAtual = textoLimpo } }
    }
}

// ==========================================
// 5. INTERFACE PRINCIPAL (AGORA COM HSPLITVIEW)
// ==========================================
struct TerminalPythonView: View {
    @StateObject private var motor = MotorPython()
    @StateObject private var gestorBotoes = GestorBotoes()
    @State private var comando: String = ""
    let layoutColunas = [GridItem(.adaptive(minimum: 75), spacing: 10)]
    
    var body: some View {
        // HSplitView cria automaticamente o separador arrastável do macOS!
        HSplitView {
            
            // --- PALETA LATERAL ---
            VStack {
                Text("Paleta").font(.headline).padding(.top, 15)
                Divider()
                ScrollView {
                    LazyVGrid(columns: layoutColunas, spacing: 10) {
                        ForEach(gestorBotoes.botoes) { botao in
                            Button(action: { motor.executar(comando: botao.comando) }) {
                                VStack(spacing: 5) {
                                    if let icone = botao.icone, !icone.isEmpty {
                                        Image(systemName: icone).font(.title2).frame(height: 25)
                                    }
                                    Text(botao.titulo).font(.caption).lineLimit(1).minimumScaleFactor(0.8)
                                }
                                .frame(maxWidth: .infinity, minHeight: 55)
                            }
                            .buttonStyle(.bordered).tint(Color.gray.opacity(0.2))
                        }
                    }
                    .padding(10)
                }
                Divider()
                Button("Recarregar JSON") { gestorBotoes.carregarBotoes() }
                    .padding(.bottom, 10).controlSize(.small)
            }
            .frame(minWidth: 150, idealWidth: 200, maxWidth: 400) // Limites da barra lateral
            .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("CriarBotaoPython"))) { notif in
                if let info = notif.userInfo as? [String: String],
                   let t = info["titulo"], let c = info["comando"], let i = info["icone"] {
                    gestorBotoes.adicionarBotao(titulo: t, comando: c, icone: i)
                }
            }
            
            // --- ÁREA DE TERMINAL + CANVAS ---
            VStack(spacing: 10) {
                ZStack(alignment: .topLeading) {
                    ScrollViewReader { scroll in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 0) {
                                let linhas = motor.historia.components(separatedBy: "\n")
                                ForEach(Array(linhas.enumerated()), id: \.offset) { index, linha in
                                    LinhaTextoView(linha: linha, comandoAtual: $comando)
                                }
                                Color.clear.frame(height: 1).id("FUNDO")
                            }
                            .padding(.vertical)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .background(Color.black.opacity(0.85))
                        .cornerRadius(10)
                        .onChange(of: motor.historia) {
                            withAnimation { scroll.scrollTo("FUNDO", anchor: .bottom) }
                        }
                    }
                    
                    // Frente: Canvas
                    ForEach(motor.itensCanvas) { item in
                        switch item.conteudo {
                        case .texto(let t):
                            Text(t)
                                .font(.headline).padding(8).background(Color.yellow.opacity(0.9))
                                .foregroundColor(.black).cornerRadius(8).shadow(radius: 5)
                                .position(x: item.x, y: item.y)
                        case .imagem(let caminho):
                            if let img = NSImage(contentsOfFile: caminho) {
                                Image(nsImage: img).resizable().scaledToFit()
                                    .frame(maxWidth: 400, maxHeight: 400).shadow(radius: 10)
                                    .position(x: item.x, y: item.y)
                            } else {
                                Text("Erro: \(caminho)").foregroundColor(.red).position(x: item.x, y: item.y)
                            }
                        }
                    }
                }
                .clipped()
                
                HStack {
                    TextField("Comando python...", text: $comando)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.system(.body, design: .monospaced))
                        .onSubmit { enviarComando() }
                    Button("Enviar") { enviarComando() }
                    Button("Carregar .py") { abrirFicheiro() }
                }
            }
            .padding(20)
            .frame(minWidth: 400, maxWidth: .infinity, minHeight: 300, maxHeight: .infinity)
            
        }
        // Limites gerais da janela (permite maximizar livremente)
        .frame(minWidth: 700, idealWidth: 900, minHeight: 500, idealHeight: 600)
    }
    
    func enviarComando() {
        guard !comando.isEmpty else { return }
        motor.executar(comando: comando)
        comando = ""
    }
    
    func abrirFicheiro() {
        let painel = NSOpenPanel()
        painel.allowedContentTypes = [UTType.pythonScript]
        if painel.runModal() == .OK, let url = painel.url {
            motor.historia += "\n[A carregar: \(url.lastPathComponent)...]\n"
            motor.injetarCodigoSilencioso("exec(open('\(url.path)').read())")
        }
    }
}

// ==========================================
// 6. ARRANQUE
// ==========================================
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { return true }
}

@main
struct BonecoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene {
        WindowGroup { TerminalPythonView() }.windowStyle(.hiddenTitleBar)
    }
}