# Revisão v9 — guarda, João e controles

A caminhada anterior do Adriano foi desenhada com corpo mais estreito e postura
alta. Normalizar a altura não corrigia anatomia. Esta revisão substitui seus oito
cels por deslocamento em guarda baseado no corpo completo parado: braços altos,
joelhos flexionados, ombros largos e passos curtos. O atlas v8 anterior permanece
arquivado; o v9 sobrepõe somente a caminhada no runtime.

João é o próximo personagem revisado: 16 estados, 8 caminhada, 8 soco, 16 chute /
gancho / cast e 16 ações baixas e aéreas. São 64 desenhos completos; cada ação
aérea tem quatro desenhos, expostos com pausas explícitas para startup, contato e
retração. Não há interpolação de partes, montagem de rosto ou modelo 3D. Rosto,
óculos, boné, cabelo e roupa usam as referências já existentes. Retratos e vozes
não foram alterados; nomes e efeitos dos poderes permanecem os mesmos.

`assets/source/arcade-v9/PROMPTS.json` registra os pedidos ao image_gen. Fontes
transparentes são preservadas em WebP sem perdas. `tools/pack_arcade_v9.py` apenas
extrai, registra e empacota cels; não deforma corpos nem desenha intermediários.
A escala é única por folha. Hurtboxes vêm da silhueta e hitboxes / ponto da mão
são registrados para o quadro ativo. João agora usa o mesmo caminho de gancho
físico do trio anterior, com poses de subida e queda até aterrissar.

## Controles e apresentação

- Teclado restaurado a partir de `legacy-source/src/input.js`: seis botões de
  golpe, força própria por tecla, R defesa, H poder, U gancho, Q super, Z drone.
- A força é guardada junto ao comando no buffer e no snapshot, para que soltar a
  tecla durante hitstop/recovery não transforme um golpe forte em médio.
- F8 reinicia; F10 abre configurações; F11 alterna tela cheia. Botões clicáveis
  permanecem no rodapé sem reorganizar o menu aprovado.
- Painel USB: dois jogadores/dispositivos, todos os comandos configuráveis com
  botões ou eixos, troca automática de conflitos, zona morta 15–65%, diagnóstico
  ao vivo, restauração e cancelamento de captura. Mapas salvos por GUID/nome.
- USB genérico pode remapear direções; o direcional padrão acompanha analógico
  apenas quando a direção mantém seu padrão. Menu aceita analógico e direcional.
- Desconexão neutraliza entradas e pausa a luta. Configurar durante pausa mantém
  a pausa ao fechar. Entradas capturadas no painel não atacam no jogo.
- Na Web, preferências usam localStorage com tratamento de erro; desktop usa
  `user://controllers-v1.json`. Não se depende de sincronização tardia do FS Web.
- `web/shell.html` é a abertura própria do jogo, com progresso, erros e tentar
  novamente. A imagem de boot padrão está desativada. O download segue necessário.
  Export usa o shell oficial de Godot com placeholders substituídos no build,
  sem threads nem dependência de COOP/COEP, e caminhos relativos para Pages.

## Verificação

`bash tools/test.sh` executa combate/replay, fluxos e regressões de teclado/USB.
`tests/arcade_v9.gd` percorre fases do João e confere buffer de força e escala da
caminhada. `tests/input_settings_v9.gd` usa eventos sintéticos para conferir seis
teclas, slots distintos, conflitos, salvamento, reload e pausa.

`tests/render_arcade_v9.gd` captura o renderer Compatibility real: menu, painel,
64 exposições de guarda → andar → guarda de Adriano/João e oito ações do João.
Essas imagens servem para inspeção visual, não apenas para verificar IDs de pose.

O workflow executa o pacote WASM em Chromium, confere abertura personalizada,
botão fullscreen, teclas originais e os fluxos de jogo. `smoke_controller.cjs`
injeta dois dispositivos na Gamepad API para exercitar o caminho Web real:
confirmação, analógico, captura/remapeamento, Start, reload e desconexão. Isso
não equivale a testar um controle USB físico; esse teste precisa do dispositivo
do jogador, especialmente para controles DirectInput sem layout reconhecido.

Os outros personagens permanecem na fila de revisão individual. A infraestrutura
de controle não altera a disponibilidade do online/coop, ainda em migração.
