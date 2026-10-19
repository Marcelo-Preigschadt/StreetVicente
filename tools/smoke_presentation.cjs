/* Actual Web UI, local FileReader/OGG playback, stage rendering and Gustavo input. */
const {chromium}=require('playwright');const assert=require('node:assert/strict');
const fs=require('node:fs');const path=require('node:path');const {spawn}=require('node:child_process');
process.chdir(path.resolve(__dirname,'..'));fs.mkdirSync('test-results',{recursive:true});
if(!fs.existsSync('build/StreetVicente'))fs.symlinkSync('web','build/StreetVicente');
const server=spawn('python3',['-m','http.server','8064','--directory','build','--bind','127.0.0.1']);
const delay=ms=>new Promise(r=>setTimeout(r,ms));let browser,page;const errors=[];
(async()=>{
 for(let i=0;i<50;i++){try{if((await fetch('http://127.0.0.1:8064/StreetVicente/')).ok)break;}catch{}await delay(100);}
 browser=await chromium.launch({headless:true,args:['--use-angle=swiftshader','--enable-unsafe-swiftshader']});
 page=await browser.newPage({viewport:{width:1280,height:720}});
 page.on('pageerror',e=>errors.push(String(e)));page.on('console',m=>{if(/SCRIPT ERROR|Parse Error|ERROR:/i.test(m.text()))errors.push(m.text());});
 const state=()=>page.evaluate(()=>window.svfQA);
 const wait=(fn,arg=null)=>page.waitForFunction(fn,arg,{timeout:30000});
 await page.goto('http://127.0.0.1:8064/StreetVicente/?qa=1',{timeout:120000});
 await wait(()=>window.svfQA?.screen==='menu');await page.keyboard.press('F5');await wait(()=>window.svfQA.screen==='stage_selection');
 for(const id of ['patio','nit','cobertura','servidor']){
  await wait(id=>window.svfQA.arena===id&&window.svfQA.arena_ids[window.svfQA.stage_cursor]===id&&window.svfQA.audio.stage===id,id);
  assert.equal((await state()).arena,id);assert((await state()).audio.ambience_playing);
  assert.equal((await state()).audio.playing,false,'Nenhuma trilha gerada ou baixada sem licença no pacote');
  await page.screenshot({path:`test-results/19-arena-${id}.png`});await page.keyboard.press('ArrowRight');
 }
 await wait(()=>window.svfQA.arena==='patio');
 const oldLevel=(await state()).audio.level;await page.keyboard.press('-');await wait(()=>window.svfQA.audio.level<.65);
 assert((await state()).audio.level<oldLevel);await page.keyboard.press('F9');await wait(()=>!window.svfQA.audio.enabled);
 await page.keyboard.press('F9');await wait(()=>window.svfQA.audio.enabled);
 await page.keyboard.press('F6');await page.locator('#svf-music-file').setInputFiles({name:'presentation-fixture.ogg',mimeType:'audio/ogg',buffer:fs.readFileSync('assets/audio/v11/impact-light.ogg')});
 await wait(()=>window.svfQA.audio.local_tracks===1&&window.svfQA.audio.playing);
 assert.equal((await state()).audio.track,'presentation-fixture.ogg');await delay(1000);assert.equal((await state()).audio.decks,1);
 await page.keyboard.press('ArrowRight');await wait(()=>window.svfQA.arena==='nit'&&window.svfQA.audio.stage==='nit'&&!window.svfQA.audio.playing);
 await page.keyboard.press('ArrowLeft');await wait(()=>window.svfQA.audio.stage==='patio'&&window.svfQA.audio.playing);
 await page.keyboard.press('Delete');await wait(()=>window.svfQA.audio.local_tracks===0&&!window.svfQA.audio.playing);
 await page.keyboard.press('Escape');await wait(()=>window.svfQA.screen==='menu');
 for(let i=0;i<4;i++)await page.keyboard.press('ArrowDown');await page.keyboard.press('Enter');await wait(()=>window.svfQA.screen==='selection');
 let q=await state();for(let i=0;i<(q.roster_ids.indexOf('gustavo')-q.cursor+13)%13;i++)await page.keyboard.press('ArrowRight');
 await page.keyboard.press('Enter');await wait(()=>window.svfQA.slot===1);
 q=await state();for(let i=0;i<(q.roster_ids.indexOf('rafael')-q.cursor+13)%13;i++)await page.keyboard.press('ArrowRight');
 await page.keyboard.press('Enter');await wait(()=>window.svfQA.screen==='stage_selection');await page.keyboard.press('Enter');
 await wait(()=>window.svfQA.screen==='fight'&&window.svfQA.intro_ticks===0);
 assert.match((await state()).art_sheet,/gustavo\/arcade-v12/);const start=(await state()).x[0];
 await page.keyboard.down('d');await wait(start=>window.svfQA.x[0]>start+20*256,start);
 assert.match((await state()).art_sheet,/arcade-v12\/walk/);await page.keyboard.up('d');
 await page.keyboard.down('d');await wait(()=>window.svfQA.x[1]-window.svfQA.x[0]<180*256);await page.keyboard.up('d');
 await page.keyboard.press('f');await wait(()=>window.svfQA.contact_clips?.includes('light'));
 await page.keyboard.press('Escape');await wait(()=>window.svfQA.paused);await page.screenshot({path:'test-results/19-gustavo-contact.png'});
 const hp=(await state()).hp;await page.keyboard.press('F5');await wait(()=>window.svfQA.screen==='stage_selection');
 await page.keyboard.press('ArrowRight');await page.keyboard.press('Enter');await wait(()=>window.svfQA.screen==='fight');
 assert.deepEqual((await state()).hp,hp,'Trocar cenário mantém a luta');
 await page.keyboard.press('F8');await delay(200);await page.keyboard.press('F2');
 await page.keyboard.down('d');await wait(()=>window.svfQA.x[1]-window.svfQA.x[0]<180*256);await page.keyboard.up('d');
 await page.keyboard.press('f');await wait(()=>window.svfQA.contact_clips?.includes('block'));
 await page.keyboard.press('Escape');await wait(()=>window.svfQA.paused);await page.screenshot({path:'test-results/19-gustavo-block.png'});
 // Gustavo v12: actual low inputs, source resolution and all three preserved powers.
 await page.keyboard.press('F8');await wait(()=>!window.svfQA.paused&&window.svfQA.state==='IDLE');
 const standing=(await state()).art_height;
 await page.keyboard.down('s');await wait(()=>window.svfQA.state==='CROUCH');
 const crouch=(await state()).art_height;assert(crouch<standing*.76,'Crouch shrinks by bending, never enlarges');
 await page.keyboard.press('f');await wait(()=>window.svfQA.moves[0]==='crouchPunch:1');
 q=await state();assert.equal(q.pose,'low');assert.equal(q.art_source,'low');assert(q.art_scale<=1);assert(Math.abs(q.art_height-crouch)<10);
 await page.keyboard.press('Escape');await wait(()=>window.svfQA.paused);await page.screenshot({path:'test-results/20-gustavo-low.png'});
 await page.keyboard.up('s');await page.keyboard.press('Enter');await wait(()=>!window.svfQA.paused);
 for(const [key,move] of [['h','special:1'],['u','uppercut:1'],['q','super:1']]){
  await page.keyboard.press('F8');await wait(()=>window.svfQA.state==='IDLE');
  await page.keyboard.press(key);
  // Retain the matching render observation: another protocol round trip can
  // otherwise read the airborne recovery or idle pose after the cast ends.
  const castHandle=await wait(move=>{const q=window.svfQA;return q.moves[0]===move&&q.art_source==='powers'?q:null;},move);
  const cast=await castHandle.jsonValue();await castHandle.dispose();
  assert.match(cast.art_sheet,/gustavo\/arcade-v12/);assert.equal(cast.art_source,'powers');
  if(key!=='u'){
   await wait(()=>window.svfQA.projectiles>0);
   await page.keyboard.press('Escape');await wait(()=>window.svfQA.paused);
   await page.screenshot({path:`test-results/20-gustavo-${key}-smoke.png`});
   await page.keyboard.press('Enter');await wait(()=>!window.svfQA.paused);
   await wait(()=>window.svfQA.last_contacts.some(e=>e.kind==='hit'));
  }else{await wait(()=>window.svfQA.trace.some(q=>q.move==='uppercut:1'&&q.y<600*256));await page.screenshot({path:'test-results/20-gustavo-upper.png'});}
  await wait(()=>window.svfQA.state==='IDLE');
 }
 console.log('GUSTAVO V12 WEB PASSED: crouch proportion, new cels, H/U/Q smoke');
 assert.deepEqual(errors,[],'Apresentação e áudio local sem erros Web');
 fs.writeFileSync('test-results/presentation-v11-smoke.json',JSON.stringify({status:'passed',checks:['Quatro arenas pela interface','Ambiente por arena','Volume e mute','Importação local MP3/OGG sem upload','Crossfade limitado a dois decks','Faixa local por arena e remoção','Gustavo com corpo novo ao andar e socar','Acerto leve e bloqueio com cels próprios','Troca de arena mantém HP','Gustavo v12: agachar/socar sem mudança de tamanho','H/U/Q preservados com nova fumaça','Console Web limpo']},null,2));
 console.log('PRESENTATION V11 WEB PASSED: stages, local audio, Gustavo, contact/block');
})().catch(async e=>{console.error(e);if(page&&!page.isClosed()){await page.screenshot({path:'test-results/presentation-v11-failure.png'}).catch(()=>{});console.error(JSON.stringify(await page.evaluate(()=>window.svfQA).catch(()=>({}))));}process.exitCode=1;}).finally(async()=>{if(browser)await browser.close();server.kill();});
