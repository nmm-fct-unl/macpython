import SwiftUI
import AppKit
import Foundation

// MARK: - Dados da Paleta
struct ComandoPaleta: Codable, Identifiable {
    var id = UUID()
    let titulo: String
    let comando: String
    let icone: String?
    
    enum CodingKeys: String, CodingKey { case titulo, comando, icone }
}

class GestorBotoes: ObservableObject {
    @Published var botoes: [ComandoPaleta] = []
    let caminhoFicheiro: URL
    
    init() {
        let fm = FileManager.default
        let currentDir = URL(fileURLWithPath: fm.currentDirectoryPath)
        caminhoFicheiro = currentDir.appendingPathComponent("botoes.json")
        carregarBotoes()
    }
    
    func carregarBotoes() {
        if FileManager.default.fileExists(atPath: caminhoFicheiro.path),
           let data = try? Data(contentsOf: caminhoFicheiro),
           let decodificados = try? JSONDecoder().decode([ComandoPaleta].self, from: data) {
            self.botoes = decodificados
        } else {
            self.botoes = [
                ComandoPaleta(titulo: "MP Edit", comando: "::swift::sys::toggle_edit", icone: "cursorarrow.and.square.on.square.dashed"),
                ComandoPaleta(titulo: "Carregar .py", comando: "::swift::sys::load", icone: "applescript"),
                ComandoPaleta(titulo: "Editar JSON", comando: "::swift::sys::edit_json", icone: "pencil"),
                ComandoPaleta(titulo: "Reload JSON", comando: "::swift::sys::reload_json", icone: "arrow.triangle.2.circlepath"),
                ComandoPaleta(titulo: "Limpar", comando: "print('::swift::clear')", icone: "trash.fill"),
                ComandoPaleta(titulo: "Olá Canvas", comando: "print('::swift::at::150::100::Olá MacPython 🐍🍏')", icone: "paintbrush.fill")
            ]
            salvarNoFicheiro()
        }
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
    
    func abrirJSON() {
        if !FileManager.default.fileExists(atPath: caminhoFicheiro.path) { salvarNoFicheiro() }
        NSWorkspace.shared.open(caminhoFicheiro)
    }
}

// MARK: - Dados do Canvas
enum TipoConteudoCanvas {
    case texto(String)
    case imagem(String)
}

struct ItemCanvas: Identifiable {
    var id: String
    var x: CGFloat
    var y: CGFloat
    var conteudo: TipoConteudoCanvas
}