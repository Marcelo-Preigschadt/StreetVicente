/* Exported WASM, normal keyboard input and immutable QA observations only. */
const {chromium}=require('playwright');const {PNG}=require('pngjs');const assert=require('node:assert/strict');
const fs=require('node:fs');const path=require('node:path');const {spawn}=require('node:child_process');
process.chdir(path.resolve(__dirname,'..'));fs.mkdirSync('test-results',{recursive:true});
if(!fs.existsSync('build/StreetVicente'))fs.symlinkSync('web','build/StreetVicente');
const server=spawn('python3',['-m','http.server','8070','--directory','build','--bind','127.0.0.1']);
const delay=ms=>new Promise(r=>setTimeout(r,ms));let browser,page;const errors=[];
const publicURL=process.env.SVF_KHAUANY_URL;
const net={};if(publicURL){const value=process.env.HTTPS_PROXY||process.env.HTTP_PROXY;if(value){const u=new URL(value);net.proxy={server:u.protocol+'//'+u.hostname+':'+u.port};if(u.username)net.proxy.username=decodeURIComponent(u.username);if(u.password)net.proxy.password=decodeURIComponent(u.password);}}
function bounds(q){return q.hurtboxes.filter(b=>b.length).map(b=>[
 Math.min(...b.map(r=>r[0]))-8,Math.min(...b.map(r=>r[1]))-8,
 Math.max(...b.map(r=>r[0]+r[2]))+8,Math.max(...b.map(r=>r[1]+r[3]))+8]);}
function energyPixels(buffer,baseline,exclude=[]){
 const p=PNG.sync.read(buffer),b=PNG.sync.read(baseline);let count=0,minX=1280,maxX=0,minY=720,maxY=0;
 for(let y=130;y<660;y++)for(let x=240;x<1270;x++){
  if(exclude.some(b=>x>=b[0]&&y>=b[1]&&x<=b[2]&&y<=b[3]))continue;
  const i=(y*p.width+x)*4,r=p.data[i],g=p.data[i+1],v=p.data[i+2];
  const changed=Math.abs(r-b.data[i])+Math.abs(g-b.data[i+1])+Math.abs(v-b.data[i+2])>100;
  const teal=v>140&&v>g*1.12&&r>g*1.05;
  const gold=r>215&&g>190&&v>105&&g>r*.78&&v<r*.88;
  const white=r>220&&g>220&&v>180;
  if(changed&&(teal||gold||white)){count++;minX=Math.min(minX,x);maxX=Math.max(maxX,x);minY=Math.min(minY,y);maxY=Math.max(maxY,y);}
 }
 return {count,width:maxX-minX+1,height:maxY-minY+1};
}
(async()=>{
 for(let i=0;i<50;i++){try{if((await fetch('http://127.0.0.1:8070/StreetVicente/')).ok)break;}catch{}await delay(100);}
 browser=await chromium.launch({...net,headless:true,args:['--use-angle=swiftshader','--enable-unsafe-swiftshader']});
 page=await browser.newPage({viewport:{width:1280,height:720},ignoreHTTPSErrors:true});
 page.on('pageerror',e=>errors.push(String(e)));page.on('console',m=>{if(/SCRIPT ERROR|Parse Error|ERROR:/i.test(m.text()))errors.push(m.text());});
 const state=()=>page.evaluate(()=>window.svfQA);
 const wait=(fn,arg=null)=>page.waitForFunction(fn,arg,{timeout:30000});
 const observe=async(fn,arg=null)=>{const h=await wait(fn,arg);try{return await h.jsonValue();}finally{await h.dispose();}};
 const pause=async()=>{await page.keyboard.press('Escape');await wait(()=>window.svfQA.paused);};
 const resume=async()=>{await page.keyboard.press('Enter');await wait(()=>!window.svfQA.paused);};
 const shot=async name=>{await pause();const b=await page.screenshot({path:'test-results/28-khauany-'+name+'.png'});await resume();return b;};
 const select=async id=>{const q=await state();for(let i=0;i<(q.roster_ids.indexOf(id)-q.cursor+13)%13;i++)await page.keyboard.press('ArrowRight');await page.keyboard.press('Enter');};
 const far=async()=>{await page.keyboard.press('F8');await wait(()=>window.svfQA.state==='IDLE');await page.keyboard.down('a');await wait(()=>window.svfQA.x[0]<110*256);await page.keyboard.up('a');};
 const approach=async()=>{await page.keyboard.press('F8');await wait(()=>window.svfQA.state==='IDLE');await page.keyboard.down('d');await wait(()=>window.svfQA.x[1]-window.svfQA.x[0]<180*256);await page.keyboard.up('d');};
 await page.setExtraHTTPHeaders({'Cache-Control':'no-cache','Pragma':'no-cache'});await page.goto(publicURL||'http://127.0.0.1:8070/StreetVicente/?qa=1',{timeout:180000,waitUntil:'domcontentloaded'});await page.waitForFunction(()=>window.svfQA?.screen==='menu',null,{timeout:120000});
 for(let i=0;i<4;i++)await page.keyboard.press('ArrowDown');await page.keyboard.press('Enter');await wait(()=>window.svfQA.screen==='selection');
 await select('khauany');await wait(()=>window.svfQA.slot===1);await select('rafael');await wait(()=>window.svfQA.screen==='stage_selection');
 await page.keyboard.press('Enter');await wait(()=>window.svfQA.screen==='fight'&&window.svfQA.intro_ticks===0);
 let q=await state();assert.deepEqual(q.selected,['khauany','rafael']);assert.equal(q.art_face_revision,21);assert.match(q.art_sheet,/khauany\/arcade-v21\/states/);
 const height=q.art_height;await shot('guard');await page.keyboard.down('d');
 await wait(()=>window.svfQA.pose==='walk');assert.match((await state()).art_sheet,/khauany\/arcade-v21\/walk/);await page.keyboard.up('d');
 await page.keyboard.down('s');await wait(()=>window.svfQA.state==='CROUCH');const low=(await state()).art_height;assert(low<height*.76);
 await page.keyboard.press('f');q=await observe(()=>{const q=window.svfQA;return q.moves[0]==='crouchPunch:1'?q:null;});
 assert.equal(q.pose,'low');assert(q.art_scale<=1);assert(Math.abs(q.art_height-low)<18);await shot('low');await page.keyboard.up('s');await wait(()=>window.svfQA.state==='IDLE');
 const pixels={};
 for(const [key,move,pose,radius] of [['h','special:1','pulse',64],['q','super:1','champion',150]]){
  await far();const baseState=await state(),baseline=await page.screenshot();await page.keyboard.press(key);
  if(key==='q'){const cast=await observe(()=>window.svfQA.trace.find(t=>t.move==='super:1'&&typeof t.meter==='number'));assert.equal(cast.meter,0);}
  q=await observe(move=>{const q=window.svfQA;return q.moves[0]===move&&q.projectiles>0?q:null;},move);
  assert.equal(q.pose,pose);assert.equal(q.art_face_revision,21);assert(q.power_positions.every(p=>p.radius===radius&&['forkVolley','forkStorm'].includes(p.effect)));
  if(key==='h'){await pause();pixels[key]=energyPixels(await page.screenshot({path:'test-results/28-khauany-'+pose+'-flight.png'}),baseline);await resume();}
  if(key==='q')await wait(()=>window.svfQA.emitted_waves===5);
  await wait(move=>window.svfQA.last_contacts.some(e=>e.character==='khauany'&&e.move===move&&e.kind==='hit'),move);
  if(key==='q'){
   let buffer,current;
   for(let retry=0;retry<8;retry++){
    await wait(()=>{const q=window.svfQA;return q.super_cutin===0&&q.shake===0&&q.power_bursts.some(b=>b.move==='super:1'&&b.kind==='hit'&&b.life>.08);});
    await pause();current=await state();
    if(current.super_cutin===0&&current.shake===0){buffer=await page.screenshot({path:'test-results/28-khauany-champion-unobstructed.png'});await resume();break;}
    await resume();
   }
   assert(buffer,'Captura do efeito real sem faixa do super ou tremor');
   pixels.q={...energyPixels(buffer,baseline,[...bounds(baseState),...bounds(current)]),cutin:current.super_cutin,shake:current.shake,excludes_actor_bounds:true};
   assert(current.hp[1]<1000);
  }else{await pause();await page.screenshot({path:'test-results/28-khauany-'+pose+'-impact.png'});q=await state();assert(q.hp[1]<1000);await resume();}
  await wait(()=>window.svfQA.state==='IDLE');
 }
 assert(pixels.q.count>16000,'Super ocupa área expressiva da arena');assert(pixels.q.height>300,'Frente do super tem altura de um lutador');
 assert(pixels.q.count>pixels.h.count*1.4,'Super tem presença maior que o Chuva de Garfos');
 await approach();await page.keyboard.press('u');
 q=await observe(()=>window.svfQA.trace.find(q=>q.move==='uppercut:1'&&q.pose==='rise'&&q.y<600*256&&q.pose_index>=3));assert.equal(q.art_face_revision,21);
 await wait(()=>window.svfQA.last_contacts.some(e=>e.character==='khauany'&&e.move==='uppercut:1'&&e.kind==='hit'));await shot('ascending-elbow');
 await wait(()=>window.svfQA.state==='IDLE'&&window.svfQA.y[0]===625*256);
 for(const key of ['h','q']){await far();await page.keyboard.press('F2');await page.keyboard.press(key);await wait(()=>window.svfQA.last_contacts.some(e=>e.character==='khauany'&&e.kind==='block'));await wait(()=>window.svfQA.state==='IDLE');}
 await page.keyboard.press('Escape');await page.keyboard.press('Escape');await wait(()=>window.svfQA.screen==='menu');
 await page.keyboard.press('ArrowUp');await page.keyboard.press('Enter');await wait(()=>window.svfQA.screen==='selection');await select('khauany');
 await wait(()=>window.svfQA.screen==='story_dialog');await page.keyboard.press('Enter');await wait(()=>window.svfQA.screen==='story');q=await state();assert.equal(q.story.character,'khauany');assert.equal(q.story.art_face_revision,21);
 const lane=q.story.ground_y;await page.keyboard.down('w');q=await observe(lane=>{const q=window.svfQA;return q.story.ground_y<lane&&q.story.pose==='walk'?q:null;},lane);
 assert.equal(q.story.y,q.story.ground_y);await shot('story');await page.keyboard.up('w');assert.deepEqual(errors,[]);
 fs.writeFileSync('test-results/khauany-v21-smoke.json',JSON.stringify({status:'passed',pixels,checks:['Rosto original, MMA e corpo inteiro v21','Agachamento sem zoom','H: palma com Chuva de Garfos e núcleo ampliado','Q: cinco grandes ondas, rastro e explosão','Super ocupa área grande em pixels reais do render','U: Contra-ataque Ascendente fisicamente aéreo','H/Q bloqueáveis e custo original','História: caminhada em profundidade','Console limpo']},null,2));
 console.log('KHAUANY V21 WEB PASSED: original identity, MMA, large silver fork fronts, ascending elbow, block, Story',JSON.stringify(pixels));
})().catch(async e=>{console.error(e);if(page&&!page.isClosed()){await page.screenshot({path:'test-results/khauany-v21-failure.png'}).catch(()=>{});console.error(JSON.stringify(await page.evaluate(()=>window.svfQA).catch(()=>({}))));}process.exitCode=1;}).finally(async()=>{if(browser)await browser.close();server.kill();});
