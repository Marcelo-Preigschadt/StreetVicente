# Marcelo: piloto 2,5D

Escolha **PILOTO 2,5D / MARCELO** na primeira opção do menu. F6 alterna modelo 3D/desenhos 2D; F3 executa a demonstração; F1 mostra as caixas autoritativas. Movimento A/D, salto W/Espaço, soco F, chute G, baixa S, defesa H, código T, Firewall Y, super U e sentinela Q.

## Implementado

- Corpo em `ArrayMesh`, com perfis de tronco, membros, mãos, botas, lapelas e abas do sobretudo. Os membros não são recortes de uma imagem.
- `Skeleton3D` de 18 ossos, com hierarquia, bind poses inversas e skinning de quatro influências disponíveis por vértice. O piloto usa atribuição rígida por segmento; ainda não possui uma pele anatômica contínua com pesos pintados entre todas as articulações.
- IK analítico para braços/pernas, transferência de peso no soco, preparação/execução/recuperação ligadas ao frame data, passadas relacionadas à distância, guarda de 2,4 segundos e transições de até 6 ticks entre estados. Comprimento visual dos segmentos acompanha o alvo para evitar juntas abertas.
- Salto, voadora com pernas recolhidas, rasteira, golpes baixos, ascendente, defesa, hitstun, dizzy, queda e levantamento. Sem relógio de animação independente que continue a avançar durante pausa/hitstop.
- Câmera ortográfica em viewport transparente 512×512, escala de 100 px/m, MSAA 2× e composição no cenário/HUD existente. Sombreamento em faixas e contorno por inverted hull, compatíveis com o renderer Compatibility/WebGL 2.
- Poderes existentes mantidos: Rajada de Código, Firewall, Enxame de Drones e Sentinela Automática. O gesto do código usa o mesmo socket autoritativo da emissão; os drones continuam sendo entidades simuladas separadamente.

## Identidade facial

A textura é **o próprio arquivo aprovado** `assets/legacy/runtime/marcelo-head-menu-v3.webp`, sem edição ou nova geração. SHA-256:

`8e99b6e49a00511d2235eb674ad742f1c7920de18a1f6d6a7771ff65194b51a0`

Ela é mapeada sobre uma superfície curva com volume craniano posterior. Não é um `Sprite3D`/billboard e não foi substituída por um rosto genérico. A projeção final é espelhada quando o personagem troca de lado, preservando o retrato nos dois sentidos. Isso é adequado ao piloto com câmera fixa; não produz uma cabeça facial completa para close-ups em qualquer ângulo. Essa próxima etapa exige uma reconstrução tridimensional fiel e UVs adicionais.

## Separação do motor

`Fighter3DPose` lê `FighterModel` e retorna alvos visuais em metros. `MarceloModel3D` monta as malhas e resolve as transformações. `Fighter3DView` cuida da câmera e composição. Nenhuma colisão, dano, emissão, número aleatório, snapshot ou entrada consulta ossos ou pixels do viewport.

Os perfis inteiros de colisão aprovados continuam sendo a autoridade, nos dois modos de apresentação. O rig leva punho e pé às respectivas regiões de contato; F1 permite revisar esse registro durante a luta. A migração visual não resolve o rollback online: snapshot/replay local e os limites de rede documentados continuam válidos.

## Arquivos

| Arquivo | Responsabilidade |
|---|---|
| `scenes/characters/marcelo_3d.tscn` | Cena do modelo |
| `scripts/presentation/marcelo_model_3d.gd` | Geometria, materiais e esqueleto |
| `scripts/presentation/fighter_3d_pose.gd` | Poses e IK |
| `scripts/presentation/fighter_3d_view.gd` | Viewport, câmera e comparação |
| `assets/shaders/fighter_toon.gdshader` | Faixas de luz e textura de identidade |
| `assets/shaders/fighter_ink.gdshader` | Contorno |
| `tests/pilot_3d.gd` | Bind pose, estados, golpes e isolamento da simulação |
| `tests/render_3d_pilot.gd` | Capturas reais do renderer OpenGL |

## Validação e Web

`bash tools/test.sh` inclui regressões de combate, progresso e shell, além de transformações finitas de todos os estados/moves, correspondência entre ossos/alvos e invariância do hash após amostragem do rig. O teste Web existente verifica o rig no WASM, alternância F6, movimento, contatos, voadora, ascendente, código/drones, campanha e pontos persistentes. Capturas e vídeo ficam no artefato `StreetVicente-Web-QA` do workflow.

Para capturas nativas, execute com um display OpenGL real ou Xvfb:

```bash
.tools/godot --path . --audio-driver Dummy --script tests/render_3d_pilot.gd
```

O modo `--headless` usa renderer dummy e não serve para avaliar a aparência. Exportação e publicação continuam por `bash tools/export_web.sh` e pelo workflow de GitHub Pages, sem threads ou exigência de cabeçalhos COOP/COEP.

## Limites e continuidade

Este é um piloto funcional da nova apresentação do Marcelo, não a conversão artística completa do jogo. Os outros 12 personagens, as prévias da seleção e os cenários permanecem em 2D. O corpo ainda precisa de topologia contínua, refinamento anatômico e acabamento de materiais; a cabeça precisa de reconstrução fiel para vistas livres. A qualidade final de Marvel vs. Capcom 3 não resulta apenas de adicionar um esqueleto e um shader.

Antes de replicar o método para todo o elenco: refinar o modelo em DCC, validar silhueta/rosto em vistas frontal e três quartos, pintar pesos, separar animações por estilo e medir frame time em hardware Web representativo. A câmera fixa, a interface entre simulação/apresentação e o fluxo de exportação deste piloto podem ser preservados ao substituir a malha inicial por uma produção artística mais detalhada.
