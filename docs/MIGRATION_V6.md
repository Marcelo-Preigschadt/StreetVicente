# Revisão 6 — recuperação, pontos e paridade local

Origem comparada em leitura: `Street-Vicente-Fighter-`, `b320e497682bbfe0e2fc39883818183fa02521f5` (head conferido novamente em 16/10/2026). Alterações somente em **StreetVicente**. Não se declara migração integral encerrada.

## Problemas corrigidos

A tontura anterior acumulava sem decair, disparava por golpes isolados e mantinha a pendência quando interrompida por outro golpe. Agora exige combo real de pelo menos três acertos e gauge 65, com a exceção química já presente nos dados do original. Decai 20/s após um segundo sem golpe, dura 2,35s, permite acelerar a saída com novos comandos e concede quatro segundos de proteção após terminar ou ser interrompida. Hitstop e hitstun continuam existindo para o impacto e os combos; não bloqueiam indefinidamente o controle.

O combo só continua enquanto o alvo ainda está em hitstun do mesmo atacante. O dano segue a escala de −8% por acerto, com piso 55%. Sequências de estilo são reconhecidas pelos IDs reais de golpes do catálogo. Reação usa progresso do hitstun, região e postura: quatro exposições no atlas reaction de Rafael/Gustavo, fases disponíveis de Marcelo e fallback da arte existente nos demais. Ainda não há desenhos novos de reação para todo o elenco.

Adriano herdava o fator 0,88 da origem e ficava com cerca de 264px. `CharacterMetrics` aplica a razão uniforme 25/22 em seleção, combate, rastros, hurtboxes/hitboxes, pushbox e emissão/raio dos poderes, recuperando a referência de 300px. Preserva largura relativa, ponto dos pés e espelhamento. Agachar e golpear continuam mudando naturalmente a silhueta; não são redimensionados quadro a quadro para uma altura fixa.

## O que faltava e foi migrado

| Sistema | Implementação Godot |
|---|---|
| Circuito CPU | `ArcadeRun`: 12 rivais, primeiro escolhido na seleção, dois rounds por confronto, rota escolar de 5,6s, avanço automático ou Enter/Start/clique |
| Pontuação | Dano ×10; hit adicional `(combo−1)×50`; estilo +500; round +1000; vida ×5; segundos restantes arredondados para cima ×50; Perfect +5000; Super KO +2000; confronto +3000; circuito +20000 |
| Regras do placar | Só P1 contra CPU pontua; empate não ganha bônus; eventos e rounds duplicados não repetem pontos; Continue mantém rival/posição/recorde e zera pontos |
| Recorde | `svf-arcade-record-v1` no navegador, compatível com o original quando no mesmo origin. Fallback em `user://`; bloqueio de storage não interrompe a partida |
| Controles avançados | C: Custom (50 de barra, 2,5s, até oito movimentos); X: contra-ataque durante blockstun (25 de barra); duplo toque: avanço/recuo com perfis próprios e sem invencibilidade |
| Levantamento | Comando nos primeiros oito frames após cair permite quick rise; wakeup e proteção continuam determinísticos |
| História / progressão | Pontos por inimigo 100 ou chefe 1000; quatro atos e segunda fase Exo; turno global de 900s; R repete o ato com seu tempo de entrada |
| História / objetos | Mesas/cadeiras carregáveis e arremessadas na fase ativa; colisão varrida; máquina libera latas explosivas; estante cai com aviso; kit recupera 220 de vida |
| História / perigos | Ácido, gelo e cabos, com período, aviso, janela ativa, alcance de lane, altura e cooldown por alvo. Afetam ambas as equipes |
| História / inimigos | Dimensões de colisão por perfil, voo, telegráficos, disparos, carga, agarrão, ataque baixo, lança-chamas e teleporte por tipo de chefe |
| História / UI | Diálogos de entrada com os textos originais e objetivo; checkpoint automático por onda/ato e ao pausar; menu Retomar/Nova campanha |
| Save e replay | Snapshots incluem reação, recuperação, Custom, passos, objetos, perigos e tiros. JSON normaliza inteiros e hash usa chaves ordenadas; ordem dos campos após reload não causa falso desync |
| Controle USB | D-pad/A/B navegam telas; Start pausa/continua e avança a rota. Combate mantém o InputMap anterior; sticks pressionados ativam Custom/Counter |

O placar do circuito é estado local de progressão, separado da simulação de luta e de futuros snapshots online. A barra atravessa rounds do mesmo confronto, mas volta a zero contra o próximo rival. Checkpoint Godot usa `svf-godot-story-v1`; não tenta interpretar snapshots JavaScript incompatíveis como estado Godot.

## Validação

`bash tools/test.sh`: **4.810 verificações, zero falhas**. Inclui os limites de recuperação, tontura interrompida, mash/restauração, quick rise, quatro quadros de reação, escala/espelhamento do Adriano, fórmulas e deduplicação de pontos, todos os 12 rivais, Continue e finalização, reconhecimento de estilo, objetos arremessados, perigo/cooldown, progressão dos quatro atos/Exo, persistência JSON e continuidade por 75 ticks após restore, Custom/Counter e footwork para os 13 personagens.

`tools/smoke_web.cjs` exercita o WASM real sob `/StreetVicente/` via teclado: reação e recuperação, Adriano na seleção e arena, Custom, pontos obtidos contra a CPU, reload do recorde e retomada da posição do História. O pipeline exporta com Godot 4.5.1, Compatibility/WebGL2, sem threads e sem necessidade de cabeçalhos COOP/COEP; só publica depois que esse smoke passa. Capturas e vídeo ficam no artefato `StreetVicente-Web-QA` da execução.

## Paridade ainda aberta

- **Online / rollback em rede e História coop:** não implementados. Replay local é testado; sessão, transporte, sinalização/TURN, confirmação, reconexão e comparação entre dois navegadores continuam necessários. Pages hospeda o cliente estático.
- **História:** o single player está expandido, mas a coreografia completa dos chefes, troca de duelista/cooperativo, entradas cinematográficas, todos os diálogos intermediários e ordenação fina de profundidade entre herói/móveis ainda diferem da origem. A IA usa FSM e ticks; não é uma conversão integral do módulo brawler original.
- **Arte e animação:** novos desenhos cobrem Marcelo e socos de Rafael/Gustavo. Restante do elenco/ações e poses específicas de carregar móveis ainda usa a arte existente. IK/contatos contínuos do Canvas não foram integralmente recriados no Godot.
- **Detalhes de combate/UI:** modificadores de counter-hit/dano aéreo, todas as nuances de lançamento/throw tech e a sequência completa do locutor ainda exigem comparação específica com a origem. Mapeamento USB personalizado, hardware USB físico e touchscreen não foram validados nesta entrega.

Esses itens permanecem explícitos para evitar tratar uma base local melhorada como paridade total do jogo original.
