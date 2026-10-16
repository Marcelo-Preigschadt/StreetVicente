# Street Vicente Fighter · Godot 4

**Jogar:** https://marcelo-preigschadt.github.io/StreetVicente/

Projeto em Godot 4.5.1 / GDScript, 1280×720, simulação a 120 Hz e exportação Web sem threads para GitHub Pages. O repositório [original Canvas](https://github.com/Marcelo-Preigschadt/Street-Vicente-Fighter-) foi usado em leitura; as alterações ficam neste projeto.

## Apresentação padrão

A primeira opção, **TREINO LIVRE**, abre Marcelo × Rafael com animação 2D. A revisão v8 integra 64 desenhos novos do Rafael, 64 do Adriano e 8 de soco aéreo do Marcelo; mantém os retratos e os drones anteriores. **F3** demonstra os movimentos; **F4** compara com a arte importada. [Escopo, fontes e validação da revisão](docs/ARCADE_V8.md).

O protótipo procedural 3D foi rejeitado e retirado dos fluxos publicados, incluindo F6. Seu código permanece isolado para referência técnica; a direção atual é 2D quadro a quadro. [Registro do protótipo arquivado](docs/PILOT_3D.md).

## Arte 2D

A interface inclui menu, seleção com 13 rostos, prévias em corpo inteiro, barras espelhadas e apresentação de super. A revisão v8 acrescenta cels de contato/defesa, onda de código e pergaminho, sequência ROUND → FIGHT → K.O./TIME OVER → vitória, cenário em toda a janela e cancel confirmado de soco aéreo em chute. A revisão completa do restante do elenco continua pendente. [Evolução anterior da arte](docs/ART_PILOT.md).

[Auditoria da migração e correções desta revisão](docs/MIGRATION_V6.md): recuperação após golpes, escala do Adriano, circuito/pontuação e progresso do História.

## Modos e estado da migração

| Sistema | Nesta versão |
|---|---|
| Seleção | 13 personagens; professores/alunos; retratos, frases e vozes preservados |
| Combate | CPU, 2 jogadores locais e treinamento; forças leve/média/forte; golpes baixos/aéreos, cancels básicos, defesa, agarrão, tontura com recuperação, levantamento rápido, double tap, Custom e contra-ataque de guarda |
| Arcade / CPU | Circuito de 12 rivais, rota, bônus, Continue e recorde persistente |
| Rounds | Melhor de três; Round/número/Fight com bloqueio de comandos; K.O./Time Over/vitória/Perfect; barra super preservada |
| Poderes | Projéteis e efeitos por personagem; código e drones/enxame do Marcelo; VFX animados e lasers independentes; compartilhados com o História |
| Arte nova | Marcelo com 72 cels; Rafael com 64 novos + 8 socos v5; Adriano com 64 novos; Gustavo com 8 socos v5; demais preservados |
| História | Quatro atos, ondas/chefes e exoesqueleto, diálogos de entrada, turno de 15 minutos, pontos por derrotas, objetos/perigos, retry de ato e save/retomada; coop ainda pendente |
| Rollback | Snapshot/replay local verificado; online permanece indisponível até implementação e testes reais de sessão/rede |
| Web | GitHub Actions importa/testa/exporta e só publica após QA do WASM |

## Controles

| Ação | P1 | P2 |
|---|---|---|
| Mover / baixo / pular | A/D · S · W ou Espaço | ←/→ · ↓ · ↑ ou Num0 |
| Soco / chute | F / G | J / K |
| Defesa | H ou segurar para trás | L ou segurar para trás |
| Especial / ascendente / super | T / Y / U | O / I / P |
| Agarrão / drone do Marcelo | E / Q | N / M |
| Custom / contra-ataque da guarda | C / X | . / , |
| Passo de avanço / recuo | Duplo toque A ou D | Duplo toque ← ou → |
| Força | Ctrl leve · sem modificador média · Shift forte | Mesmo modificador |

**F1** mostra caixas; **F2**, no treino, alterna P2 humano/parado/defesa alta/baixa; **F3** demonstra o piloto; **F4** compara arte; **R** reinicia; **Esc** pausa e novamente volta ao menu; **Enter** continua; **F11** tela cheia. No História, W/S muda a profundidade e Espaço pula; F/E pega uma mesa/cadeira próxima e F arremessa. Kits recuperam 220 de vida. O menu História oferece retomar o checkpoint; N começa outra campanha. R repete o ato atual. No circuito, R/Continue reinicia o mesmo rival e zera os pontos, preservando o recorde. Teclado e gamepads USB são suportados; mapeamento depende do dispositivo/navegador.

## Codespaces e exportação

```bash
bash tools/setup_godot.sh
bash tools/test.sh
bash tools/export_web.sh
python3 -m http.server 8060 --directory build/web
```

Abra a porta 8060 em **Ports**. Para o editor desktop, importe `project.godot` no Godot 4.5.1 Standard e execute F5. Editor/templates são fixados em `tools/godot_version.txt`.

No GitHub, **Settings → Pages → Source: GitHub Actions**. Push na `main` executa testes headless, exportação single-thread, QA no Chromium/WebGL e deployment. O artefato `StreetVicente-Web` contém o pacote completo; `StreetVicente-Web-QA` contém screenshots, vídeo e relatório dos testes. Publique todo `build/web/`, incluindo `.wasm`, `.pck`, `.js` e `.nojekyll`.

## Organização

```text
assets/characters/marcelo/art-v1/  novos atlases de animação
assets/source/marcelo-art-v1/      originais da arte; excluídos do export
assets/legacy/                     elenco, cenários, objetos e áudio importados
data/legacy/                       catálogo imutável e commit da origem
data/characters/                   Resources e registro da nova arte
data/moves/                        exemplos editáveis de frame data (.tres)
autoloads/                         input e configuração do projeto
scripts/characters/                FighterModel serializável + roster
scripts/combat/                    FSM, frame data e AABB inteiro
scripts/input/                     input local, edges e buffer
scripts/match/                     simulação 1×1, CPU e fluxo do jogo
scripts/presentation/              animação por ticks, arte, áudio, poderes e impacto
scripts/story/                     campanha offline
scripts/net/                       replay local; não há transporte online ainda
scenes/                            entrada do projeto
tests/                             regressões headless
tools/                             importação, preparação de arte, exportação e QA
.github/workflows/                 validação e GitHub Pages
```

Frame data usa **60 Hz de design**, convertido para **120 ticks/s**. Exemplo do soco médio do Marcelo: startup 6f, active 4f, recovery 12f = 44 ticks. Dados de desenho e colisão são separados; a fase da animação não altera as regras do golpe. O exemplo original `data/moves/jab.tres` continua útil para criar novos Resources sem o catálogo importado.

A origem dos dados está fixada em `data/legacy/source-lock.json`. Para reimportar assets/dados aprovados, execute `node tools/import_legacy.mjs` com Node 22+ ou use o workflow de importação. Nenhum JavaScript do motor Canvas é executado no jogo Godot.

[Arte do piloto](docs/ART_PILOT.md) · [Plano e limites da migração](docs/MIGRATION.md) · [Arquitetura](docs/ARCHITECTURE.md) · [Web](docs/WEB.md)
