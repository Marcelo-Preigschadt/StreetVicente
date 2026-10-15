/* QA uses real keyboard/mouse input. svfQA is a read-only state observer. */
const {chromium}=require('playwright');
const assert=require('node:assert/strict');
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
 await page.goto('http://127.0.0.1:8061/StreetVicente/?qa=1',{timeout:120000});
 await page.waitForFunction(()=>window.svfQA?.screen==='menu',null,{timeout:90000});
 assert.equal((await state()).roster,13);await page.screenshot({path:'test-results/01-menu.png'});
 // First menu entry directly starts the new-art pilot in native Godot training.
 await page.keyboard.press('Enter');await wait(()=>window.svfQA?.screen==='fight');
 assert.deepEqual((await state()).selected,['marcelo','rafael']);assert.equal((await state()).new_art,true);
 await page.screenshot({path:'test-results/02-pilot-ready.png'});
 let before=await state();await page.keyboard.down('d');await delay(350);await page.keyboard.up('d');
 let moved=await state();assert(moved.x[0]>before.x[0]+40*256,'Movimento real no WASM');
 await page.keyboard.press('w');await wait(()=>window.svfQA?.state==='JUMP');
 assert((await state()).y[0]<625*256,'Salto altera altura');await page.screenshot({path:'test-results/03-jump.png'});await delay(900);
 await page.keyboard.press('r');await delay(150);await page.keyboard.down('d');
 await wait(()=>window.svfQA && window.svfQA.x[1]-window.svfQA.x[0]<180*256);await page.keyboard.up('d');await delay(100);
 before=await state();await page.keyboard.press('f');await wait(()=>window.svfQA?.hp[1]<1000);
 assert((await state()).hp[1]<before.hp[1],'Soco aplica dano');await page.screenshot({path:'test-results/04-contact.png'});
 await delay(500);await page.keyboard.press('g');await delay(160);await page.screenshot({path:'test-results/05-kick.png'});await delay(600);
 await page.keyboard.down('s');await page.keyboard.press('g');await delay(200);assert.equal((await state()).pose,'low');await page.screenshot({path:'test-results/06-low.png'});await page.keyboard.up('s');
 await page.keyboard.press('r');await delay(200);await page.keyboard.press('t');await wait(()=>window.svfQA?.projectiles>0);await page.screenshot({path:'test-results/07-code.png'});await delay(900);
 await page.keyboard.press('u');await wait(()=>window.svfQA?.projectiles>=5);await page.screenshot({path:'test-results/08-drones.png'});
 assert.equal((await state()).meter[0],0,'Super consome barra');
 await page.keyboard.press('F4');await wait(()=>window.svfQA?.new_art===false);await page.screenshot({path:'test-results/09-old-art-comparison.png'});await page.keyboard.press('F4');
 await page.keyboard.press('Escape');await delay(100);before=await state();await delay(250);assert.equal((await state()).tick,before.tick,'Pausa congela simulação');
 await page.keyboard.press('Escape');await wait(()=>window.svfQA?.screen==='menu');
 // Selection includes all approved portraits and original quotes.
 await page.keyboard.press('ArrowDown');await page.keyboard.press('Enter');await wait(()=>window.svfQA?.screen==='selection');
 await page.screenshot({path:'test-results/10-roster.png'});await page.keyboard.press('Escape');
 // Campaign shell uses original stages/enemies and independent lane/jump coordinates.
 await page.keyboard.press('ArrowDown');await page.keyboard.press('ArrowDown');await page.keyboard.press('Enter');await wait(()=>window.svfQA?.screen==='selection');
 await page.keyboard.press('Enter');await wait(()=>window.svfQA?.screen==='story');await delay(400);
 assert((await state()).story.enemies>=3);await page.keyboard.press('Space');await delay(180);await page.screenshot({path:'test-results/11-story.png'});
 await page.keyboard.press('Escape');await page.keyboard.press('Escape');await wait(()=>window.svfQA?.screen==='menu');
 // Visual review playback, actual commands into the same simulation as the player.
 await page.keyboard.press('ArrowUp');await page.keyboard.press('ArrowUp');await page.keyboard.press('ArrowUp');await page.keyboard.press('Enter');
 await wait(()=>window.svfQA?.screen==='fight');await page.keyboard.press('F3');await delay(11000);await page.screenshot({path:'test-results/12-demo.png'});
 await page.keyboard.press('Escape');await page.setViewportSize({width:960,height:540});await delay(200);await page.screenshot({path:'test-results/13-resize.png'});
 assert.equal(responses['index.wasm'],200);assert.equal(responses['index.pck'],200);assert.deepEqual(errors,[],'Console Web sem erros');
 fs.writeFileSync('test-results/web-smoke.json',JSON.stringify({status:'passed',checks:['WASM/PCK sob /StreetVicente/','13 personagens','nova arte por estados','movimento','prejump/salto','soco com dano','chute','rasteira','código','cinco drones','comparação de arte','pausa','seleção','história','demonstração','resize','console sem erros'],responses},null,2));
 await page.close();console.log('WEB SMOKE PASSED: novo Marcelo + combate/poderes + roster + história');
})().catch(async e=>{console.error(e);console.error('Browser errors:',JSON.stringify(errors));if(page&&!page.isClosed()){await page.screenshot({path:'test-results/failure.png'}).catch(()=>{});const status=await page.evaluate(()=>({url:location.href,qa:window.svfQA,status:document.getElementById('status')?.innerText})).catch(()=>({}));console.error('Browser state:',JSON.stringify(status));fs.writeFileSync('test-results/failure.json',JSON.stringify({error:String(e),errors,status},null,2));}process.exitCode=1;}).finally(async()=>{if(browser)await browser.close();server.kill();});
