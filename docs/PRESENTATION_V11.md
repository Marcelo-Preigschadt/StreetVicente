# Revisão v11 · Gustavo, arenas e contato

O repositório Canvas permanece intacto. Esta revisão altera somente StreetVicente.

## João: comandos confirmados

| Tecla P1 | Golpe | Comportamento |
|---|---|---|
| H | Super Soco | Soco normal de poder; energia segue o punho desenhado, sem enrolar o corpo |
| U | Curto-Circuito 301 | Subida elétrica; mantém o avanço/alcance de gancho |
| Q | Rolamento Selvagem | Especial da barra: preparação, viagem física, três contatos elétricos, rebote e recuperação; defesa interrompe o combo e provoca recuo maior |

As falas de U/Q acompanham os nomes remapeados. O catálogo importado permanece imutável; os ajustes ficam em PowerMoves. Q mantém o custo de barra do especial: no treino, F8 restaura a situação inicial/barra. A base física do rolinho e seus snapshots continuam compartilhados com o História.

## Gustavo, por inteiro

64 desenhos completos novos: 16 estados, 8 passos em guarda, 8 socos, 16 quadros de chute/gancho/poder e 16 de golpes baixos/aéreos. Mantidos rosto aprovado, cabelo preso, jaleco branco, camiseta oliva, jeans e tênis marrons. Não há rosto recortado em polígonos, modelo 3D ou esticamento vertical entre poses.

Os originais lossless estão em `assets/source/arcade-v11/gustavo_*.webp`; a referência está em `references/gustavo-master.png`. Os prompts exatos e a origem de cada imagem estão em [provenance.json](../assets/source/arcade-v11/provenance.json). O empacotamento reproduzível usa `python3 tools/pack_arcade_v11.py` (Pillow, numpy, scipy). O jogo carrega `assets/characters/gustavo/arcade-v11/*.webp` e `data/characters/gustavo-arcade-v11.json`.

Cada folha usa escala uniforme; raízes e linhas de chão são registradas por quadro. Hurtboxes são calculadas offline a partir da silhueta e o contato ofensivo acompanha punho/bota. O chute mantém o quadro de extensão durante o active. O gancho usa preparação no chão, subida aérea e aterrissagem. As poses do salto não são pés plantados deslizando pelo ar.

Gustavo se junta a Marcelo, Rafael, Adriano e João na revisão completa. Os outros oito personagens ainda precisam desse mesmo trabalho; os efeitos compartilhados já se aplicam aos 13.

## Arenas e efeitos

Pátio ao pôr do sol, NIT, Cobertura noturna e Servidor central. As três novas artes originais estão em `assets/stages/v11/`, preservadas em WebP lossless. F5 ou o botão da arena abre a seleção; confirmar dentro da luta mantém simulação, vida e round. No circuito, os próximos rivais variam o cenário. O História conserva os fundos próprios de cada ato e usa o ambiente associado à etapa.

O cenário cobre a janela, incluindo proporções largas/altas. Folhas, poeira, estrelas e luzes usam apenas relógio visual e não entram em snapshots. Impactos têm quatro exposições por categoria: leve, pesado/chute, defesa azul e poder. Fonte lossless: `assets/effects/arcade-v11/impacts.webp`; registro: `data/characters/impact-cels-v11.json`. Energia e cortes radiais do especial aparecem atrás dos lutadores. Flash e tremor continuam finitos, sem deslocar caixas.

Pássaros animados e estrelas orbitam acima da hurtbox da cabeça somente durante DIZZY com duração positiva. A órbita segue state_tick: pausa/hitstop a congelam; recuperação e K.O. a removem. Golpe comum não cria uma falsa tontura.

## Áudio sem serviço pago

Não são publicadas músicas geradas nem trilhas extraídas de Street Fighter. A [orientação oficial da Capcom](https://www.capcom.co.jp/support/faq/others_website_037521.html) não concede redistribuição de suas músicas em outro jogo. Comprar ou encontrar um download não equivale à autorização de incluí-lo no pacote público.

F6 na seleção de arena aceita um MP3/OGG local (até 12 MB). A faixa é associada à arena em memória, com loop e transição; Del remove. Nada é enviado a servidor, salvo no repositório ou persistido ao recarregar. F9 silencia música/ambiente; −/+ ajusta o volume. Só essas preferências são salvas. Os quatro ambientes discretos e os quatro sons de impacto foram sintetizados localmente, sem banco de músicas ou serviço pago; reprodução: `python3 tools/create_stage_sounds_v11.py` (numpy, scipy, ffmpeg). As vozes e os efeitos existentes continuam independentes.

## Validação

`bash tools/test.sh` verifica combate/replay, comandos, poses, colisões, fim de round, status real, seleção/retomada de arena e áudio local nativo. O fixture `tests/render_presentation_v11.gd` captura o renderer Compatibility real, incluindo caminhada e ataques. No Web, `tools/smoke_presentation.cjs` usa teclado, FileReader e reprodução OGG reais, testa as quatro arenas, volume/mute, remoção da faixa, Gustavo e impactos. `smoke_powers.cjs` verifica H separado de Q, combo, bloqueio/rebote e um K.O. real. Os testes existentes mantêm controles USB simulados, placar/História, tela cheia e cobertura em diferentes proporções. Controle USB físico e audição subjetiva em outros navegadores continuam dependendo do dispositivo do jogador.

`tools/test.sh` e `npm run test:web` fazem parte do gate: Pages só recebe a exportação quando todos passam. O projeto continua Godot 4.5.1, Compatibility, Web sem threads. Não há nova promessa de online/rollback em rede.
