# História v26 — protótipo Godot, referência Streets of Rage 4

Streets of Rage 4 é a referência de direção artística e sensação de combate.
O projeto continua Godot 4.5.1 com exportação Web. Esta revisão é uma amostra
para avaliação, não uma reprodução do jogo comercial nem uma certificação de
qualidade equivalente.

## Implementado

- Novo cenário ilustrado original para a abertura no pátio/cantina, com
  contorno desenhado, sombras gráficas e piso livre de objetos incorporados.
  Os demais atos conservam seus cenários anteriores.
- `OpenBorMotion`, adaptado de `testmove/common_trymove` do OpenBOR:
  colisão separada em X/profundidade, deslizamento pela borda, bloqueio de
  deslocamentos rápidos e saída de sobreposições presentes em saves antigos.
- Aproximação dos inimigos com rota persistente ao redor da mobília. O ponto
  final de ataque também é retirado de dentro dos obstáculos. A IA conserva
  preparação antes do ataque e limita a dois atacantes simultâneos.
- Agarrão de inimigo próximo no chão por **E** quando não há mobília
  interagível próxima. Os corpos são alinhados somente se ambos cabem no piso;
  o alvo fica vinculado durante a preparação e é lançado no quadro de soltura
  do movimento existente. Um corpo arremessado pode atingir outro inimigo.
- Encadeamento de quatro normais confirmados, finalizador com queda e
  cancelamento de normais confirmados em poderes existentes. A energia
  continua sendo obtida em combate, sem recarga passiva.
- Estados de vínculo, voo e rota incluídos no snapshot para solo/coop.
  Protocolo online v26 evita misturar simulações com a versão publicada v25b.

Os sprites, rostos, vozes e poderes aprovados não foram redesenhados. O
`FighterModel` e o sistema de poderes existentes continuam responsáveis por
suas respectivas regras. A fila de ondas continua a adaptação MIT anterior.
O mapa exato das rotinas externas está em `third_party/openbor/README.md`.

## Limites desta amostra

Não foi integrado o jogo completo Final Fight LNS Ultimate. Seu repositório
público contém o motor; o pacote do módulo foi inacessível no download oficial.
Não foi localizado código-fonte público do Streets of Rage 4.

Os inimigos ainda usam as animações existentes. A quantidade e a continuidade
de seus desenhos precisam de revisão artística própria para se aproximar da
referência. Personagens sem uma sequência específica de arremesso ainda
dependem da apresentação existente desse movimento. Carregar mesa/cadeira não
foi reintroduzido; mesas são destrutíveis e cadeiras são lançadas com chute.
Nenhuma destas limitações é resolvida apenas trocando a rotina de colisão.

## Verificação

- `bash tools/test.sh`: regressões de combate, cena completa, shell, controles,
  sprites/poderes existentes, replay solo e cooperativo.
- `tests/story_v26.gd`: reprodução da mesa, saída de sobreposição, deslocamento
  rápido, agarrão/soltura, corpo atingindo outro inimigo, replay JSON e rota
  autônoma da IA ao redor de mesa.
- `bash tools/export_web.sh`: pacote Web sem threads e licença OpenBOR.
- `SVF_CHROMIUM_BIN=/caminho/chrome node tools/smoke_story_v23.cjs`: percurso
  de teclado no jogo exportado. A variável é opcional para ambientes que já
  possuem Chromium instalado pelo Playwright.

O cenário foi criado com a ferramenta integrada de geração de imagens. O
prompt integral e o arquivo de origem estão em
`docs/story-v26-image-prompt.txt` e `assets/stages/v26/patio-illustrated.png`.
