# Revisão v10 — rolinho, ganchos e efeitos

> Atualização v11: o rolinho do João foi movido para **Q**, conforme o comando confirmado pelo autor. **H é Super Soco**; consulte [a revisão atual](PRESENTATION_V11.md).

A movimentação aprovada, retratos, roupas, menu e controles permanecem. Esta
revisão altera as ações de poder e corrige o encerramento dos rounds. O projeto
Canvas original não recebe alterações.

## Fim de round

O último golpe deixava `freeze_ticks` positivo: o ramo de round encerrado não
consumia esse contador. A apresentação reativava a vibração enquanto ele fosse
positivo. Agora o hitstop final termina antes da sequência de vitória, e a câmera
responde a novos impactos identificados, com decaimento finito. Projéteis e recuos
pendentes são encerrados no resultado. A reação aérea final ainda aterrissa; não
há novos contatos após o K.O. A validação inclui K.O., timeout e partida encerrada
por mais tempo que o intervalo de troca de round.

## João — H / Rolinho Elétrico

`RollMotion` controla preparação, avanço horizontal do próprio corpo, contato,
três pulsos elétricos, rebote e recuperação. Oito desenhos completos novos
representam carga, quatro orientações do giro, aterrissagem e retorno à guarda.
A escala é uniforme; o centro de rotação é registrado para evitar oscilação.

- O giro avança entre 1.000 e 1.200 px/s conforme a força, sem teleporte nem
  perseguição automática do adversário. Tem limite de tempo e respeita paredes.
- O corpo precisa chegar perto do tronco: uma mão estendida na guarda não
  interrompe o rolinho a mais de 180 px da raiz do defensor.
- No acerto, o deslocamento para. O mesmo alvo recebe três contatos espaçados em
  nove ticks livres, com choque visível entre os corpos. Cada pulso tem hitstop.
- Os pulsos repartem o dano original em 25% / 25% / 50%, antes da redução normal
  de combo. O terceiro lança e derruba. A contribuição de tontura é distribuída
  para evitar impor uma longa tontura automaticamente a cada uso.
- Defender interrompe no primeiro contato, sem sequência de choque. O rebote
  físico é mais longo que no acerto. Dano de defesa original continua aplicável.
- O erro também termina em rebote e recuperação. Um golpe recebido cancela o
  rolinho. Contra-ataque, invulnerabilidade e esquiva continuam possíveis.
- Direção, fase, relógio, alvo e contagem de pulsos entram no snapshot. A mesma
  ação funciona no História e no Versus; o História preserva a colisão por faixa.

`MoveData` mantém o custo e dano base. `PowerMoves.configure` cria a sobreposição
em memória; o catálogo JSON importado e suas vozes não são reescritos. H aparece
como Rolinho Elétrico na apresentação; U e Q continuam sendo ações independentes.

## Ganchos e efeitos dos 13 lutadores

Os ganchos recebem avanço de preparação e impulso horizontal por personagem.
As bandas de colisão do arco são conservadoras e ativas somente durante os
frames ofensivos. O desenho da mão continua contribuindo para contato próximo.
A escala especial do Adriano é aplicada uma vez à arte e às caixas.

A apresentação usa cels desenhados de arco ascendente, anel de giro e dissipação,
com cor e motivos próprios de cada personagem. Os projéteis existentes recebem
rastros, carga na mão e impacto. Código, pergaminhos, fumaça, garfos e livros
mantêm seus desenhos de origem; tinta, selos, circuitos, impulso, vento e
caligrafia têm composição própria. A elétrica de João acompanha o alvo durante
os pulsos. Os drones e seus lasers mantêm a lógica existente.

`PowerFXV10` e `PowerCelsV10` só apresentam dados; não modificam dano, estados ou
relógios de combate. `CombatImpact` aplica flash e vibração finitos no contato.
Pausar congela o tempo dos efeitos. Não há dependência de shader de desktop,
threads, downloads externos de assets ou física de renderização.

## Fontes e reprodução

`assets/source/powers-v10/PROMPTS.json` registra as duas gerações e as referências
de identidade do João. Os originais transparentes ficam preservados em WebP sem
perdas. Os empacotadores só extraem e registram desenhos; não pintam intermediários,
recortam rostos para montagem nem deformam personagens.

```bash
python3 tools/pack_roll_v10.py
python3 tools/pack_power_cels_v10.py
bash tools/test.sh
bash tools/export_web.sh
npm ci
npx playwright install chromium
npm run test:web
```

`tests/powers_v10.gd` verifica distâncias de 220, 500 e 900 px para o rolinho,
as três forças e ambos os lados; acerto, defesa, paredes, erro, interrupção,
snapshot/replay, História e fim de partida. Os 13 ganchos são testados a 260 px
e 700 px, com e sem defesa e com direções espelhadas.

`tests/render_powers_v10.gd` captura o renderer Compatibility real para revisão
visual: carga/disparo dos poderes, subida dos 13 ganchos, fases do rolinho e
vitória. Requer um display gráfico; `--headless` não serve como prova visual.

No workflow, `smoke_powers.cjs` usa somente teclado e o observador Web de leitura:
seleciona João × Rafael, executa H, confere combo elétrico, defesa/rebote e vence
um round de verdade para verificar o fim do hitstop e da vibração. Os demais
smokes continuam cobrindo menu, USB simulado, fullscreen, todos os temas de
poder, pontuação e História. O deploy para Pages depende desses testes passarem.

A revisão não implementa sessão online/rollback de rede nem redesenha o restante
do elenco. A confirmação de replay local não significa netcode online pronto.
