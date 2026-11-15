# MacPython 🐍 - API
**Versão:** 0.1
**Autor:** Nuno C. Marques
**Ano:** 2026

O MacPython é um terminal interativo e tela de desenho (canvas) construído em **SwiftUI**, alimentado por um interpretador **Python 3** nativo a correr em background. 

O projeto utiliza uma **arquitetura modular**, dividindo a aplicação em múltiplos ficheiros para facilitar a manutenção, escalabilidade e leitura do código.

---

## 🏗️ Estrutura de Ficheiros

O projeto é composto por 4 ficheiros Swift independentes que partilham o mesmo contexto no momento da compilação.

### 1. `Models.swift`
Responsável pela camada de **Dados** e persistência.
* **`ComandoPaleta`**: Estrutura que define as propriedades de cada botão (título, comando, ícone).
* **`GestorBotoes`**: Classe `ObservableObject` que gere a leitura e escrita do ficheiro `botoes.json`.
* **Dados do Canvas**: Definições de `ItemCanvas` e `TipoConteudoCanvas` (texto e imagem).

### 2. `MotorPython.swift`
O **Cérebro** da aplicação. 
* Gere a classe `MotorPython`.
* Inicia o `Process()` apontando para `/usr/bin/env python3`.
* Lida com as `Pipes` de entrada (Standard Input) e saída (Standard Output/Error).
* Implementa a **State Machine** (Máquina de Estados) que interceta os comandos iniciados por `::swift::` (como `clear`, `at`, `image` e `button`) para manipular o Canvas.

### 3. `Components.swift`
Guarda as **Views Reutilizáveis** (UI).
* **`LinhaTextoView`**: Apresenta cada linha do terminal, detetando se é um output do Python ou um comando do utilizador, permitindo clicar para copiar o comando de volta para o input.
* **`ItemCanvasView`**: O componente desenhado no Canvas, que reage ao **Modo MP Edit** (drag & drop) e comunica as novas coordenadas ao `MotorPython`.

### 4. `MacPythonApp.swift`
A **Interface Principal** e o ponto de entrada da aplicação.
* Contém a `TerminalPythonView`, que usa um `HSplitView` para dividir o ecrã entre a **Paleta Lateral** (botões) e a **Área de Terminal/Canvas**.
* Processa a interceção dos novos comandos de sistema internos (`::swift::sys::...`).
* Inicia o ciclo de vida da app através de `@main`.

---

## ⚙️ Sistema Dinâmico de Botões (botoes.json)

A Paleta Lateral é agora 100% gerida por um ficheiro JSON. Não existem botões codificados rigidamente (hardcoded) na interface visual (UI). 

O Swift interceta comandos especiais para controlar a própria aplicação. Os comandos suportados são:

| Comando | Ação no Sistema |
| :--- | :--- |
| `::swift::sys::toggle_edit` | Liga/desliga o modo **MP Edit** (para arrastar elementos no Canvas). O botão fica laranja quando ativo. |
| `::swift::sys::load` | Abre um painel de seleção (`NSOpenPanel`) para carregar e executar um ficheiro `.py`. |
| `::swift::sys::edit_json` | Abre o `botoes.json` no editor de texto pré-definido do macOS. |
| `::swift::sys::reload_json` | Atualiza a UI em tempo real, recarregando os dados do `botoes.json`. |
| *(Qualquer outro texto)* | O comando é enviado diretamente para ser executado no interpretador Python. |

> **Nota de Recuperação:** Se o ficheiro `botoes.json` for eliminado ou corrompido, a aplicação recria-o automaticamente no arranque com os botões de sistema predefinidos e alguns botões de exemplo (Limpar, Olá Canvas).

---

## 🛠️ Como Compilar e Executar

Como o projeto está dividido em múltiplos ficheiros, é necessário compilar a pasta inteira num único executável, indicando ao compilador Swift que deve tratá-los como partes do mesmo programa.

Abre o Terminal na pasta onde guardaste os 4 ficheiros `.swift` e executa:

```bash
# Opção 1: Especificar os ficheiros
swiftc -parse-as-library Models.swift MotorPython.swift Components.swift MacPythonApp.swift -o macpython

# Opção 2: Compilar todos os .swift na pasta atual (Recomendado)
swiftc -parse-as-library *.swift -o macpython

```

Depois de compilar, basta iniciar a aplicação:

```bash
./macpython

```

```

```