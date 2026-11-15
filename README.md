# MacPython 🐍

O **MacPython** é um wrapper interativo feito em Swift/SwiftUI que junta o poder do interpretador Python a uma interface gráfica nativa de macOS. Com suporte para memória persistente, clique-para-copiar no terminal, um *Canvas* 2D sobreposto e uma paleta de ferramentas expansível via JSON (e até em tempo real pelo Python!).

## Funcionalidades
- **Janela e Barra Lateral Ajustáveis:** Arraste o divisor para a esquerda/direita ou redimensione a janela principal sem limites.
- **Histórico Interativo:** Clique em qualquer comando amarelo antigo para o passar instantaneamente para a barra de input.
- **Paleta JSON em Tempo Real:** Edite `botoes.json` ou crie botões dinamicamente. Atualiza com o clique de um botão ou automaticamente.
- **Canvas Overlay Animado:** Uma máquina de estados (State Machine) interna permite desenhar, mover e atualizar gráficos e textos em tempo real, sem piscar o ecrã.
- **MP_Edit (Bidirecional):** Arraste objetos visuais com o rato e o Swift atualiza silenciosamente as coordenadas dentro do próprio interpretador Python!

## Como Compilar e Executar no macOS

Abra o terminal na pasta onde tem o ficheiro `macpython.swift` e corra:

```bash
# 1. Compilar para binário nativo
swiftc -parse-as-library macpython.swift -o macpython

# 2. Executar
./macpython

```

---

## A Ponte Python ⇄ Swift (Máquina de Estados)

O MacPython usa um namespace seguro (`::swift ... ::`) para enviar comandos visuais do Python para a interface. O Swift guarda em memória a posição atual (`at`) e o nome do objeto atual (`name`).

**Superpoder da Máquina de Estados:** Se der um nome a um objeto e mais tarde criar outro com o *mesmo nome*, o Swift **atualiza o objeto antigo** (movendo-o ou mudando o texto/imagem) em vez de criar um novo! Ideal para animações.

*(Pode usar o fecho com `::` no final para evitar problemas com quebras de linha, mas o Swift também aceita a sintaxe aberta sem os `::` finais).*

### 1. Limpar Ecrã

```python
print("::swift clear::")

```

### 2. Criar e Atualizar Caixas de Texto

```python
# Define as coordenadas e o ID (nome) do objeto
print("::swift at 200 150::")
print("::swift name etiqueta_1::")
# Cria o objeto visual
print("::swift print Este texto suporta espaços perfeitamente!::")

```

### 3. Inserir e Atualizar Imagens / Gráficos

Ideal para usar em conjunto com o `matplotlib`! Guarde o gráfico num PNG e mande o Swift desenhá-lo:

```python
print("::swift at 300 200::")
print("::swift name meu_grafico::")
print("::swift image /Users/o_seu_user/Desktop/grafico.png::")

```

### 4. Criar um Botão na Paleta via Python

Os botões usam o separador vertical `|` para separar os argumentos, permitindo espaços livres no título e no código Python:

```python
# Sintaxe: Titulo | Comando a executar | Ícone SFSymbol
print("::swift button Limpar Tudo | print('::swift clear::') | trash::")

```

*(Assim que for executado, o botão aparece na barra lateral e é guardado para sempre no ficheiro `botoes.json`)*.

---

## 5. Modo de Edição Bidirecional (MP_Edit) 🖱️🔄

O MacPython não se limita a receber ordens do Python. Ele **conversa de volta**.
Na barra inferior, existe um botão **MP_Edit**. Quando ativado, todos os objetos do Canvas (textos e imagens) ganham uma margem tracejada cor-de-laranja e podem ser arrastados livremente com o rato pelo ecrã.

Sempre que largar um objeto (drag & drop), o Swift **injeta a nova coordenada** de volta no interpretador Python, para dentro de um dicionário global nativo chamado `macpython_pos`.

**Como testar a magia:**

1. Crie um objeto através do terminal:
`print('::swift name meu_texto::')`
`print('::swift print Arraste-me!::')`
2. Ative o botão **MP_Edit** na interface e mova o texto para outro sítio com o rato.
3. No terminal Python, escreva e envie:
`print(macpython_pos['meu_texto'])`

*(O Python irá devolver a coordenada exata (X, Y) onde você deixou o objeto visualmente!)*

---

## Licença

Este projeto é disponibilizado sob a **Licença MIT**.
Criado por Nuno C. Marques (2026).
Qualquer pessoa pode usar, modificar e distribuir, desde que mantenha a atribuição à versão base do MacPython.

