# Migração incremental

Origem consultada em modo de leitura: `Marcelo-Preigschadt/Street-Vicente-Fighter-`, head observado `b320e497682bbfe0e2fc39883818183fa02521f5`. Esta entrega grava apenas em StreetVicente.

Foram inspecionados diretamente `src/locomotion.js` e `src/netplay.js`. O original mantém física a 120 Hz e frame data a 60 Hz. RollbackGame salva snapshots e inputs, prevê held remoto anterior sem repetir ataques, corrige a partir do primeiro input divergente e limita o histórico a 180 ticks. A nova base não converte esses módulos automaticamente.

## Etapas e critérios

| Etapa | Implementação | Critério de aceite |
|---|---|---|
| 1 — esta base | Núcleo inteiro, FSM, frame data, buffer, AABB, snapshots, Web | Testes headless e build Web executável |
| 2 — personagem piloto | Marcelo completo: atlas, retrato, voz PT-BR, kung fu e poderes | Rosto/identidade preservados; origem nos pés e alcance verificados |
| 3 — combate completo | Prejump/landing, cancels, combos, dizzy, knockdown/wakeup, throws, supers e projéteis | Replays com equivalência de frame data e resultados |
| 4 — rig e elenco | Contatos dos pés, IK e gait por estilo; hurtboxes por pose | Sem deslizar, perder membros/rostos ou variar escala; revisão individual |
| 5 — história offline | Mundo 2.5D, ondas, objetos, bosses e progressão | Uma fase completa, retry/seleção/retorno e câmera |
| 6 — online 1×1 | Transporte, sessão, previsão, rollback limitado e hashes | Dois navegadores, atraso/jitter/perda e reconexão verificados |
| 7 — história online | Autoridade, snapshots de entidades e orçamento de replay | Versus estável primeiro; depois dimensionar coop |

## Locomoção articulada

O original atualiza contatos após paredes/corpos e deriva fase da distância realmente percorrida. Preservar: input → root autoritativo → contatos do mundo → gait → pose. Apenas desenhar com Skeleton2D não preserva esse comportamento.

1. Extrair bind pose, comprimentos, stride, duty factor, lift, aceleração/desaceleração e variações para frente/trás. Converter unidades explicitamente.
2. Montar Node2D/Skeleton2D/Bone2D com origem nos pés e escala artística independente da colisão. Preservar rosto/cabeça dos atlases reais.
3. Fixar o pé de apoio em coordenadas do mundo, interpolar swing entre contatos, acompanhar pelvis/root e resolver joelho/tornozelo com IK de dois ossos e bend coerente.
4. Fazer blend da pose inteira — tronco, quadril, braços e pernas — no início/fim da caminhada e golpes. Não esticar a arte para compensar stride incorreto.
5. Pose/contatos que afetem alcance ou hurtbox precisam ser inteiros/tabelados e restauráveis. Cosméticos podem usar floats e reconstrução após correção. Não derivar colisão autoritativa de IK visual.
6. Comparar parede, reversão, aterrissagem, carry, hitstun e golpes quadro a quadro. Resetar contatos após teleporte/correção.

## Personagens, moves e assets

Converter dados declarativos para Resources mantendo IDs, frame data, nível, caixas, custo e propriedades. Não traduzir todo o JavaScript linha a linha: separar dados de lógica e provar equivalência com testes. Converter origem das hurtboxes do atlas para os pés e preservar escala.

SpriteFrames/AnimationPlayer e AnimationTree são apresentação. O frame de gameplay vem do tick. Preservar rostos, roupas e vozes PT-BR aprovadas; não substituir elenco por lutadores de outra franquia. Áudio nunca controla duração de combate/seleção.

Projéteis, drones e lasers simulados ficam separados de shaders/partículas. Cada entidade precisa de ID, owner, root/velocidade, idade/TTL, janela ativa, alvos e estado necessário ao save/load. Câmera/áudio são eventos deduplicáveis.

## História 2.5D

Separar X, profundidade/lane e altura Z. Projetar `(x, lane - z)` e ordenar desenho pela lane; salto não muda a faixa de profundidade. Acerto depende de alcance lateral, tolerância de lane e altura: o AABB lateral do Versus é insuficiente.

Criar StoryWorld, StoryEntity, WaveDirector e StageDefinition. Fases contêm limites/câmera, spawns, gatilhos, ondas e progressão. Objetos quebráveis/carregáveis e bosses têm estados próprios. Ordem de spawn, RNG com seed e progresso entram no snapshot antes do coop. Saves em user:// precisam de teste de persistência no Web/reload.

## Rollback Web realista

Godot não fornece determinismo nem rollback de luta ao ativar multiplayer. CharacterBody2D/RigidBody2D, timers de Node, clocks e RNG global não devem ser autoridade reexecutável. Esta base usa inteiros/AABB; ainda exige comparar WASM/nativo, navegadores e arquiteturas.

Transporte proposto: **WebRTC DataChannel**, sinalização HTTPS/WSS externa para offer/answer/ICE, STUN e fallback TURN autenticado com credenciais temporárias. Navegador não oferece ENet/UDP cru. **GitHub Pages só hospeda estáticos**, não sinalização/TURN. No desktop, WebRTC exige extensão nativa; no Web, a API já existe.

Canal de inputs unordered com retransmissão limitada, redundância de inputs recentes, frame e acknowledgments; canal confiável separado para handshake/controle. Validar tamanho, slot, tick futuro/passado e build/hash de dados. WebSocket pode servir como relay, com head-of-line blocking e latência a medir.

Ponto inicial experimental: input delay de 2–4 frames de design (4–8 ticks) e janela de rollback de 6–8 frames (12–16 ticks). **Medir**, sem prometer que esses valores servem à rede real. Histórico de diagnóstico pode ser maior; não ress imular 180 ticks no caminho crítico Web. A 120 Hz há 8,33 ms nominais por tick, mas replay disputa o orçamento com renderização: medir p95/p99 no hardware alvo.

Por tick: capturar input local futuro, prever held remoto anterior com pressed=0, salvar estado anterior, simular e guardar hash. Input real divergente restaura o estado mais antigo afetado e ress imula ambos em ordem fixa. Efeitos confirmados ou previstos precisam IDs e deduplicação; não repetir áudio a cada replay.

Adicionar checksums de ticks confirmados, dump no primeiro desync e política de resync/desconexão. Não aceitar snapshot remoto arbitrário sem validar sessão/versão/conteúdo. Aba suspensa ou dívida acima do limite exige pausa coordenada e handshake de retomada; não simular minutos de catch-up nem manter um peer jogando sozinho.

ReplayTimeline prova somente correção local. Lobby, transporte, previsão, confirmação, reconexão e consenso de sessão não estão implementados nesta etapa. Expor online apenas após esses critérios passarem.
