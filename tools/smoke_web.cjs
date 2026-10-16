/* QA uses real keyboard/mouse input. svfQA is a read-only state observer. */
const {chromium}=require('playwright');
const assert=require('node:assert/strict');const {PNG}=require('pngjs');
const fs=require('node:fs');const path=require('node:path');const {spawn}=require('node:child_process');
process.chdir(path.resolve(__dirname,'..'));fs.mkdirSync('test-results',{recursive:true});
if(!fs.existsSync('build/StreetVicente'))fs.symlinkSync('web','build/StreetVicente');
const server=spawn('python3',['-m','http.server','8061','--directory','build','--bind','127.0.0.1']);
const delay=ms=>new Promise(r=>setTimeout(r,ms));let browser,page;const errors=[];
(async()=>{
 for(let i=0;i<50;i++){try{if((await fetch('http://127.0.0.1:8061/StreetVicente/')).ok)break;}catch{}await delay(100);}
 browser=await chromium.launch({headless:true,args:['--use-angle=swiftshader','--enable-unsafe-swiftshader']});
 page=await browser.newPage({viewport:{width:1280,height:720},recordVideo:{dir:'test-results/video',size:{width:1280,height:720}}});
 const responses={};page.on('pageerror',e=>errors.push(String(e)));page.on('console',m=>{if(/SCRIPT ERROR|Parse Error|Failed to load|ERROR:|observer enabled/i.test(m.text())){console.log('BROWSER',m.text());if(!/observer enabled/i.test(m.text()))errors.push(m.text());}});
 page.on('response',r=>{if(/index\.(wasm|pck)$/.test(r.url()))responses[r.url().split('/').pop()]=r.status();});
 const state=()=>page.evaluate(()=>window.svfQA);
 const wait=fn=>page.waitForFunction(fn,null,{timeout:25000});
 const pausedShot=async file=>{await page.keyboard.press('Escape');await wait(()=>window.svfQA?.paused===true);const png=await page.screenshot(file?{path:file}:{});await page.keyboard.press('Enter');await wait(()=>window.svfQA?.paused===false);return png;};
 const green=(r,g,b)=>g>160&&g>r*1.1&&g>b*1.3;
 const addedGreen=(before,after)=>{const a=PNG.sync.read(before),b=PNG.sync.read(after);let count=0;for(let y=170;y<635;y++)for(let x=100;x<1180;x++){const i=(y*b.width+x)*4;if(green(b.data[i],b.data[i+1],b.data[i+2])&&!green(a.data[i],a.data[i+1],a.data[i+2]))count++;}return count;};
 await page.goto('http://127.0.0.1:8061/StreetVicente/?qa=1',{timeout:120000});
 await page.waitForFunction(()=>window.svfQA?.screen==='menu',null,{timeout:90000});
 assert.equal((await state()).roster,13);await page.screenshot({path:'test-results/01-menu.png'});
 // First menu entry directly starts the new-art pilot in native Godot training.
 await page.keyboard.press('Enter');await wait(()=>window.svfQA?.screen==='fight');
 assert.deepEqual((await state()).selected,['marcelo','rafael']);assert.equal((await state()).new_art,true);
 assert.equal((await state()).fx_revision,4,'Pacote novo de geometria e VFX');
 await page.screenshot({path:'test-results/02-pilot-ready.png'});
 let before=await state();await page.keyboard.down('d');await delay(350);await page.keyboard.up('d');
 let moved=await state();assert(moved.x[0]>before.x[0]+40*256,'Movimento real no WASM');
 await page.keyboard.press('w');await wait(()=>window.svfQA?.state==='JUMP');
 assert((await state()).y[0]<625*256,'Salto altera altura');await page.screenshot({path:'test-results/03-jump.png'});
 // Screenshots can take longer than a whole jump on software WebGL. Capture the
 // first jump, then issue the kick immediately on a second jump before capturing.
 await wait(()=>window.svfQA?.state==='IDLE');await page.keyboard.press('w');await wait(()=>window.svfQA?.state==='JUMP');
 await page.keyboard.press('g');await wait(()=>window.svfQA?.pose==='air'&&window.svfQA?.pose_index>=3);
 assert.equal((await state()).moves[0],'airKick:1');await page.screenshot({path:'test-results/03a-air-kick.png'});
 await wait(()=>window.svfQA?.state==='LANDING'||window.svfQA?.state==='IDLE');await delay(120);
 assert.equal((await state()).moves[0],'');assert.equal((await state()).state,'IDLE','Aterrissagem termina ataque aéreo');
 await page.keyboard.press('r');await delay(150);await page.keyboard.down('d');
 await wait(()=>window.svfQA && window.svfQA.x[1]-window.svfQA.x[0]<180*256);await page.keyboard.up('d');await delay(100);
 before=await state();await page.keyboard.press('f');await wait(()=>window.svfQA?.hp[1]<1000);
 const contact=(await state()).last_contacts.find(e=>e.kind==='hit');assert(contact,'Contato autoritativo disponível');
 assert(before.hurtboxes[1].some(r=>contact.x/256>=r[0]-4&&contact.x/256<=r[0]+r[2]+4&&contact.y/256>=r[1]-4&&contact.y/256<=r[1]+r[3]+4),'Impacto localizado no desenho do Rafael');
 assert((await state()).hp[1]<before.hp[1],'Soco aplica dano');await page.screenshot({path:'test-results/04-contact.png'});
 await delay(500);await page.keyboard.press('g');await delay(160);await page.screenshot({path:'test-results/05-kick.png'});await delay(600);
 await page.keyboard.down('s');await page.keyboard.press('g');await delay(200);assert.equal((await state()).pose,'low');await page.screenshot({path:'test-results/06-low.png'});await page.keyboard.up('s');
 // Freeze through the player's normal pause control for both images. Software
 // WebGL screenshot latency must not let the projectile hit and disappear first.
 // Explicit uppercut review: freeze each capture with normal pause, not a QA mutation.
 await page.keyboard.press('r');await delay(150);await page.keyboard.press('y');
 await wait(()=>window.svfQA?.moves?.[0]==='uppercut:1'&&window.svfQA?.y?.[0]<625*256&&window.svfQA?.pose==='combat'&&window.svfQA?.pose_index===10);
 await pausedShot('test-results/06a-uppercut-rise.png');
 // Return the immutable observer object from the matching render. A second
 // evaluate after waitForFunction can observe landing on slow software WebGL.
 const fallHandle=await wait(()=>{const q=window.svfQA;return q?.moves?.[0]==='uppercut:1'&&q.vy>500&&q.y[0]<625*256?q:null;});
 const fall=await fallHandle.jsonValue();await fallHandle.dispose();assert.equal(fall.pose,'states','Gancho usa pose aérea durante a descida');assert.equal(fall.pose_index,8);assert.equal(fall.hitboxes[0].length,0,'Sem hitbox na recuperação');
 await pausedShot('test-results/06b-uppercut-fall.png');await wait(()=>window.svfQA?.state==='IDLE');
 assert.equal((await state()).y[0],625*256,'Gancho retorna ao chão');
 await page.keyboard.press('r');await delay(200);const baseFx=await pausedShot();await page.keyboard.press('t');await wait(()=>window.svfQA?.projectiles>0);
 const codeFx=await pausedShot('test-results/07-code.png');const codePixels=addedGreen(baseFx,codeFx);
 assert(codePixels>300,'Onda de código deve estar visível em pixels, não apenas existir na simulação');await delay(900);
 await page.keyboard.press('u');await wait(()=>window.svfQA?.projectiles>=5);
 assert.equal((await state()).meter[0],0,'Super consome barra');
 // Observe the beam before any screenshot can consume its flight window. A
 // separate Q cast gives the stationary drone a longer, two-second windup shot.
 await wait(()=>window.svfQA?.power_positions?.some(p=>p.kind==='laser'&&p.age>=5));await page.screenshot({path:'test-results/08a-drone-laser.png'});
 await page.keyboard.press('r');await delay(150);await page.keyboard.press('q');await wait(()=>window.svfQA?.power_kinds?.includes('drone'));await page.screenshot({path:'test-results/08-drones.png'});
 // Approach to the physical body limit and cast through the normal controls.
 // The release socket may be beyond the opponent; the first swept segment must hit.
 await page.keyboard.press('r');await delay(150);await page.keyboard.down('d');await wait(()=>window.svfQA.x[1]-window.svfQA.x[0]<112*256);await page.keyboard.up('d');
 const closeState=await state();assert(closeState.x[1]-closeState.x[0]>=106*256,'Pushboxes evitam sobreposição de troncos');
 await page.keyboard.press('t');await wait(()=>window.svfQA.hp[1]<1000);await page.screenshot({path:'test-results/08b-code-close-contact.png'});
 await page.keyboard.press('F4');await wait(()=>window.svfQA?.new_art===false);await page.screenshot({path:'test-results/09-old-art-comparison.png'});await page.keyboard.press('F4');
 await page.keyboard.press('Escape');await delay(100);before=await state();await delay(250);assert.equal((await state()).tick,before.tick,'Pausa congela simulação');
 await page.keyboard.press('Escape');await wait(()=>window.svfQA?.screen==='menu');
 // Selection includes all approved portraits and original quotes.
 await page.keyboard.press('ArrowDown');await page.keyboard.press('Enter');await wait(()=>window.svfQA?.screen==='selection');
 await page.screenshot({path:'test-results/10-roster.png'});await page.keyboard.press('Escape');
 // Campaign shell uses original stages/enemies and independent lane/jump coordinates.
 await page.keyboard.press('ArrowDown');await page.keyboard.press('ArrowDown');await page.keyboard.press('Enter');await wait(()=>window.svfQA?.screen==='selection');
 await page.keyboard.press('Enter');await wait(()=>window.svfQA?.screen==='story');await delay(400);
 assert((await state()).story.enemies>=3);await page.keyboard.press('Space');await delay(180);await page.screenshot({path:'test-results/11-story.png'});await delay(800);
 // Restart each campaign check through R: screenshot latency must not let the
 // approaching enemies interrupt the next cast before its startup completes.
 await page.keyboard.press('r');await delay(100);await page.keyboard.press('t');await wait(()=>window.svfQA?.story?.projectiles>0);assert.equal((await state()).story.power_sprites,true);await page.screenshot({path:'test-results/11a-story-code.png'});
 await page.keyboard.press('r');await delay(100);await page.keyboard.press('q');await wait(()=>window.svfQA?.story?.power_kinds?.includes('drone'));await page.screenshot({path:'test-results/11b-story-drone.png'});
 await page.keyboard.press('Escape');await page.keyboard.press('Escape');await wait(()=>window.svfQA?.screen==='menu');
 // Visual review playback, actual commands into the same simulation as the player.
 await page.keyboard.press('ArrowUp');await page.keyboard.press('ArrowUp');await page.keyboard.press('ArrowUp');await page.keyboard.press('Enter');
 await wait(()=>window.svfQA?.screen==='fight');await page.keyboard.press('F3');await delay(11000);await page.screenshot({path:'test-results/12-demo.png'});
 // Select and cast all new thematic VFX using only normal UI/keyboard controls.
 await page.keyboard.press('Escape');await page.keyboard.press('Escape');await wait(()=>window.svfQA?.screen==='menu');
 for(const id of ['gustavo','khauany','dienes']){
  for(let i=0;i<4;i++)await page.keyboard.press('ArrowDown');await page.keyboard.press('Enter');await wait(()=>window.svfQA?.screen==='selection');
  let q=await state();const target=q.roster_ids.indexOf(id);for(let i=0;i<(target-q.cursor+13)%13;i++)await page.keyboard.press('ArrowRight');
  await page.keyboard.press('Enter');await page.keyboard.press('Enter');await wait(()=>window.svfQA?.screen==='fight');
  await page.keyboard.press(id==='dienes'?'u':'t');await wait(()=>window.svfQA?.projectiles>0);await page.screenshot({path:`test-results/14-${id}-power.png`});
  await page.keyboard.press('Escape');await page.keyboard.press('Escape');await wait(()=>window.svfQA?.screen==='menu');
  // menu_index was 4 (training); move it to 0 for the next iteration.
  for(let i=0;i<4;i++)await page.keyboard.press('ArrowUp');
 }
 await page.setViewportSize({width:960,height:540});await delay(200);await page.screenshot({path:'test-results/13-resize.png'});
 assert.equal(responses['index.wasm'],200);assert.equal(responses['index.pck'],200);assert.deepEqual(errors,[],'Console Web sem erros');
 fs.writeFileSync('test-results/web-smoke.json',JSON.stringify({status:'passed',checks:['WASM/PCK sob /StreetVicente/','13 personagens','nova arte por estados','voadora dedicada e aterrissagem','gancho: subida e queda sem pose de chão no ar','efeito código visível em pixels','drone estacionário e laser','efeitos no História','fumaça/garfos/livros','movimento','prejump/salto','soco com dano','chute','rasteira','código','cinco drones','comparação de arte','pausa','seleção','história','demonstração','resize','console sem erros'],responses,codePixels},null,2));
 await page.close();console.log('WEB SMOKE PASSED: novo Marcelo + combate/poderes + roster + história');
})().catch(async e=>{console.error(e);console.error('Browser errors:',JSON.stringify(errors));if(page&&!page.isClosed()){await page.screenshot({path:'test-results/failure.png'}).catch(()=>{});const status=await page.evaluate(()=>({url:location.href,qa:window.svfQA,status:document.getElementById('status')?.innerText})).catch(()=>({}));console.error('Browser state:',JSON.stringify(status));fs.writeFileSync('test-results/failure.json',JSON.stringify({error:String(e),errors,status},null,2));}process.exitCode=1;}).finally(async()=>{if(browser)await browser.close();server.kill();});
