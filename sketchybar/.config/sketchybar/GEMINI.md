# GEMINI.md - Configuração do SketchyBar

Este documento fornece as diretrizes, arquitetura e convenções técnicas para o desenvolvimento e manutenção desta configuração do [SketchyBar](https://github.com/FelixKratz/SketchyBar) no macOS.

---

## 1. Visão Geral do Projeto

Esta é uma configuração moderna e altamente modular do **SketchyBar** para macOS, escrita em **Lua** utilizando a biblioteca de extensão nativa **[SbarLua](https://github.com/FelixKratz/SbarLua)**. Ela faz parte de um repositório de dotfiles gerenciado via **GNU Stow** e foi adaptada a partir da configuração de referência de Felix Kratz, com foco em integração direta com o gerenciador de janelas em mosaico **[AeroSpace](https://github.com/nikitabobko/AeroSpace)**.

### Características Principais
- **Base 100% Lua**: Elimina scripts em shell pesados usando a API Lua do SketchyBar via `SbarLua`.
- **Integração com AeroSpace**: Monitoramento dinâmico dos workspaces em tempo real, exibindo os ícones dos aplicativos abertos exclusivamente no workspace ativo e apenas o número nos demais para economizar espaço horizontal.
- **Provedores de Eventos em C**: Utilitários compilados nativamente (`cpu_load` e `network_load`) que comunicam estatísticas de uso diretamente ao SketchyBar via Mach Ports (`mach_msg`) sem sobrecarga de subprocessos.
- **Widgets Interativos e Popups**:
  - Seletor de dispositivo de áudio e slider de volume com suporte a scroll no trackpad/mouse.
  - Detalhes de Wi-Fi e rede com recurso "clique para copiar" para o clipboard (`pbcopy`).
  - Monitor de bateria com status de carregamento e cálculo de tempo restante (`pmset`).
  - Player de mídia para Spotify e Apple Music com controles via `nowplaying-cli`.
  - Gráfico de CPU com atalho para o Monitor de Atividade.

---

## 2. Estrutura do Diretório

```
.config/sketchybar/
├── sketchybarrc                   # Ponto de entrada executável (#!/usr/bin/env lua)
├── init.lua                       # Inicialização do bar, ciclo de vida e event loop
├── bar.lua                        # Estilo e propriedades da barra (altura, margem, blur, etc.)
├── default.lua                    # Configurações e estilos padrão herdados por itens
├── settings.lua                   # Configurações globais (fontes, paddings, ícones)
├── colors.lua                     # Paleta de cores ARGB e função auxiliar with_alpha
├── icons.lua                      # Dicionário de glifos (SF Symbols / Nerd Font)
├── GEMINI.md                      # Documentação e guia do projeto para agentes e desenvolvedores
├── helpers/                       # Módulos auxiliares e código C nativo
│   ├── init.lua                   # Configura package.cpath para SbarLua e compila helpers
│   ├── app_icons.lua              # Mapeamento de nomes de apps para glifos da sketchybar-app-font
│   ├── default_font.lua           # Mapeamento e tipografia padrão (SF Pro / SF Mono)
│   ├── makefile                   # Makefile raiz dos helpers
│   └── event_providers/           # Provedores de eventos em C
│       ├── makefile               # Makefile para compilação dos binários
│       ├── sketchybar.h           # Header de comunicação IPC nativa com SketchyBar (Mach ports)
│       ├── cpu_load/              # Monitor de uso de CPU em tempo real
│       └── network_load/          # Monitor de tráfego de rede (upload/download em en0)
└── items/                         # Componentes visuais da barra
    ├── init.lua                   # Orquestrador de carregamento dos itens
    ├── apple.lua                  # Ícone estático da Apple
    ├── spaces.lua                 # Workspaces do AeroSpace (ícones de apps no ativo, números nos demais)
    ├── front_app.lua              # Indicador do aplicativo em primeiro plano
    ├── calendar.lua               # Relógio e data (pt_BR) com atalho para o Calendar.app
    ├── media.lua                  # Widget de mídia (Spotify/Music) e controles de reprodução
    └── widgets/                   # Widgets secundários agrupados
        ├── init.lua               # Carregador dos widgets
        ├── battery.lua            # Status de carga e tempo restante de bateria
        ├── volume.lua             # Indicador, slider e seletor de dispositivos de som
        ├── wifi.lua               # Velocímetro de rede e popup de diagnóstico
        └── cpu.lua                # Gráfico histórico de utilização de CPU
```

---

## 3. Dependências e Pré-requisitos

### Softwares do Sistema e Ferramentas CLI
- **macOS** (com suporte a Apple Silicon ou Intel)
- **Homebrew**:
  ```bash
  brew tap FelixKratz/formulae
  brew tap nikitabobko/tap
  brew install sketchybar aerospace lua stow switchaudio-osx nowplaying-cli borders
  ```
- **Fontes Necessárias**:
  ```bash
  brew install --cask sf-symbols font-sf-mono font-sf-pro font-sketchybar-app-font
  ```
  *(Nota: O chevron de `front_app.lua` utiliza `Hack Nerd Font:Bold:14.0`).*

### Extensão SbarLua (`sketchybar.so`)
O projeto necessita do módulo compilado `sketchybar.so` localizado em:
`~/.local/share/sketchybar_lua/sketchybar.so`

Instalação se não estiver presente:
```bash
git clone https://github.com/FelixKratz/SbarLua.git /tmp/SbarLua
cd /tmp/SbarLua
make install
rm -rf /tmp/SbarLua
```

---

## 4. Arquitetura e Fluxo de Execução

1. **Inicialização**:
   - O daemon do SketchyBar invoca `./sketchybarrc` (interpretado por `/usr/bin/env lua`).
   - `sketchybarrc` executa `require("helpers")` e `require("init")`.
   - `helpers/init.lua` injeta `~/.local/share/sketchybar_lua/?.so` no `package.cpath` do Lua e dispara `make` silencioso em `helpers` para garantir que os binários C estejam compilados.

2. **Carregamento em Lote (Batching)**:
   - `init.lua` invoca `sbar.begin_config()`. Todas as chamadas de configuração subsequentes (`bar.lua`, `default.lua`, `items`) são enfileiradas e enviadas ao daemon em uma única transação atômica através de `sbar.end_config()`, minimizando flickering e tempo de renderização.

3. **Loop de Eventos (`sbar.event_loop()`)**:
   - `sbar.event_loop()` mantém o processo Lua escutando eventos disparados pelo SketchyBar e executando os callbacks registrados via `:subscribe(...)`.

4. **Event Providers Nativos (C)**:
   - `items/widgets/cpu.lua` e `items/widgets/wifi.lua` iniciam os binários `cpu_load` e `network_load` em segundo plano via `sbar.exec(...)`.
   - `cpu_load` lê estatísticas do processador e emite o evento `cpu_update`.
   - `network_load` utiliza um stream unbuffered via pseudo-terminal (PTY) com `nettop` (imune a filtros de rede/NetworkExtensions que zeram contadores BSD no macOS) e fallback para `sysctl IFMIB`, enviando `network_update` via Mach Port com upload e download formatados.

---

## 5. Comandos Úteis de Desenvolvimento

### Recarregar Configuração
```bash
# Recarrega a barra e executa novamente o sketchybarrc
sketchybar --reload
```

### Testar Execução do Script Diretamente
```bash
# Permite inspecionar logs, prints e erros de sintaxe Lua
lua ~/.config/sketchybar/sketchybarrc
```

### Compilar Provedores C Manualmente
```bash
cd ~/.config/sketchybar/helpers && make
```

### Inspecionar Itens e Estados
```bash
# Consultar propriedades de um item específico (retorna JSON)
sketchybar --query widgets.battery
sketchybar --query workspace.1

# Disparar um evento manualmente para testar o comportamento
sketchybar --trigger front_app_switched INFO="Ghostty"
sketchybar --trigger aerospace_workspace_change FOCUSED_WORKSPACE="1"
```

### Gerenciamento de Dotfiles (GNU Stow)
```bash
# A partir da raiz do repositório dotfiles (~/dotfiles)
stow -R sketchybar  # Re-linka o pacote sketchybar para ~/.config/sketchybar
```

---

## 6. Padrões de Código e Boas Práticas

1. **Chamadas Assíncronas**:
   - Sempre utilize `sbar.exec("comando", callback)` para comandos shell dentro de callbacks de eventos ou cliques.
   - Evite `io.popen` e `os.execute` dentro de callbacks de atualização frequente para não bloquear a thread do event loop do Lua.

2. **Gerenciamento de Popups**:
   - Popups que listam elementos dinâmicos (como `volume.device.*` em `items/widgets/volume.lua`) devem remover os itens criados anteriormente ao fechar (`sbar.remove('/volume.device\\.*/')`).
   - Use inscrições em `mouse.exited.global` para fechar automaticamente popups ao mover o cursor para longe da barra.

3. **Cores e Transparências**:
   - Utilize a paleta unificada em `colors.lua` (esquema **Tokyo Night**).
   - Para variações de opacidade, use a função auxiliar `colors.with_alpha(color, alpha)`.

4. **Tratamento de Espaçamento e Agrupamento**:
   - Itens de preenchimento (`sbar.add("item", { width = settings.group_paddings })`) são usados para separar grupos visuais.
   - Brackets (`sbar.add("bracket", ...)`) são utilizados para encapsular conjuntos de itens com bordas, fundos estilizados ou popups compartilhados.
