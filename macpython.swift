// =====================================================================
//  MacPython 🐍
//  Versão: 0.0 (inicial version)
//  Ano: 2026
//  Autor: Nuno C. Marques
//  Licença: MIT License
// =====================================================================

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
            ComandoPaleta(titulo: "Limpar Tudo", comando: "print('::swift clear::')", icone: "trash.fill"),
            ComandoPaleta(titulo: "Canvas", comando: "print('::swift at 150 100::')\nprint('::swift name ola::')\nprint('::swift print Olá MacPython 🐍::')", icone: "paintbrush.fill")
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
// 2. DADOS DO CANVAS (Agora mutáveis e Equatable)
// ==========================================
enum TipoConteudoCanvas: Equatable {
    case texto(String)
    case imagem(String)
}

struct ItemCanvas: Identifiable, Equatable {
    let id: String 
    var x: CGFloat // Agora são variáveis para podermos arrastar!
    var y: CGFloat
    let conteudo: TipoConteudoCanvas
}

// ==========================================
// 3. MOTOR PYTHON (Máquina de Estados)
// ==========================================
class MotorPython: ObservableObject {
    @Published var historia: String = "Bem-vindo ao MacPython! 🐍\n"
    @Published var itensCanvas: [ItemCanvas] = []
    
    private var mpAtX: CGFloat = 100
    private var mpAtY: CGFloat = 100
    private var mpName: String = UUID().uuidString
    
    private var processo = Process()
    private var pipeEntrada = Pipe()
    private var pipeSaida = Pipe()
    private var bufferSaida: String = ""
    
    let marcadorComando = "\u{200B}"
    
    init() {
        processo.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        // O dicionário global 'macpython_pos' é injetado diretamente no arranque do Python!
        let pythonScript = "import sys, code; sys.ps1=''; sys.ps2=''; macpython_pos={}; code.interact(banner='', exitmsg='', local=globals())"
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
        let prefixo = "::swift "
        if linha.hasPrefix(prefixo) {
            var instrucao = linha.dropFirst(prefixo.count)
            if instrucao.hasSuffix("::") { instrucao = instrucao.dropLast(2) }
            
            let partes = instrucao.split(separator: " ", maxSplits: 1)
            guard let comando = partes.first else { return }
            let argumentos = partes.count > 1 ? String(partes[1]).trimmingCharacters(in: .whitespaces) : ""
            
            switch String(comando) {
            case "clear": historia = ""; itensCanvas.removeAll()
            case "at":
                let coords = argumentos.split(separator: " ")
                if coords.count >= 2, let x = Double(coords[0]), let y = Double(coords[1]) {
                    self.mpAtX = CGFloat(x); self.mpAtY = CGFloat(y)
                }
            case "name": self.mpName = argumentos
            case "print":
                adicionarOuAtualizarItem(ItemCanvas(id: mpName, x: mpAtX, y: mpAtY, conteudo: .texto(argumentos)))
                self.mpName = UUID().uuidString
            case "image":
                adicionarOuAtualizarItem(ItemCanvas(id: mpName, x: mpAtX, y: mpAtY, conteudo: .imagem(argumentos)))
                self.mpName = UUID().uuidString
            case "button":
                let argsBotao = argumentos.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
                if argsBotao.count >= 3 {
                    let info = ["titulo": argsBotao[0], "comando": argsBotao[1], "icone": argsBotao[2]]
                    NotificationCenter.default.post(name: NSNotification.Name("CriarBotaoPython"), object: nil, userInfo: info)
                }
            default: historia += linha + "\n"
            }
        } else {
            historia += linha + "\n"
        }
    }
    
    private func adicionarOuAtualizarItem(_ novoItem: ItemCanvas) {
        if let index = itensCanvas.firstIndex(where: { $0.id == novoItem.id }) {
            itensCanvas[index] = novoItem
        } else {
            itensCanvas.append(novoItem)
        }
        // Sempre que se cria ou atualiza um item por código, avisa o dicionário Python também
        atualizarPosicaoPython(id: novoItem.id, x: novoItem.x, y: novoItem.y)
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
    
    // Comunica de volta para o Python o resultado de um drag & drop visual
    func atualizarPosicaoPython(id: String, x: CGFloat, y: CGFloat) {
        let codigo = "macpython_pos['\(id)'] = (\(Int(x)), \(Int(y)))"
        injetarCodigoSilencioso(codigo)
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
// 5. INTERFACE PRINCIPAL
// ==========================================
struct TerminalPythonView: View {
    @StateObject private var motor = MotorPython()
    @StateObject private var gestorBotoes = GestorBotoes()
    @State private var comando: String = ""
    @State private var modoEdicao: Bool = false // <-- NOVO: Estado de Edição
    
    let layoutColunas = [GridItem(.adaptive(minimum: 75), spacing: 10)]
    
    // Função helper para desenhar o conteúdo (limpa o código do ForEach)
    @ViewBuilder
    func renderizarConteudo(item: ItemCanvas) -> some View {
        switch item.conteudo {
        case .texto(let t):
            Text(t)
                .font(.headline).padding(8).background(Color.yellow.opacity(0.9))
                .foregroundColor(.black).cornerRadius(8).shadow(radius: 5)
        case .imagem(let caminho):
            if let img = NSImage(contentsOfFile: caminho) {
                Image(nsImage: img).resizable().scaledToFit()
                    .frame(maxWidth: 400, maxHeight: 400).shadow(radius: 10)
            } else {
                Text("Erro: \(caminho)").foregroundColor(.red)
            }
        }
    }
    
    var body: some View {
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
            .frame(minWidth: 150, idealWidth: 200, maxWidth: 400)
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
                    
                    // --- CANVAS COM SUPORTE A DRAG & DROP ---
                    // Usamos Binding ($motor.itensCanvas) para podermos alterar a variável X e Y
                    ForEach($motor.itensCanvas) { $item in
                        renderizarConteudo(item: item)
                            // Moldura visual de Edição
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.orange, style: StrokeStyle(lineWidth: modoEdicao ? 3 : 0, dash: [5, 5]))
                            )
                            .position(x: item.x, y: item.y)
                            // Gesto de Arrastar (Só funciona se o modoEdicao estiver true)
                            .gesture(
                                DragGesture(coordinateSpace: .named("Canvas"))
                                    .onChanged { value in
                                        guard modoEdicao else { return }
                                        item.x = value.location.x
                                        item.y = value.location.y
                                    }
                                    .onEnded { value in
                                        guard modoEdicao else { return }
                                        // Quando larga o objeto, avisa o dicionário Python!
                                        motor.atualizarPosicaoPython(id: item.id, x: item.x, y: item.y)
                                    }
                            )
                    }
                }
                .coordinateSpace(name: "Canvas") // Espaço de coordenadas para o rato bater certo com a janela
                .clipped()
                
                // Barra Inferior (Agora com o botão de Modo Edição!)
                HStack {
                    TextField("Comando python...", text: $comando)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.system(.body, design: .monospaced))
                        .onSubmit { enviarComando() }
                    
                    Button("Enviar") { enviarComando() }
                    Button("Carregar .py") { abrirFicheiro() }
                    
                    // O NOVO TOGGLE
                    Toggle(isOn: $modoEdicao) {
                        Label("MP_Edit", systemImage: "cursorarrow.and.square.on.square.dashed")
                    }
                    .toggleStyle(.button)
                    .tint(.orange)
                }
            }
            .padding(20)
            .frame(minWidth: 400, maxWidth: .infinity, minHeight: 300, maxHeight: .infinity)
            
        }
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
