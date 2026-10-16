# Revisão 2D · arcade v8

Direção atual: animação 2D quadro a quadro com cels completos, inspirada na leitura
de poses e no impacto dos jogos de luta arcade. O protótipo 3D permanece arquivado.
Esta revisão não representa acabamento equivalente ao de Marvel vs. Capcom 2 em
todo o elenco.

| Personagem | Desenhos novos nesta revisão | Integração |
|---|---:|---|
| Adriano | 64 | 16 estados/reação; 8 caminhada; 8 soco; 16 chute/ascendente/poder; 16 ações baixas/aéreas |
| Rafael | 64 | 16 estados/reação; 8 caminhada; 16 chute/ascendente/poder; 8 golpes baixos; 16 ações aéreas; soco v5 preservado |
| Marcelo | 8 | Soco aéreo dedicado, com pernas recolhidas; demais 64 desenhos anteriores preservados |
| Contato e poderes | 16 | 4 impacto, 4 defesa, 4 onda digital, 4 pergaminho histórico |

São 136 desenhos novos de personagens e 16 exposições de efeitos. Os quatro cels
de cada ação aérea do Adriano usam holds explícitos na exposição de oito índices.
Não são oito desenhos únicos por ação. Os rostos de seleção não foram alterados;
as referências de identidade foram usadas para desenhar os corpos inteiros, sem
colar recortes de retrato sobre os personagens.

## Registro e combate

- Altura neutra final de Rafael e Adriano: 300 px. A conversão herdada de 25/22 do
  Adriano é aplicada uma vez à arte e à geometria, evitando dupla ampliação.
- Pivôs, chão e escala são registrados por atlas; nenhuma pose é esticada ou
  deformada em tempo de execução. Atlases usam prateleiras compactas para reduzir
  memória transparente no WebGL.
- Hurtboxes são bandas de silhueta pré-calculadas. Punhos, botas e sockets de
  emissão são registrados offline. A simulação lê retângulos inteiros, a 120 Hz.
- Soco aéreo pode encadear em chute aéreo após contato confirmado. Não há cancel
  de normal aéreo no vazio, repetição livre de soco/chute, ou cancel chute → soco.
- Hitstop preserva os inputs; pausa do jogador preserva o relógio dos efeitos e
  rastros. Impactos leves, pesados e defesa têm exposições diferentes.
- Onda digital não imprime texto na tela; drones existentes foram preservados.
  Rafael/Adriano ainda compartilham o VFX histórico de pergaminho. O selo imperial
  exclusivo do Adriano continua como refinamento pendente, sem alterar seu kit.

## Tela e rounds

O cenário cobre o viewport expandido, mantendo y625 como chão da luta e sem
esticar os lutadores. A revisão visual inclui 1280×720, 1720×720 e 1024×768.
HUD e limites físicos continuam no espaço lógico de 1280×720.

Abertura: ROUND + número, depois FIGHT, com as gravações já existentes. São 192
ticks de abertura; movimento, ataques e cronômetro aguardam o término. Os botões
pressionados nessa fase não vazam para o início da luta. R no treino reinicia sem
repetir a abertura; entrada pelo menu e rounds seguintes a apresentam normalmente.

Encerramento: K.O./TIME OVER, vitória/empate e PERFECT quando aplicável. A voz de
K.O. usa o efeito já existente; não foi criada uma nova gravação para TIME OVER.
O contador da abertura participa de snapshot/replay. A barra super entre rounds,
pontuação, Continue e checkpoint do História foram preservados.

## Fontes e reprodução

Ferramenta de arte: **image_gen.imagegen integrada**, com referências locais.
Prompts completos e fontes selecionadas: [PROMPTS.json](../assets/source/arcade-v8/PROMPTS.json).
Originais selecionados: `assets/source/arcade-v8/*.webp` (compressão sem perdas).
Arte publicada: `assets/characters/{adriano,rafael,marcelo}/arcade-v8/` e
`assets/effects/arcade-v8/`. Fontes, testes e previews ficam fora do pacote Web.

```bash
python3 tools/pack_arcade_v8.py
python3 tools/pack_arcade_effects_v8.py
bash tools/test.sh
bash tools/export_web.sh
```

O empacotamento usa Pillow/numpy/scipy somente offline para extração/registro,
sem pintar partes, gerar poses, interpolar membros ou substituir rostos.
`tests/arcade_v8.gd` verifica o combo aéreo real, recusa de whiff, replay, abertura,
escala e correspondência dos atlases. `tests/render_arcade_v8.gd` captura o jogo
com renderer Compatibility/OpenGL, não o renderer vazio de `--headless`.
O QA Web usa teclado/mouse no WASM real, incluindo abertura, Adriano e janelas
expandidas. O GitHub Actions bloqueia o deploy se os testes falharem.

## Continuidade da migração

João, Tais, Luciana, Khauãny, Dienes e o restante do elenco ainda precisam da mesma
revisão completa de cels, transições e poderes próprios. Agarrões e assinaturas
visuais dos supers também requerem sequências específicas. O online segue
indisponível: snapshot/replay local não equivale a rollback online pronto.
