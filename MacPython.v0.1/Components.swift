import SwiftUI


// MARK: - Linha do Terminal

struct LinhaTextoView: View {
    let linha: String
    let onSelectCommand: (String) -> Void

    @State private var isHovered = false

    private let marcador = "\u{200B}"

    private var isComando: Bool {
        linha.hasPrefix(marcador)
    }

    // Remove o marcador interno e o prompt Python.
    // O prompt não faz parte do comando que será recuperado ou arrastado.
    private var textoLimpo: String {
        let texto = linha.replacingOccurrences(of: marcador, with: "")

        if isComando && texto.hasPrefix(">>> ") {
            return String(texto.dropFirst(4))
        }

        return texto
    }

    var body: some View {
        HStack {
            if isComando {
                // As linhas de comando são clicáveis e podem ser arrastadas.
                // Não activamos textSelection nesta branch para evitar o
                // conflito entre a selecção nativa e o gesto de recuperação.
                Text(textoLimpo)
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(.yellow)
                    .draggable(textoLimpo)
            } else {
                // O output mantém a selecção de texto nativa do macOS.
                Text(textoLimpo)
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(.green)
                    .textSelection(.enabled)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            isHovered && isComando
                ? Color.white.opacity(0.15)
                : Color.clear
        )
        .cornerRadius(4)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture {
            guard isComando else { return }
            onSelectCommand(textoLimpo)
        }
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
                    .font(.title2)
                    .padding(8)
                    .background(Color.yellow.opacity(0.9))
                    .foregroundColor(.black)
                    .cornerRadius(8)
                    .shadow(radius: 5)

            case .imagem(let caminho):
                if let img = NSImage(contentsOfFile: caminho) {
                    Image(nsImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 400, maxHeight: 400)
                        .shadow(radius: 10)
                } else {
                    Text("❌ Imagem não encontrada")
                        .foregroundColor(.red)
                }
            }
        }
        .overlay(
            isMPEditActive
                ? Rectangle().stroke(
                    Color.orange,
                    style: StrokeStyle(lineWidth: 2, dash: [5])
                )
                : nil
        )
        .position(
            x: item.x + dragOffset.width,
            y: item.y + dragOffset.height
        )
        .gesture(
            isMPEditActive
                ? DragGesture()
                    .onChanged { dragOffset = $0.translation }
                    .onEnded { value in
                        let newX = item.x + value.translation.width
                        let newY = item.y + value.translation.height
                        dragOffset = .zero
                        motor.atualizarPosicao(
                            id: item.id,
                            novaPosicao: CGPoint(x: newX, y: newY)
                        )
                    }
                : nil
        )
        .animation(.easeInOut(duration: 0.1), value: item.x)
        .animation(.easeInOut(duration: 0.1), value: item.y)
    }
}
