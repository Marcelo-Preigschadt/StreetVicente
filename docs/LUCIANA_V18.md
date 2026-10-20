# Luciana: rosto original, MMA e grandes poderes de linguagem

Revisão seguinte à Tais v17, cujo padrão de movimentos e escala de poderes foi aprovado pelo usuário. A identidade usa `luciana-portrait-v1.webp`, o retrato aprovado `luciana-head-menu-v3.webp` e as folhas originais do projeto Canvas. O rosto adulto, olhos, nariz, linhas de expressão, cabelo loiro escuro liso repartido de lado e brincos foram comparados visualmente às referências em todas as folhas. Mantidos camiseta azul, calça preta, luvas MMA vermelhas/pretas, tênis brancos, retrato e vozes individuais.

São 88 desenhos completos de fonte, 87 distintos consumidos, e 24 cels de efeitos. A guarda baixa compartilha o início/fim do direto baixo. Guarda, caminhada, defesa, agachamento, salto, aterrissagem, reações, vitória, direto, joelhada curta, direto no corpo, low kick, cruzado aéreo, joelhada voadora, clinch e poderes usam os novos desenhos. `face_revision: 18` verifica proveniência do recurso; semelhança facial é verificação visual.

| Comando | Nome original | Apresentação e contato |
| --- | --- | --- |
| H | Direto da Palavra | Direto emite cunha de papel e tinta pelo punho; frente de 300 × 250 px, núcleo físico de raio 64 px |
| U | Acento Ascendente | Compressão, uppercut, subida física, ápice e aterrissagem; grande arco de acento e pergaminho de 350 × 450 px acompanha a lutadora |
| Q | Sem Direito a Réplica | Três grandes frentes de 480 × 450 px, rastro de até 680 px e explosão de 640 × 520 px; núcleo físico de raio 150 px |

Violeta, tinta, papel marfim e pontuação dourada distinguem os poderes dos efeitos atléticos da Tais. Carga, liberação, frentes, arco e explosão usam imagens próprias. As fitas de papel e halos ficam atrás dos atores para preservar a leitura do rosto. O impacto do Q persiste por 0,85 s; H/U por 0,6 s. A defesa reduz a dimensão visual da explosão. Halos e rastros são visuais; somente os núcleos registrados participam da colisão varrida determinística.

Danos, velocidades, três ondas, cadência de dez ticks, comandos, nomes, falas e custo de 100 da barra foram preservados. H/Q continuam bloqueáveis. U continua salto real. A emissão usa o punho registrado nos dois sentidos. Contatos de diretos, joelhadas, golpes baixos/aéreos e subida acompanham os membros desenhados. A caminhada também anima o corpo inteiro ao mover em profundidade W/S no História.

## Fontes e reprodução

- `assets/source/luciana-v18/`: referências, modelo, folhas selecionadas, prompts, hashes de proveniência e registro anatômico/de contatos; excluído do export por `.gdignore`.
- `assets/characters/luciana/arcade-v18/`: dez atlas de runtime; `assets/effects/luciana-v18/`: dois atlas próprios de efeitos.
- `tools/pack_luciana_v18.py`: recorte e empacotamento reproduzíveis, preservando pixels e alpha, sem ampliar fontes, deformar membros ou colar rostos.
- `scripts/combat/luciana_pose_v18.gd`: poses sincronizadas aos disparos e à física do salto.
- `scripts/presentation/luciana_fx_v18.gd`: carga, emissão, papel/tinta, grandes frentes e dissipação.
- `tests/luciana_v18.gd`: recursos, escala, contatos bilaterais, defesa, salto e emissão.
- `tools/smoke_luciana.cjs`: teclado real no WASM, História e medição dos pixels novos de energia.

```bash
python3 tools/pack_luciana_v18.py
bash tools/test.sh
bash tools/export_web.sh
npm run test:web
```

Arte gerada com ImageGen integrado. A fonte conserva resolução nativa; dobrar pernas ou agachar não muda a escala dentro da sequência. A publicação depende da bateria nativa e da suíte completa de navegador do workflow.

Validação local: 91.355 verificações nativas, zero falhas. O teste específico do WASM passou com teclado real, defesa, salto e História; mediu 40.529 pixels novos de energia no Q e 417 px de altura, contra 11.473 pixels no H. Esses números são observações de uma captura real, não as dimensões nominais do desenho. A suíte completa também integra a verificação específica da Luciana.
