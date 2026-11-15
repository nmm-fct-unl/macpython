import SwiftUI


// MARK: - Linha do Terminal
struct LinhaTextoView: View {
    let linha: String
    @Binding var comandoAtual: String
    @State private var isHovered: Bool = false
    let marcador = "\u{200B}"
    
    var isComando: Bool { linha.hasPrefix(marcador) }
    var textoLimpo: String { linha.replacingOccurrences(of: marcador, with: "") }
    
    var body: some View {
        Text(textoLimpo)
            .font(.system(size: 14, design: .monospaced))
            .foregroundColor(isComando ? .yellow : .green)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(isHovered && isComando ? Color.white.opacity(0.15) : Color.clear)
            .cornerRadius(4)
            .textSelection(.enabled) // Permite selecionar o texto
            .onHover { hover in isHovered = hover }
            // O simultaneousGesture garante que o clique funciona em simultâneo com a seleção!
            .simultaneousGesture(
                TapGesture().onEnded {
                    if isComando { 
                        comandoAtual = textoLimpo.replacingOccurrences(of: ">>> ", with: "") 
                    }
                }
            )
    }
}

// MARK: - Objetos do Canvas (Textos / Imagens)
struct ItemCanvasView: View {
    let item: ItemCanvas
    @ObservedObject var motor: MotorPython
    @Binding var isMPEditActive: Bool
    @State private var dragOffset = CGSize.zero
    
    var body: some View {
        Group {
            switch item.conteudo {
            case .texto(let t):
                Text(t)
                    .font(.title2).padding(8).background(Color.yellow.opacity(0.9))
                    .foregroundColor(.black).cornerRadius(8).shadow(radius: 5)
            case .imagem(let caminho):
                if let img = NSImage(contentsOfFile: caminho) {
                    Image(nsImage: img).resizable().scaledToFit()
                        .frame(maxWidth: 400, maxHeight: 400).shadow(radius: 10)
                } else {
                    Text("❌ Imagem não encontrada").foregroundColor(.red)
                }
            }
        }
        .overlay(
            isMPEditActive ? 
            Rectangle().stroke(Color.orange, style: StrokeStyle(lineWidth: 2, dash: [5])) 
            : nil
        )
        .position(x: item.x + dragOffset.width, y: item.y + dragOffset.height)
        .gesture(
            isMPEditActive ?
            DragGesture()
                .onChanged { dragOffset = $0.translation }
                .onEnded { value in
                    let newX = item.x + value.translation.width
                    let newY = item.y + value.translation.height
                    dragOffset = .zero
                    motor.atualizarPosicao(id: item.id, novaPosicao: CGPoint(x: newX, y: newY))
                }
            : nil
        )
        .animation(.easeInOut(duration: 0.1), value: item.x)
        .animation(.easeInOut(duration: 0.1), value: item.y)
    }
}