# História v27 — corredor, cantina e unidades do NIT

A revisão anterior conservava os inimigos antigos e duas ilhas de mobília
distribuídas sobre um fundo que rolava em outra velocidade. O primeiro ato
agora tem duas áreas desenhadas para a fase: corredor escolar e cantina.
O chão contínuo e os elementos jogáveis compartilham a mesma projeção e
deslocamento de câmera. As mesas ficam diante da cantina, na faixa de
refeições, deixando a passagem da luta livre.

## Mudança visível

- Duas novas pinturas de cenário em `assets/stages/v27/`, com arquitetura
  lateral, iluminação e piso comuns.
- Sessenta e seis desenhos novos de inimigos: 25 do guarda, 25 do comandante
  e 16 do drone. Os 16 perfis de inimigos da campanha usam essa família
  visual, com escala e paletas próprias. Os bípedes têm oito poses de passos,
  preparação, extensão do golpe, recuperação, reação e queda. O avanço é
  sincronizado à distância percorrida; a corrida de ataque também usa passos.
- O empacotador encontra cada corpo completo pela transparência. Isso
  preserva punhos que ultrapassam as células sugeridas pelo gerador.
- Mobília e máquina de bebidas redesenhadas com o mesmo material e traço.
- HUD do História mais compacto: vida e energia no alto, ajuda inicial
  temporária e interação mostrada perto do objeto/inimigo.
- A câmera enquadra a luta e abre a próxima área gradualmente após a vitória.
  O estado da câmera participa do save/replay cooperativo.
- Faixa de profundidade ampliada e distância corporal por porte do inimigo,
  reduzindo o agrupamento de máquinas no mesmo ponto.
- Golpes comuns dos inimigos atingem pela região do braço. Os efeitos dos
  golpes do jogador são posicionados na interseção real das caixas.
- O agarrão tem preparação legível e proteção durante a soltura. Os desenhos
  aprovados dos jogadores foram preservados.
- O alcance em profundidade do agarrão e dos golpes de IA inclui a borda
  corporal: uma aproximação diagonal não exige atravessar a própria colisão.

## Entrega e carregamento

O código e as artes estão na revisão do projeto Godot existente. A entrega
pretendida é o mesmo GitHub Pages, após a validação, e não um protótipo
permanentemente separado.

O PCK exportado recebe um nome derivado de seu SHA-256. O HTML referencia esse
nome e publica `build.json`. Isso impede que um pacote antigo em cache esconda
as alterações da revisão. A URL com `?v=27` renova também a leitura do HTML.

Os sprites, rostos, poderes, vozes e controles aprovados dos 13 jogadores
continuam existentes. Versus/treino não usam o HUD nem os inimigos novos do
História. Outros atos recebem os novos inimigos e as correções de projeção;
suas pinturas de fundo ainda são as anteriores. Esta revisão não declara
qualidade comercial equivalente a Streets of Rage 4.

## Origem dos desenhos

As seis imagens foram criadas pela ferramenta integrada de geração de imagens:
os dois cenários, os três conjuntos de animação e o conjunto de objetos.
Os prompts integrais estão em `story-v27-image-prompts.json`.
Os originais estão em `assets/source/story-v27/`, e os PNGs de cenário em
`assets/stages/v27/`. `tools/pack_story_v27.py` apenas registra, recorta e
codifica os desenhos, sem inventar poses ou aplicar escala por quadro.

## Validação

- Regressões nativas de combate, quatro atos, custos de energia, controles,
  câmera, save/rollback e campanha cooperativa.
- Validação e exportação Web com PCK identificado pelo conteúdo.
- Navegador por comandos reais: percurso, combate, energia, interação com
  mobília, agarrão/arremesso e avanço do primeiro ato.
- A publicação só deve ocorrer após os checks exigidos pelo fluxo do projeto.
