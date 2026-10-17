# Street Vicente Fighter · Godot 4

**Jogar:** https://marcelo-preigschadt.github.io/StreetVicente/

Projeto em Godot 4.5.1 / GDScript, 1280×720, simulação a 120 Hz e exportação Web sem threads para GitHub Pages. O repositório [original Canvas](https://github.com/Marcelo-Preigschadt/Street-Vicente-Fighter-) foi usado em leitura; as alterações ficam neste projeto.

## Apresentação padrão

A primeira opção, **TREINO LIVRE**, abre Marcelo × Rafael com animação 2D. A revisão v8 integra 64 desenhos novos do Rafael, 64 do Adriano e 8 de soco aéreo do Marcelo; mantém os retratos e os drones anteriores. **F3** demonstra os movimentos; **F4** compara com a arte importada. [Escopo, fontes e validação da revisão](docs/ARCADE_V8.md).

O protótipo procedural 3D foi rejeitado e retirado dos fluxos publicados, incluindo F6. Seu código permanece isolado para referência técnica; a direção atual é 2D quadro a quadro. [Registro do protótipo arquivado](docs/PILOT_3D.md).

## Arte 2D

A interface inclui menu, seleção com 13 rostos, prévias em corpo inteiro, barras espelhadas e apresentação de super. A revisão v8 acrescenta cels de contato/defesa, onda de código e pergaminho, sequência ROUND → FIGHT → K.O./TIME OVER → vitória, cenário em toda a janela e cancel confirmado de soco aéreo em chute. A revisão v9 redesenha João (64 cels) e a caminhada em guarda do Adriano. Os demais personagens continuam sendo revisados um por vez. [Revisão v9, controles e validação](docs/ARCADE_V9.md). [Evolução anterior da arte](docs/ART_PILOT.md).

A revisão v10 corrige a vibração após K.O., implementa o **rolinho elétrico do João em H** com três acertos e rebote na defesa, amplia o avanço dos ganchos e apresenta novos efeitos de carga, rastro e impacto para os 13 lutadores. [Regras, arte e validação v10](docs/POWERS_V10.md).

[Auditoria da migração e correções desta revisão](docs/MIGRATION_V6.md): recuperação após golpes, escala do Adriano, circuito/pontuação e progresso do História.

## Modos e estado da migração

| Sistema | Nesta versão |
|---|---|
| Seleção | 13 personagens; professores/alunos; retratos, frases e vozes preservados |
| Combate | CPU, 2 jogadores locais e treinamento; forças leve/média/forte; golpes baixos/aéreos, cancels básicos, defesa, agarrão, tontura com recuperação, levantamento rápido, double tap, Custom e contra-ataque de guarda |
| Arcade / CPU | Circuito de 12 rivais, rota, bônus, Continue e recorde persistente |
| Rounds | Melhor de três; Round/número/Fight com bloqueio de comandos; K.O./Time Over/vitória/Perfect; barra super preservada |
| Poderes | Rolinho elétrico físico do João; ganchos com avanço e arco ativo; projéteis e efeitos por personagem; código e drones/enxame do Marcelo; VFX animados e lasers independentes; compartilhados com o História |
| Arte nova | Marcelo com 72 cels; Rafael com 64 novos + 8 socos v5; Adriano com 64 novos (caminhada v9); João com 64 novos + 8 cels de rolinho; Gustavo com 8 socos v5; demais preservados |
| História | Quatro atos, ondas/chefes e exoesqueleto, diálogos de entrada, turno de 15 minutos, pontos por derrotas, objetos/perigos, retry de ato e save/retomada; coop ainda pendente |
| Rollback | Snapshot/replay local verificado; online permanece indisponível até implementação e testes reais de sessão/rede |
| Web | GitHub Actions importa/testa/exporta e só publica após QA do WASM |

## Controles

| Ação | P1 | P2 |
|---|---|---|
| Mover / baixo / pular | A/D · S · W ou Espaço | ←/→ · ↓ · ↑ ou Num0 |
| Socos leve / médio / forte | T / F / Y | Num7 / J ou Num8 / Num9 |
| Chutes leve / médio / forte | V / G / B | Num4 / K ou Num5 / Num6 |
| Defesa | R ou segurar para trás | O ou segurar para trás |
| Poder / gancho / super | H / U / Q | L / ; / . |
| Agarrão / drone do Marcelo | E / Z | N / I |
| Custom / contra-ataque da guarda | C / X | M / , |
| Passo de avanço / recuo | Duplo toque A ou D | Duplo toque ← ou → |

Teclado segue o **mapa original do Canvas**, com força por botão. **F8** reinicia (R voltou a defender); **F1** caixas, **F2** alvo de treino, **F3** demonstração, **F4** compara arte, **Esc** pausa/menu, **Enter** continua. No História, W/S muda profundidade e Espaço pula; F/E pega objetos e F arremessa. F8 repete o ato ou rival; Continue zera pontos e mantém recorde.

Os botões **CONTROLE USB** e **TELA CHEIA** ficam no rodapé de todas as telas. **F10** abre o painel USB; **F11** também alterna tela cheia. Conecte o controle e pressione um botão para o navegador reconhecê-lo. No painel, escolha jogador/dispositivo, clique na ação e pressione o botão ou mova um eixo; ajuste a zona morta e restaure padrões quando necessário. Mapas são salvos por modelo de dispositivo no navegador; dois controles têm slots separados. Ao desconectar ou trocar um controle, o combate pausa.

Padrão USB: analógico/direcional move; A pula/confirma; B chuta/volta; X soca; Y solta poder; LB defende; RB soco forte; RT chute forte; Back agarra; L3 drone; R3 contra; Start pausa. Como no original, LT+Y dá gancho, LT+RB super e LT+Start Custom; LT+X dá poder. Essas ações podem receber botões diretos no painel. Os números exibidos são os índices normalizados do Godot: a identificação de A/B/X/Y depende do modelo e do navegador.

A abertura Web usa o título e as cores do jogo, com progresso de download e mensagem de erro/repetição. A imagem inicial Godot está desativada; baixar WASM/PCK ainda é necessário.

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
