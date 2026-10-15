# Street Vicente Fighter · Godot 4

Base funcional da migração para **Godot 4.5.1 + GDScript**, exportável para WebAssembly/WebGL 2 e GitHub Pages. Projeto independente de [Street-Vicente-Fighter-](https://github.com/Marcelo-Preigschadt/Street-Vicente-Fighter-).

Esta etapa implementa **Versus local e treino**, com dois manequins de validação. O elenco, sprites, vozes, poderes, campanhas e sessões online do jogo original ainda precisam ser portados. Não há migração automática nem rollback online pronto.

## Executar no Codespaces

```bash
bash tools/setup_godot.sh
bash tools/test.sh
bash tools/export_web.sh
python3 -m http.server 8060 --directory build/web
```

Abra a porta **8060** no painel **Ports** do Codespaces e clique no canvas. O editor gráfico não é necessário para importar, testar e exportar. O `.devcontainer` instala editor e templates Web no primeiro uso. Requer Linux x86_64, Python 3.11+, curl, bash e ripgrep; o container padrão fornece esses componentes. O primeiro download do pacote oficial de templates é grande: o instalador preserva apenas os templates Web sem threads após extrair.

No desktop: instale **Godot 4.5.1 Standard**, importe `project.godot` e pressione **F5**. Editor, templates e CI usam a versão fixada em `tools/godot_version.txt`. Uma atualização exige repetir os testes nativos e Web.

## Controles

| Ação | Jogador 1 | Jogador 2 | Controle USB de cada slot |
|---|---|---|---|
| Mover | A / D | ← / → | Direcional ou analógico esquerdo |
| Pular | W | ↑ | Direcional/analógico para cima |
| Agachar | S | ↓ | Direcional/analógico para baixo |
| Soco | F | J | X / quadrado |
| Chute / voadora | G | K | A / cruz |
| Rasteira | S + G | ↓ + K | Baixo + chute |
| Defender | H ou segurar para trás | L ou segurar para trás | L1 / LB |

**F1** alterna caixas; **F2** alterna P2 humano, parado, defesa alta e defesa baixa; **R** reinicia; **Esc** pausa/continua; **F11** alterna tela cheia. No navegador, pressione um botão do controle para permitir sua detecção. Mapeamentos físicos dependem do navegador/controle. Perda de foco pausa a sessão local; Esc continua.

## Implementado

- Resolução lógica de **1280×720**, letterbox e renderer Compatibility.
- Simulação inteira, ponto fixo **1/256 px**, **120 ticks/s**, separada de SceneTree e apresentação.
- FSM: Idle, Walk, Crouch, Jump, Attack, Hitstun, Block e KO.
- Buffer de **12 ticks / 100 ms**, edges explícitos e SOCD horizontal neutro.
- Resources `.tres` para personagens, golpes e janelas de hitbox.
- Hurtboxes de cabeça/tronco/pernas, AABBs espelhados, pushboxes, paredes, defesa mid/low/overhead.
- Startup/active/recovery, hitstop, hitstun, blockstun, um acerto por alvo/golpe e trades simultâneos.
- HUD, HP, timer, reset, treino, interpolação visual e manequim com membros articulados.
- Snapshot/restore, hash de estado e histórico **local** com correção/replay para testes. **Sem transporte ou sessão rollback online.**
- Pipeline de testes, exportação e deployment; pacote independente `StreetVicente-Web` nos artefatos do Actions.

## Organização

```text
project.godot              configuração 2D, 120 Hz, cena principal
export_presets.cfg        preset Web sem threads
autoloads/                configuração de input, fora da simulação
assets/characters/        futuros atlases, retratos e rigs do elenco
assets/audio/             futuras vozes e efeitos
data/characters/          CharacterData (.tres)
data/moves/               MoveData + HitboxData (.tres)
data/stages/              futuros dados dos cenários
scenes/                   entrada do projeto
scripts/characters/       modelo serializável dos lutadores
scripts/combat/           FSM, frame data e matemática de colisão
scripts/input/            pacotes, buffer e teclado/gamepad
scripts/match/            simulação e controlador local
scripts/presentation/     manequim/IK visual
scripts/stages/           cenário de treino
scripts/ui/               HUD e feedback visual
scripts/net/              histórico local; transporte futuro
scripts/story/            ponto de extensão da campanha
tests/                    regressões headless do núcleo
tools/                    instalação, testes e exportação
.devcontainer/            ambiente Codespaces
.github/workflows/        validação e GitHub Pages
```

## Frame data

**Frames de design: 60 Hz. Ticks de simulação: 120 Hz.** Não copie frames como ticks. `4f = 8 ticks = 66,67 ms`.

| ID | Startup | Active | Recovery | Dano | Hitstun | Blockstun | Nível |
|---|---:|---:|---:|---:|---:|---:|---|
| jab | 4f | 3f | 9f | 44 | 17f | 10f | Mid |
| kick | 8f | 4f | 17f | 80 | 23f | 13f | Mid |
| sweep | 10f | 5f | 21f | 90 | 26f | 15f | Low |
| air_kick | 5f | 7f | 12f | 70 | 20f | 12f | Overhead |

O `jab.tres` declara startup 4, active 3, recovery 9 e hitbox `Rect2i(24, -156, 112, 38)` nos frames `[4, 7)`. Ocupa ticks 0–31: startup 0–7, active 8–13, recovery 14–31. Pés são a origem; Y negativo aponta para cima; espelhamento usa `x' = -(x + largura)`. A animação visual não controla a hitbox.

Para outro lutador, duplique `data/characters/prototype.tres`, altere ID e associe Resources de golpes próprios. Use IDs estáveis e dados imutáveis por partida. O manequim atual não representa os professores/alunos.

## Publicar no GitHub Pages

1. Em **Settings → Pages → Build and deployment → Source**, escolha **GitHub Actions** se ainda não estiver configurado. O workflow tenta habilitar Pages; a configuração inicial pode exigir essa escolha manual uma vez.
2. Cada push na `main` executa importação, testes, exportação single-thread e deployment. Em **Actions**, abra `Godot · Validate, export and deploy Web`. Também pode usar **Run workflow**.
3. Após deployment bem-sucedido: **https://marcelo-preigschadt.github.io/StreetVicente/**.

O diretório publicado é **`build/web/`**, com `index.html`, `index.js`, `index.wasm`, `index.pck` e os demais arquivos gerados. Não renomeie arquivos após exportar nem publique apenas o HTML. `.nojekyll` é gerado automaticamente. Os caminhos relativos preservam `/StreetVicente/`.

O build e o artefato para download são independentes da habilitação inicial do Pages. Nenhum segredo de backend é necessário nesta etapa. Use HTTP/HTTPS para executar o build.

## Continuidade

Física inteira e replay são uma base para determinismo, **não uma certificação entre plataformas**. Antes do online: comparar hashes/replays no Web e nativo, implementar protocolo versionado, previsão, confirmação, rollback limitado e deduplicação de efeitos. IK visual e partículas não entram no snapshot.

Esta base oferece um round, sem combos/cancels, throws, knockdown/wakeup, supers, projéteis, IA ofensiva ou campanha. O próximo recorte é migrar **um personagem real completo** e comparar com o motor original antes de ampliar o elenco. [Plano de migração](docs/MIGRATION.md) · [Arquitetura](docs/ARCHITECTURE.md) · [Web e Codespaces](docs/WEB.md).

## Referências oficiais

- [Godot 4.5 — exportação Web](https://docs.godotengine.org/en/4.5/tutorials/export/exporting_for_web.html)
- [Godot 4.5 — WebRTC](https://docs.godotengine.org/en/4.5/tutorials/networking/webrtc.html)
- [Godot — linha de comando](https://docs.godotengine.org/en/4.5/tutorials/editor/command_line_tutorial.html)
- [GitHub Pages — workflows](https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages)
