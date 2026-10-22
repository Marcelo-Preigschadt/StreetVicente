# Ruan: identidade original, Karatê e grandes frentes elétricas

Revisão seguinte à Luciana v18, seguindo a referência aprovada de movimentos e escala da Tais v17. A selfie original `IMG-20261006-WA0009.jpg` orienta a identidade facial em cada folha; o retrato aprovado e os atlas originais preservam a continuidade do personagem. Rosto arredondado, nariz largo, lábios cheios, óculos retangulares, bigode e barba no queixo foram comparados visualmente às referências. Mantidos boné preto para trás, jaqueta verde, camiseta branca, calça azul escura, tênis preto/branco, mãos sem luvas, retrato e vozes individuais em português brasileiro.

São 88 desenhos completos de fonte, 87 distintos consumidos, e 24 cels próprios de efeitos. A guarda baixa compartilha o início/fim do gyaku-zuki baixo. Guarda, caminhada de Karatê, defesas, agachamento, saltos, aterrissagem, reações, vitória, gyaku-zuki, mae-geri, ashi-barai, zuki aéreo, yoko-geri aéreo, agarrão e poderes usam o conjunto v19. A rasteira mantém a escala do corpo e ambos os braços visíveis. No mae-geri, as duas mãos permanecem em guarda. `face_revision: 19` verifica proveniência do recurso; semelhança facial é verificação visual.

| Comando | Nome original | Apresentação e contato |
| --- | --- | --- |
| H | Pulso de Choque | Gyaku-zuki emite frente elétrica azul/violeta pelo punho; desenho de 320 × 260 px e núcleo físico de raio 68 px |
| U | Punho de Trovão | Compressão, impulso, punho ascendente, subida física, ápice e aterrissagem; arco de raios de 370 × 470 px acompanha o movimento |
| Q | Kata da Tempestade | Três grandes frentes de 480 × 460 px, rastro de até 680 px com ramificações e explosão de 640 × 540 px; núcleo físico de raio 152 px |

Azul, violeta e núcleos brancos distinguem o Ruan da descarga corporal verde do João. Carga, liberação, frente, arco e explosão usam desenhos próprios. Raios históricos e halos ficam atrás dos atores para preservar a leitura das silhuetas. O impacto do Q persiste por 0,85 s; H/U por 0,6 s. A defesa reduz o tamanho visual da explosão. Uma malha de apresentação em cache dissipa a opacidade nas margens de cada cel para impedir cortes retangulares e vazamento de quadros vizinhos, mantendo os pixels originais do núcleo. Somente os núcleos registrados causam colisão varrida determinística; halos e rastros não geram contatos adicionais.

Danos, velocidades, três ondas, cadência de dez ticks, comandos, nomes, falas e custo de 100 da barra do Q foram preservados. H/Q continuam bloqueáveis. U continua salto real. As emissões seguem os punhos dos novos desenhos nos dois sentidos. Contatos dos golpes normais acompanham os membros; a rasteira inclui a canela e o tênis visíveis. Caminhar em profundidade W/S no História também anima o corpo inteiro sem confundir salto e faixa.

## Fontes e reprodução

- `assets/source/ruan-v19/`: referências já públicas do projeto original, modelo, folhas selecionadas, prompts, hashes de proveniência e registro anatômico/de contatos; excluído do export por `.gdignore`.
- `assets/characters/ruan/arcade-v19/`: dez atlas de runtime; `assets/effects/ruan-v19/`: dois atlas exclusivos de efeitos elétricos.
- `tools/pack_ruan_v19.py`: recorte e empacotamento reproduzíveis, sem ampliar fontes, deformar membros ou colar rostos.
- `scripts/combat/ruan_pose_v19.gd`: exposição sincronizada aos três disparos e à física da subida.
- `scripts/presentation/ruan_fx_v19.gd`: carga, emissão, frentes, ramificações e dissipação.
- `tests/ruan_v19.gd`: recursos, escala, regressão da rasteira, contato bilateral, defesa, salto e emissão.
- `tools/smoke_ruan.cjs`: teclado real no WASM, História e medição dos pixels novos de energia.

```bash
python3 tools/pack_ruan_v19.py
bash tools/test.sh
bash tools/export_web.sh
npm run test:web
```

Arte gerada com ImageGen integrado. Fontes conservam resolução nativa e alpha; agachamento e pernas dobradas mantêm o mesmo fator de escala dentro da sequência. A publicação depende da bateria nativa e da suíte completa de navegador do workflow.

Validação local: 97.895 verificações nativas, zero falhas. O teste específico do WASM passou com teclado real, defesa, salto e História; mediu 56.912 pixels novos de energia no Q e 416 px de altura, contra 19.656 pixels no H. São observações de uma captura real, não as dimensões nominais do desenho. A suíte completa integra a verificação específica do Ruan.
