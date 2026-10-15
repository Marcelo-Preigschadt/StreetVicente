# Web e Codespaces

Versão fixada: Godot 4.5.1 Standard/GDScript. Preset Web, Compatibility → WebGL 2, threads/GDExtension/PWA desativados. Não exige SharedArrayBuffer ou COOP/COEP.

```bash
bash tools/setup_godot.sh
bash tools/test.sh
bash tools/export_web.sh
python3 -m http.server 8060 --directory build/web
```

Abrir o link encaminhado da porta 8060 em Ports. Requer HTTP/HTTPS, WASM e WebGL 2. Não há dependência de Node.js em produção.

O instalador baixa arquivos oficiais e verifica SHA512 pelo manifesto da release. Usa `.tools/godot` e `$XDG_DATA_HOME/godot/export_templates/4.5.1.stable` ou `~/.local/share/...`. Para usar instalação própria: `GODOT_BIN=/caminho/godot bash tools/test.sh` e o mesmo para exportar. Templates precisam coincidir com a versão do editor.

## Editor desktop

Importar project.godot → Editor → Manage Export Templates → instalar mesma versão → Project → Export → Web. Confirmar Thread Support OFF, Extension Support OFF e Compatibility. Exportar `build/web/index.html`; servir a pasta inteira. O script cria `.nojekyll` e verifica arquivos/caminhos.

## Actions e Pages

Build e deploy são separados. Build falha em erro de parser, regressão ou pacote incompleto. Artefato StreetVicente-Web permite baixar o jogo mesmo antes de configurar Pages. PRs validam sem publicar; push na main publica com Pages OIDC.

Settings → Pages → Source **GitHub Actions** é a configuração inicial. configure-pages tenta habilitar automaticamente; GITHUB_TOKEN pode não ter a autorização administrativa dessa primeira operação. Nesse caso, selecionar Source e executar Run workflow. Builds seguintes não precisam de PAT.

O artefato publica seus arquivos na raiz de `/StreetVicente/` e usa caminhos relativos. Não renomear arquivos, publicar somente HTML, colocar `/index.wasm` absoluto ou introduzir rotas de SPA. O build não entra no histórico Git.

## Verificação no navegador

- Console sem erros de script/engine; WASM/PCK com HTTP 200 e MIME `application/wasm` para WASM.
- Movimento/jump/crouch/soco/chute/rasteira/voadora para ambos; F1 caixas apenas no active.
- F2 defesa alta bloqueia mid e perde para low; defesa baixa bloqueia low e perde para overhead.
- Hold não repete ataque; comando no fim de recovery executa na janela livre.
- Hitstop, HP, timer, KO e reset; sem dano repetido no mesmo golpe.
- Resize mantém proporção e origem; fullscreen após gesto do usuário. Esc também é reservado pelo navegador para sair de fullscreen.
- Trocar aba pausa local e limpa teclas; Esc retoma. Online precisará de pausa coordenada.
- Comparar Chromium/Firefox, hardware alvo e dois controles físicos, inclusive conectar/desconectar. Teste sintético não prova mapeamento de um dispositivo USB real.

Quando migrados, usar áudio importado em Sample para efeitos/vozes e desbloquear com gesto inicial. Não depender de efeitos de barramento ou áudio procedural nesse modo. Manter GDScript para export Web.

## Desempenho

A troca de engine não garante fluidez automaticamente. Medir tempo de tick/render, memória e download; consolidar um lutador/stage antes do elenco inteiro. Compartilhar atlas, limitar efeitos/entidades e perfilar WASM. Pooling só quando medido e com IDs/spawn determinísticos.
