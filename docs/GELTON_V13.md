# Gelton · revisão v13

Revisão exclusiva do Gelton seguindo o padrão visual aprovado no Gustavo v12. Rosto, cabelo cacheado, barba, brinco, colar, camiseta bordô, calça branca, cordão e pés descalços foram preservados. Retrato e vozes continuam os existentes.

## Desenhos e animação

As fontes contêm 80 novos desenhos de corpo inteiro, divididos em 10 folhas. O jogo organiza 80 posições de animação: 76 desenhos distintos e quatro reutilizações explícitas da guarda para manter continuidade nas transições. Não há ampliação dos pixels da origem, deformação do corpo, cabeça colada em polígonos ou rotação de uma imagem parada para simular acrobacias.

| Sequência | Quadros | Comportamento |
|---|---:|---|
| Estados | 16 | Guarda, defesa alta/baixa, esquiva, salto, aterrissagem, reações, tontura, queda e vitória |
| Ginga / caminhada | 8 | Ginga em 1,6 s no idle, caminhada vinculada à distância real, ciclo de 210 px |
| Palmada | 8 | Preparação, extensão, contato e recolhimento a partir da ginga |
| Meia-lua | 8 | Câmara do joelho, arco da perna, extensão e retorno |
| Negativa / rasteira | 8 | Palmada baixa e varrida apoiada; guarda baixa compartilhada com o estado agachado |
| Ataques aéreos | 8 | Palmada e chapa no ar com preparação e recolhimento |
| Pincelada | 8 | Preparação do tronco, palma estendida, recuperação e guarda |
| Aú | 8 | Entrada lateral, apoio, inversão, rotação aérea e aterrissagem |
| Roda | 8 | Apoio das mãos, bananeira, tesoura das pernas, descida e guarda |

As fontes selecionadas têm oito poses por imagem, com escala registrada por anatomia. Palmadas/golpes baixos usam folhas 2×4 para deixar os membros completos e separados. As demais usam 4×2. O registro de raiz, piso, palmas, pés e hitboxes está em `assets/source/gelton-v13/registration.json`.

## Poderes mantidos

| Comando P1 | Poder | Apresentação |
|---|---|---|
| H | Pincelada Cromática | Tinta se forma na palma; pincelada com frente compacta, cauda e gotas; respingos no contato |
| U | Aú das Cores | Aú desenhado em fases, avanço/subida da simulação e crescente de tinta na área ativa |
| Q | Roda das Artes | Bananeira e tesoura das pernas com arco pintado; cinco ondas lançadas pelos pés registrados |

O atlas exclusivo contém 16 quadros de efeitos: pincelada, respingo, crescente e preparação/soltura. A defesa recebe um contato menor e azulado. O flash genérico foi reduzido somente nos poderes do Gelton para deixar os desenhos de tinta visíveis. Não foram alterados dano, velocidade dos projéteis, frame data, custo de barra, quantidade de ondas, nomes ou vozes.

A geometria ofensiva normal foi registrada sobre as palmas/pés desenhados. Os crescentes ativos de U continuam compartilhando o perfil determinístico já existente com o apresentador. O rastro da tinta é decorativo e não aumenta o raio dos projéteis. Simulação, snapshots, pausa e hitstop continuam independentes dos efeitos.

## Fontes e reprodução

- Desenhos e prompts: `assets/source/gelton-v13/`. [Prompts finais, referências, arquivos escolhidos e método](../assets/source/gelton-v13/provenance.json).
- Método: ferramenta integrada `image_gen`; processamento posterior limitado a recorte, alpha, atlas lossless e registro de geometria. Não houve geração de música ou de novas vozes.
- Sprites usados: `assets/characters/gelton/arcade-v13/`.
- Efeitos: `assets/effects/gelton-v13/paint.webp`.
- Manifestos: `data/characters/gelton-arcade-v13.json` e `gelton-effects-v13.json`.
- Seleção de quadros: `scripts/combat/gelton_pose_v13.gd`.
- Efeitos: `scripts/presentation/gelton_fx_v13.gd`.
- Reprodução: `python3 tools/pack_gelton_v13.py` com Pillow, NumPy e SciPy.

## Validação

`bash tools/test.sh`: 66.158 verificações de combate/replay sem falhas, além dos fluxos de shell, História, configurações e controles. A cobertura específica verifica ginga, proporção baixa, todos os estados/golpes sem fallback, colisões apenas no active, contatos nos dois sentidos e origem das cinco ondas por pose.

`tests/render_gelton_v13.gd` captura a apresentação real em Compatibility, com Gelton ao lado do Gustavo aprovado, oito fases da ginga, ataques e as três sequências de poderes; inclui acerto e defesa da tinta.

`tools/smoke_gelton.cjs` usa teclado real no WASM exportado sob `/StreetVicente/`: seleção Gelton × Gustavo, caminhada, S+F, H, U, Q e bloqueio de projétil. Observa o estado de QA sem injetar posição, vida ou relógios. A publicação exige também a aprovação das suítes Web anteriores.

Gustavo e os demais personagens permanecem com sua arte anterior. Todas as alterações ficam no StreetVicente; o repositório original não foi modificado.
