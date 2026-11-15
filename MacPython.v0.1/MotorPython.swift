import SwiftUI
import Foundation

class MotorPython: ObservableObject {
    @Published var historia: String = "Bem-vindo ao MacPython! 🐍\n"
    @Published var itensCanvas: [ItemCanvas] = []
    
    private var processo = Process()
    private var pipeEntrada = Pipe()
    private var pipeSaida = Pipe()
    private var bufferSaida: String = ""
    
    private var nomeAtual: String = "obj_\(UUID().uuidString.prefix(5))"
    let marcadorComando = "\u{200B}"
    
    init() {
        processo.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        let pythonScript = "import sys, code; sys.ps1=''; sys.ps2=''; macpython_pos={}; code.interact(banner='', exitmsg='')"
        processo.arguments = ["python3", "-u", "-c", pythonScript]
        
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
                    itensCanvas.removeAll()
                    historia += "✨ Canvas limpo.\n"
                case "name":
                    if partes.count >= 4 { nomeAtual = partes[3] }
                case "at":
                    if partes.count >= 6, let x = Double(partes[3]), let y = Double(partes[4]) {
                        let texto = partes[5...].joined(separator: "::")
                        upsertItemCanvas(x: CGFloat(x), y: CGFloat(y), conteudo: .texto(texto))
                    }
                case "image":
                    if partes.count >= 6, let x = Double(partes[3]), let y = Double(partes[4]) {
                        let caminho = partes[5...].joined(separator: "::")
                        upsertItemCanvas(x: CGFloat(x), y: CGFloat(y), conteudo: .imagem(caminho))
                    }
                case "button":
                    if partes.count >= 6 {
                        let info = ["titulo": partes[3], "comando": partes[4], "icone": partes[5]]
                        NotificationCenter.default.post(name: NSNotification.Name("CriarBotaoPython"), object: nil, userInfo: info)
                        historia += "🔘 Botão '\(partes[3])' adicionado via Python.\n"
                    }
                default: break
                }
            }
        } else {
            historia += linha + "\n"
        }
    }
    
    private func upsertItemCanvas(x: CGFloat, y: CGFloat, conteudo: TipoConteudoCanvas) {
        if let idx = itensCanvas.firstIndex(where: { $0.id == nomeAtual }) {
            itensCanvas[idx].conteudo = conteudo
            itensCanvas[idx].x = x
            itensCanvas[idx].y = y
        } else {
            itensCanvas.append(ItemCanvas(id: nomeAtual, x: x, y: y, conteudo: conteudo))
        }
        nomeAtual = "obj_\(UUID().uuidString.prefix(5))"
    }
    
    func atualizarPosicao(id: String, novaPosicao: CGPoint) {
        if let idx = itensCanvas.firstIndex(where: { $0.id == id }) {
            itensCanvas[idx].x = novaPosicao.x
            itensCanvas[idx].y = novaPosicao.y
            injetarCodigoSilencioso("macpython_pos['\(id)'] = (\(novaPosicao.x), \(novaPosicao.y))")
        }
    }
    
    func executar(comando: String) {
        historia += "\(marcadorComando)>>> \(comando)\n"
        let input = comando + "\n"
        if let data = input.data(using: .utf8) { pipeEntrada.fileHandleForWriting.write(data) }
    }
    
    func injetarCodigoSilencioso(_ codigo: String) {
        let input = codigo + "\n"
        if let data = input.data(using: .utf8) { pipeEntrada.fileHandleForWriting.write(data) }
    }
}