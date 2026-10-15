# Arquitetura do núcleo

`LocalCombatInput` transforma eventos/polling em `CombatInput(held, pressed)`. `FightSimulation.step` recebe dois slots, registra buffers, resolve hitstop, atualiza ambos a partir das posições anteriores, resolve pushboxes, coleta contatos, aplica impactos, resolve paredes e avança contadores. Coletar antes de aplicar permite trades sem prioridade implícita de P1.

`FighterModel` não é Node, não chama Input, não lê relógio e não usa `move_and_slide`. Colisões não dependem de Area2D/PhysicsServer: AABBs são inteiros com origem nos pés e ordem fixa. Isso permite ressimulação síncrona sem depender do passo do servidor de física.

Posições e velocidades têm escala 256; velocidade é deslocamento por tick. O protótipo usa gravidade de 64 unidades/tick² = 3600 px/s²; o elenco importado usa 77 unidades/tick², aproximação fixa de 4320 px/s². Velocidades são convertidas por personagem; 3 px/tick = 360 px/s. O núcleo não usa delta variável.

O controlador avança em `_physics_process` a 120 Hz. Até 16 passos de catch-up por render são permitidos; isso não garante desempenho em hardware lento. Perda de foco pausa o modo local e limpa inputs.

## Contratos

| Componente | Responsabilidade | Snapshot |
|---|---|---|
| CharacterData/MoveData/HitboxData | Dados imutáveis | IDs; configuração deve coincidir entre peers |
| CombatInput/CommandBuffer | Held, edges e comandos consumíveis | Sim |
| FighterModel | Root, velocidade, facing, FSM, HP, stun, move e alvos atingidos | Sim |
| FightSimulation | Tick, timer, hitstop e resultado | Sim |
| PowerSystem | Projéteis, formação/carregamento de drones, lasers, IDs e TTL; compartilhado com StorySimulation | Sim |
| StorySimulation | Herói, inimigos/cooldowns, objetos, ondas e projéteis; restore offline | Sim |
| ReplayTimeline | Inputs e snapshots, 240 ticks | Externo ao estado do mundo |
| SpriteFighterView/GameScreen/CombatImpact | Interpolação, desenho por chave, partículas | Não |
| AppSettings | InputMap e dispositivo | Não |

Snapshots copiam coleções mutáveis; restore não retém referências e limpa eventos. O hash usa serialização binária com ordem fixa de campos. O futuro handshake precisa incluir build e hash dos Resources; não comparar builds diferentes. ReplayTimeline testa correção local, sem prever ou confirmar frames remotos; não é usado como sessão online.

## Extensão

Estados estão em `FighterState.Id`; transições ficam em FighterModel. PreJump, Landing, Knockdown, Wakeup e Dizzy já têm estados explícitos. Agarrão é um move com nível throw; o super usa hitstop global e custo. Novas transições precisam serializar seus contadores e testar saída, interrupção e reentrada. Animações não disparam transições autoritativas.

Moves têm janelas `[início,fim)` em frames absolutos. Multihit exige `hit_id` por janela/grupo e alvos por hit_id; a base limita um acerto por alvo/golpe. Cancels devem declarar janela, condições on-hit/on-block/whiff, custo e destino. Throws exigem prioridade e resolução próprias.

Hitstop congela combate e timer, mantendo amostragem de input; buffer expira pelo tick global. Stun mede ticks fora do hitstop. Defesa depende de direção para trás ou guarda e nível do golpe. Orientação fica travada durante ataque/hitstun. Salto pode cruzar por cima quando as pushboxes deixam de se sobrepor verticalmente.

## Apresentação

Views interpolam posições anterior/atual com `Engine.get_physics_interpolation_fraction()`. Não adicionar interpolação automática aos mesmos nós. Após reset/correção, chamar `sync(true)` e reconstruir apresentação. O manequim de referência conserva IK de dois segmentos. A apresentação do elenco usa atlas; Marcelo usa PilotArt com 64 novos desenhos e exposição das chaves conforme fase/tick. Caminhada avança pela distância efetiva após paredes/pushboxes. IK visual não decide hurtboxes.

Eventos são `{id,tick,kind,slot,x,y}`. O modo local os consome uma vez por passo. Rollback futuro deve confirmar e deduplicar áudio/partículas/câmera por ID para não reapresentar efeitos a cada replay.
