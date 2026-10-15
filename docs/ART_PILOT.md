# Marcelo — piloto de arte 2D

Esta versão introduz 56 desenhos novos do Marcelo e a reprodução dessas poses no combate Godot. É o piloto da direção visual, não a renovação concluída dos 13 personagens.

## Ver em movimento

Abra o jogo e selecione **TESTAR MARCELO / NOVA ARTE**. A/D anda; W pula; S agacha; F soca; G chuta; S+F e S+G executam golpes baixos; H defende; T lança código; Y executa ascendente; Q cria sentinela; U invoca enxame com barra cheia.

**F3** alterna uma demonstração automática, enviando comandos pelo mesmo motor usado pelo jogador. **F4** compara a arte nova e a original sem alterar colisões, dano ou simulação. R reinicia e recarrega a barra no treinamento. Esc pausa; Enter continua; Esc novamente volta ao menu.

![Prévia animada do soco](previews/marcelo-punch-v1.gif)

## Entrega visual

| Atlas | Desenhos | Uso |
|---|---:|---|
| punch | 8 | Guarda, preparação, extensão e recuperação do soco |
| walk | 8 | Passadas alternadas com movimento de quadril, tronco e braços |
| states | 16 | Guarda, defesa, salto, aterrissagem, impacto, dizzy, queda e vitória |
| combat | 16 | Chute, ascendente e preparação/emissão/recuperação de poder |
| low | 8 | Soco agachado e rasteira |

Os originais gerados estão em `assets/source/marcelo-art-v1/`. Os atlases preparados estão em `assets/characters/marcelo/art-v1/`. `data/characters/marcelo-art-v1.json` registra recortes, origem nos pés e escala por atlas. O empacotador extrai os desenhos por componentes conexos e preserva seus pixels; ele não desenha poses intermediárias.

Preparação reprodutível (fora do runtime):

```bash
python -m pip install pillow numpy scipy
python tools/pack_pilot_art.py assets/source/marcelo-art-v1
```

O jogo seleciona os desenhos em `PilotArt` pela fase do golpe e tick autoritativo. A interpolação da posição no render é independente: não há morph automático entre rostos/membros nem esqueleto girando recortes. Poses-chave podem permanecer expostas por vários ticks. A simulação a 120 Hz não exige 120 desenhos diferentes por segundo.

## Impacto e poderes

`CombatImpact` consome eventos com IDs para faíscas, flash de contato, escurecimento de super e abalo visual. `SpriteFighterView` cria rastros a partir das próprias poses. Hitstop, hitstun e blockstun pertencem à simulação. `PowerView` desenha código animado, rotores/laser de drones e efeitos próprios por personagem; entidades de projétil têm ID, idade, delay e TTL restauráveis.

As vozes PT-BR anteriores foram preservadas. A nova arte é do Marcelo. Fumaça, garfos e livros são efeitos procedurais sobre o elenco importado; os outros personagens ainda precisam do mesmo trabalho de redesenho e revisão de animação.

## Limites e revisão

É uma primeira passagem de arte: exige revisão visual de continuidade, silhueta, apoio de pés e alcance. Não se afirma equivalência de qualidade com a produção da Capcom. As caixas importadas são a base de gameplay; F4 mantém as mesmas regras para permitir comparar a apresentação. O alinhamento fino de cada novo desenho com as caixas ainda é parte da revisão do personagem.

Há desenhos compartilhados entre forças e alguns golpes contextuais; isto não equivale a desenhar uma sequência independente para cada um dos 36 recursos do Marcelo. Agarrões e transições especiais ainda precisam de arte dedicada.

## Geração

Ferramenta: geração de imagens integrada, com referências locais do próprio personagem. Nenhuma arte de lutador da Capcom foi incorporada.

Prompt comum: “Production animation sprite atlas for Street Vicente Fighter. Preserve Marcelo's recognizable face, swept-back dark brown hair, full beard, stocky adult build, black long open coat, black shirt, trousers and boots, no glasses. Hand-drawn arcade 2D, strong ink outlines, three-tone cel shading. Fixed side/three-quarter camera facing right; consistent anatomy, scale and identity; full bodies and complete limbs; transparent background; no text, grid, scenery or baked-in effects.”

Variações aplicadas: punch — 8 chaves consecutivas de guarda/preparação/soco/recuperação; walk — 8 chaves de contato/apoio/passagem alternadas; states — 16 estados de defesa, salto, impacto e queda; combat — 8 chaves de chute, 4 de ascendente, 4 de emissão de poder; low — 4 chaves de soco agachado e 4 de rasteira. As referências e os arquivos originais permanecem versionados para revisão.
