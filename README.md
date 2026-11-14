# MacPython 🐍🍏

Nasceu uma ferramenta incrível! 🎉 O MacPython agora junta o melhor de dois mundos: a flexibilidade bruta e análise de dados do Python com a interface fluida, nativa e desenhada a hardware (Metal/SwiftUI) do macOS.

O **MacPython** é um wrapper interativo feito em Swift/SwiftUI que junta o poder do interpretador Python a uma interface gráfica nativa de macOS. Com suporte para memória persistente, clique-para-copiar no terminal, um *Canvas* 2D sobreposto e uma paleta de ferramentas expansível via JSON (e até em tempo real pelo Python!).

## Funcionalidades
- **Janela e Barra Lateral Ajustáveis:** Arraste o divisor para a esquerda/direita ou redimensione a janela principal sem limites.
- **Histórico Interativo:** Clique em qualquer comando amarelo antigo para o passar instantaneamente para a barra de input.
- **Paleta JSON em Tempo Real:** Edite `botoes.json` ou crie botões dinamicamente. Atualiza com o clique de um botão ou automaticamente.
- **Canvas Overlay:** O Swift escuta o output do Python. Comandos mágicos formatados são interceptados e desenhados por cima do terminal em vez de impressos em texto.

## Como Compilar e Executar no macOS

Abra o terminal na pasta onde tem o ficheiro `macpython.swift` e corra:

### 1. Compilar para binário nativo
```bash
swiftc -parse-as-library macpython.swift -o macpython
```

### 2. Executar
```bash
./macpython
```

## A Ponte Python ⇄ Swift (Comandos Mágicos)

O interpretador processa comandos normalmente. Contudo, se imprimir (`print`) uma string iniciada por `::swift::`, o terminal não a apresenta em texto. Em vez disso, envia uma instrução visual ao SwiftUI.

Experimente estes comandos diretamente na linha de input ou carregando um `.py`:

### 1. Limpar Ecrã e Canvas

```python
print("::swift::clear")
```

Apaga todo o histórico de terminal e remove todos os gráficos e textos do Canvas.

### 2. Escrever Texto Flutuante

```python
print("::swift::at::<Posição_X>::<Posição_Y>::<O_seu_texto_aqui>")
```

# Exemplo:

```python
print("::swift::at::200::150::Isto está a flutuar nas coordenadas X=200, Y=150!")
```

### 3. Desenhar um Gráfico / Imagem (PNG, JPG)

```python
print("::swift::image::<Posição_X>::<Posição_Y>::<Caminho_Absoluto_da_Imagem>")
```

# Exemplo (substitua o caminho por uma imagem no seu Mac):

```python
print("::swift::image::300::200::/Users/o_seu_user/Desktop/grafico.png")
```

*Dica de Ouro:* Pode usar bibliotecas de Python como o `matplotlib`, guardar o ficheiro e ordenar na mesma função que o Swift carregue o novo PNG para o ecrã.

### 4. Criar um Botão na Paleta via Python

```python
print("::swift::button::<Titulo>::<Comando_Python>::<SFSymbol>")
```

# Exemplo:
```python
print("::swift::button::Mágica::print('Criado do python!')::wand.and.stars")
```

Assim que for executado, um novo botão aparecerá na barra lateral esquerda e será guardado para sempre no ficheiro `botoes.json`.
