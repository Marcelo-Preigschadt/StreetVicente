# Online v22 — Godot

O menu **ONLINE / VERSUS E COOP** abre as salas do Godot. Há **Versus 1 × 1** e **História cooperativa**, para duas pessoas em navegadores ou computadores diferentes. Escolha o modo antes de criar ou entrar na sala.

## Jogar

1. Use **Criar sala** e compartilhe o código de oito caracteres. A outra pessoa escolhe o mesmo modo e usa **Entrar com código**. Também há **Buscar partida** e lista de salas, atualizada a cada cinco segundos.
2. Cada pessoa escolhe e confirma apenas seu próprio personagem. Os 13 estão disponíveis; dois jogadores não podem usar o mesmo personagem. Enter confirma ou desfaz a confirmação. O anfitrião pode escolher a arena com F5 antes da partida.
3. Cada computador usa os comandos de **P1**, inclusive o controle USB configurado para P1. No Versus, cada pessoa controla seu lado. No cooperativo, os dois controlam seus heróis no mesmo ato.
4. Esc pausa os dois jogadores; Enter retoma. Outro Esc, com a partida pausada, sai da sala. Ao terminar, os dois usam Enter para voltar juntos à seleção.

O cooperativo compartilha inimigos, ondas, chefes, objetos, perigos e pontuação. Poderes e drones não acertam o parceiro. A câmera acompanha a dupla e limita sua separação; o portão exige os dois jogadores vivos. **E**, perto de um parceiro caído, o levanta com 300 de vida. A derrota acontece quando os dois caem. O progresso cooperativo pertence à sessão online e não substitui o save individual do História.

## Recuperação

Quando falta comunicação, a previsão tem limite: a partida espera pela rede. Ao reconectar, os dois retomam o mesmo estado confirmado. Atualizar a página também preserva um bilhete privado naquela aba: entre no Online e use **Retomar minha sala** enquanto a sala estiver válida. A troca de anfitrião não é suportada; o anfitrião precisa voltar. Salas sem heartbeat expiram em três minutos.

O bilhete usa `sessionStorage`: não é compartilhado entre abas e não vai para o endereço ou observador de QA. Contém a credencial de manutenção da sala, portanto é apagado ao sair explicitamente. Recarregar o anfitrião cria uma nova identificação de partida para rejeitar mensagens antigas.

## Implementação

O Canvas original usa Supabase Broadcast por WebSocket TLS e o diretório `public.svf_rooms`. O Godot reutiliza esse serviço e as políticas de propriedade, mas usa protocolo e canal separados (`svf-godot-v22`). Salas Canvas e Godot não aparecem juntas e não podem iniciar partidas incompatíveis.

- `RoomDirectory`: lista pública, código legível e manutenção por token aleatório de 256 bits. Apenas SHA-256 do token é salvo no banco. O cliente contém somente a chave pública do projeto; nunca uma chave administrativa.
- `RealtimeRelay`: conexão Phoenix v1 com heartbeat, limite de buffers e reconexão progressiva.
- `OnlineSession`: duas vagas, seleção confirmada, carregamento dos dois lados, pausa, checkpoint, nova seleção e recuperação.
- `RollbackSession`: simulação determinística a 120 Hz; atraso de entrada de seis ticks, até 24 ticks de previsão remota e histórico de 360 ticks. Repete comandos recentes e ainda não confirmados, corrige entradas tardias e compara hashes de checkpoints. Áudio e impactos só consomem eventos confirmados.
- `CoopStorySimulation`: mantém dois heróis, objetos próprios, inimigos compartilhados e estado serializável. Objetos ambientais e perigos avançam uma vez por tick.

O anfitrião decide seleção e checkpoints. Este é um modo casual entre duas pessoas, sem ranking ou servidor autoritativo de combate. A chave de protocolo deve mudar quando as regras ou o formato do estado mudarem. Há um único projeto Supabase compartilhado com o original; tráfego e disponibilidade dependem desse serviço.

A migração SQL amplia somente o CHECK de personagens de oito para 13; mantém grants, expiração e RLS originais. Não cria tabelas ou desativa políticas.

## Verificação

`bash tools/test.sh` inclui dois peers simulados comparados a uma execução offline, com atraso, perda e reordenação de pacotes, replay, snapshots JSON, eventos sem repetição, espera limitada, comandos durante espera, comandos inválidos, drones aliados e ajuda ao parceiro.

`node tools/smoke_online.cjs` executa dois clientes WASM independentes pelo serviço real. A automação usa a interface e comandos normais; `window.svfQA` é somente leitura. Ela verifica Versus, cooperativo, hashes confirmados, pausa, interrupção de rede, retomada dos dois assentos após reload e saída da sala. Capturas e relatório ficam em `test-results/`. `SVF_ONLINE_URL` permite repetir o teste na publicação.
