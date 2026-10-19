/* Real keyboard input; svfQA only observes the exported Godot simulation. */
const {chromium}=require('playwright');const assert=require('node:assert/strict');
const fs=require('node:fs');const path=require('node:path');const {spawn}=require('node:child_process');
process.chdir(path.resolve(__dirname,'..'));fs.mkdirSync('test-results',{recursive:true});
if(!fs.existsSync('build/StreetVicente'))fs.symlinkSync('web','build/StreetVicente');
const server=spawn('python3',['-m','http.server','8067','--directory','build','--bind','127.0.0.1']);
const delay=ms=>new Promise(r=>setTimeout(r,ms));let browser,page;const errors=[];
(async()=>{
 for(let i=0;i<50;i++){try{if((await fetch('http://127.0.0.1:8067/StreetVicente/')).ok)break;}catch{}await delay(100);}
 browser=await chromium.launch({headless:true,args:['--use-angle=swiftshader','--enable-unsafe-swiftshader']});
 page=await browser.newPage({viewport:{width:1280,height:720}});
 page.on('pageerror',e=>errors.push(String(e)));page.on('console',m=>{if(/SCRIPT ERROR|Parse Error|ERROR:/i.test(m.text()))errors.push(m.text());});
 const state=()=>page.evaluate(()=>window.svfQA);
 const wait=(fn,arg=null)=>page.waitForFunction(fn,arg,{timeout:30000});
 const observe=async(fn,arg=null)=>{const h=await wait(fn,arg);try{return await h.jsonValue();}finally{await h.dispose();}};
 const shot=async name=>{await page.keyboard.press('Escape');await wait(()=>window.svfQA.paused);await page.screenshot({path:'test-results/'+name});await page.keyboard.press('Enter');await wait(()=>!window.svfQA.paused);};
 const select=async id=>{const q=await state();for(let i=0;i<(q.roster_ids.indexOf(id)-q.cursor+13)%13;i++)await page.keyboard.press('ArrowRight');await page.keyboard.press('Enter');};
 const approach=async()=>{await page.keyboard.press('F8');await wait(()=>window.svfQA.state==='IDLE');await page.keyboard.down('d');await wait(()=>window.svfQA.x[1]-window.svfQA.x[0]<175*256);await page.keyboard.up('d');};
 await page.goto('http://127.0.0.1:8067/StreetVicente/?qa=1',{timeout:120000});
 await wait(()=>window.svfQA?.screen==='menu');
 for(let i=0;i<4;i++)await page.keyboard.press('ArrowDown');await page.keyboard.press('Enter');await wait(()=>window.svfQA.screen==='selection');
 await select('marcos');await wait(()=>window.svfQA.slot===1);await select('rafael');await wait(()=>window.svfQA.screen==='stage_selection');
 await page.keyboard.press('Enter');await wait(()=>window.svfQA.screen==='fight'&&window.svfQA.intro_ticks===0);
 assert.deepEqual((await state()).selected,['marcos','rafael']);
 assert.match((await state()).art_sheet,/marcos\/arcade-v16\/states/);assert.equal((await state()).art_face_revision,16);
 const height=(await state()).art_height;await shot('23-marcos-guard.png');
 const x=(await state()).x[0];await page.keyboard.down('d');await wait(x=>window.svfQA.x[0]>x+20*256,x);
 assert.match((await state()).art_sheet,/marcos\/arcade-v16\/walk/);await shot('23-marcos-walk.png');await page.keyboard.up('d');
 await page.keyboard.down('s');await wait(()=>window.svfQA.state==='CROUCH');const low=(await state()).art_height;
 assert(low<height*.76);await page.keyboard.press('f');
 let q=await observe(()=>{const q=window.svfQA;return q.moves[0]==='crouchPunch:1'?q:null;});
 assert.equal(q.pose,'low');assert(q.art_scale<=1);assert(Math.abs(q.art_height-low)<18);
 await shot('23-marcos-low.png');await page.keyboard.up('s');await wait(()=>window.svfQA.state==='IDLE');
 for(const [key,move,pose,effect] of [['h','special:1','session','sessionLock'],['u','uppercut:1','rise','reverseStack'],['q','super:1','panic','kernelPanic'],['e','throw:1','throw',null]]){
  await approach();await page.keyboard.press(key);
  await wait(move=>window.svfQA.last_contacts.some(e=>e.character==='marcos'&&e.move===move&&e.kind==='hit'),move);
  // Freeze through the player's pause input immediately after contact. Several
  // inspection round trips first would let the short digital burst expire.
  await page.keyboard.press('Escape');await wait(()=>window.svfQA.paused);
  q=await state();assert.equal(q.projectiles,0);assert(q.hp[1]<1000);
  const active=q.trace.find(q=>q.move===move&&q.hit_count>0);
  assert(active);assert.equal(active.pose,pose);assert.equal(active.art_face_revision,16);assert.match(active.art_sheet,/marcos\/arcade-v16/);
  if(effect)assert(q.last_contacts.some(e=>e.effect===effect));
  if(key==='u')assert(q.trace.filter(e=>e.move===move).every(e=>e.y===625*256),'Pilha Reversa mantém os pés no chão');
  if(key==='q')assert.equal(q.meter[0],0);
  await page.screenshot({path:'test-results/23-marcos-'+pose+'.png'});
  await page.keyboard.press('Enter');await wait(()=>!window.svfQA.paused);await wait(()=>window.svfQA.state==='IDLE');
 }
 for(const [key,kind] of [['h','hit'],['q','hit'],['u','block']]){
  await approach();await page.keyboard.press('F2');await page.keyboard.press(key);
  await wait(kind=>window.svfQA.last_contacts.some(e=>e.character==='marcos'&&e.kind===kind),kind);
  assert.equal((await state()).projectiles,0);await wait(()=>window.svfQA.state==='IDLE');
 }
 await page.keyboard.press('Escape');await page.keyboard.press('Escape');await wait(()=>window.svfQA.screen==='menu');
 await page.keyboard.press('ArrowUp');await page.keyboard.press('Enter');await wait(()=>window.svfQA.screen==='selection');await select('marcos');
 await wait(()=>window.svfQA.screen==='story_dialog');await page.keyboard.press('Enter');await wait(()=>window.svfQA.screen==='story');
 q=await state();assert.equal(q.story.character,'marcos');assert.equal(q.story.art_face_revision,16);
 const lane=q.story.ground_y;await page.keyboard.down('w');
 q=await observe(lane=>{const q=window.svfQA;return q.story.ground_y<lane&&q.story.pose==='walk'?q:null;},lane);
 assert.equal(q.story.y,q.story.ground_y);assert.match(q.story.art_sheet,/marcos\/arcade-v16\/walk/);
 await shot('23-marcos-story.png');await page.keyboard.up('w');assert.deepEqual(errors,[]);
 fs.writeFileSync('test-results/marcos-v16-smoke.json',JSON.stringify({status:'passed',checks:['Marcos x Rafael: identidade v16 em todos os golpes','Guarda, tsugi-ashi e pegada baixa sem zoom','H: Sequestro de Sessão vence defesa','U: Pilha Reversa apoiada no chão e bloqueável','Q: Kernel Panic com custo de 100 e projeção','E: Ippon seoi nage com sequência própria','Poderes sem projéteis','História: caminhada em profundidade com nova arte','Console Web limpo']},null,2));
 console.log('MARCOS V16 WEB PASSED: judo, grounded lift, session throw, kernel panic, guard, depth walk');
})().catch(async e=>{console.error(e);if(page&&!page.isClosed()){await page.screenshot({path:'test-results/marcos-v16-failure.png'}).catch(()=>{});console.error(JSON.stringify(await page.evaluate(()=>window.svfQA).catch(()=>({}))));}process.exitCode=1;}).finally(async()=>{if(browser)await browser.close();server.kill();});
