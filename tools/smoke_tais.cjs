/* Exported WASM, normal keyboard input and immutable QA observations only. */
const {chromium}=require('playwright');const {PNG}=require('pngjs');const assert=require('node:assert/strict');
const fs=require('node:fs');const path=require('node:path');const {spawn}=require('node:child_process');
process.chdir(path.resolve(__dirname,'..'));fs.mkdirSync('test-results',{recursive:true});
if(!fs.existsSync('build/StreetVicente'))fs.symlinkSync('web','build/StreetVicente');
const server=spawn('python3',['-m','http.server','8068','--directory','build','--bind','127.0.0.1']);
const delay=ms=>new Promise(r=>setTimeout(r,ms));let browser,page;const errors=[];
function energyPixels(buffer,baseline){
 const p=PNG.sync.read(buffer),b=PNG.sync.read(baseline);let count=0,minX=1280,maxX=0,minY=720,maxY=0;
 for(let y=130;y<660;y++)for(let x=240;x<1270;x++){
  const i=(y*p.width+x)*4,r=p.data[i],g=p.data[i+1],v=p.data[i+2];
  const changed=Math.abs(r-b.data[i])+Math.abs(g-b.data[i+1])+Math.abs(v-b.data[i+2])>100;
  const teal=g>130&&v>115&&g>r*1.3&&v>r*1.15;
  const gold=r>215&&g>190&&v>105&&g>r*.78&&v<r*.88;
  const white=r>220&&g>220&&v>180;
  if(changed&&(teal||gold||white)){count++;minX=Math.min(minX,x);maxX=Math.max(maxX,x);minY=Math.min(minY,y);maxY=Math.max(maxY,y);}
 }
 return {count,width:maxX-minX+1,height:maxY-minY+1};
}
(async()=>{
 for(let i=0;i<50;i++){try{if((await fetch('http://127.0.0.1:8068/StreetVicente/')).ok)break;}catch{}await delay(100);}
 browser=await chromium.launch({headless:true,args:['--use-angle=swiftshader','--enable-unsafe-swiftshader']});
 page=await browser.newPage({viewport:{width:1280,height:720}});
 page.on('pageerror',e=>errors.push(String(e)));page.on('console',m=>{if(/SCRIPT ERROR|Parse Error|ERROR:/i.test(m.text()))errors.push(m.text());});
 const state=()=>page.evaluate(()=>window.svfQA);
 const wait=(fn,arg=null)=>page.waitForFunction(fn,arg,{timeout:30000});
 const observe=async(fn,arg=null)=>{const h=await wait(fn,arg);try{return await h.jsonValue();}finally{await h.dispose();}};
 const pause=async()=>{await page.keyboard.press('Escape');await wait(()=>window.svfQA.paused);};
 const resume=async()=>{await page.keyboard.press('Enter');await wait(()=>!window.svfQA.paused);};
 const shot=async name=>{await pause();const b=await page.screenshot({path:'test-results/24-tais-'+name+'.png'});await resume();return b;};
 const select=async id=>{const q=await state();for(let i=0;i<(q.roster_ids.indexOf(id)-q.cursor+13)%13;i++)await page.keyboard.press('ArrowRight');await page.keyboard.press('Enter');};
 const far=async()=>{await page.keyboard.press('F8');await wait(()=>window.svfQA.state==='IDLE');await page.keyboard.down('a');await wait(()=>window.svfQA.x[0]<110*256);await page.keyboard.up('a');};
 const approach=async()=>{await page.keyboard.press('F8');await wait(()=>window.svfQA.state==='IDLE');await page.keyboard.down('d');await wait(()=>window.svfQA.x[1]-window.svfQA.x[0]<180*256);await page.keyboard.up('d');};
 await page.goto('http://127.0.0.1:8068/StreetVicente/?qa=1',{timeout:120000});await wait(()=>window.svfQA?.screen==='menu');
 for(let i=0;i<4;i++)await page.keyboard.press('ArrowDown');await page.keyboard.press('Enter');await wait(()=>window.svfQA.screen==='selection');
 await select('tais');await wait(()=>window.svfQA.slot===1);await select('rafael');await wait(()=>window.svfQA.screen==='stage_selection');
 await page.keyboard.press('Enter');await wait(()=>window.svfQA.screen==='fight'&&window.svfQA.intro_ticks===0);
 let q=await state();assert.deepEqual(q.selected,['tais','rafael']);assert.equal(q.art_face_revision,17);assert.match(q.art_sheet,/tais\/arcade-v17\/states/);
 const height=q.art_height;await shot('guard');await page.keyboard.down('d');
 await wait(()=>window.svfQA.pose==='walk');assert.match((await state()).art_sheet,/tais\/arcade-v17\/walk/);await page.keyboard.up('d');
 await page.keyboard.down('s');await wait(()=>window.svfQA.state==='CROUCH');const low=(await state()).art_height;assert(low<height*.76);
 await page.keyboard.press('f');q=await observe(()=>{const q=window.svfQA;return q.moves[0]==='crouchPunch:1'?q:null;});
 assert.equal(q.pose,'low');assert(q.art_scale<=1);assert(Math.abs(q.art_height-low)<18);await shot('low');await page.keyboard.up('s');await wait(()=>window.svfQA.state==='IDLE');
 const pixels={};
 for(const [key,move,pose,radius] of [['h','special:1','pulse',58],['q','super:1','champion',146]]){
  await far();const baseline=await page.screenshot();await page.keyboard.press(key);
  q=await observe(move=>{const q=window.svfQA;return q.moves[0]===move&&q.projectiles>0?q:null;},move);
  assert.equal(q.pose,pose);assert.equal(q.art_face_revision,17);assert(q.power_positions.every(p=>p.radius===radius&&p.effect==='athleticPulse'));
  await pause();pixels[key]=energyPixels(await page.screenshot({path:'test-results/24-tais-'+pose+'-flight.png'}),baseline);await resume();
  if(key==='q')await wait(()=>window.svfQA.emitted_waves===4);
  await wait(move=>window.svfQA.last_contacts.some(e=>e.character==='tais'&&e.move===move&&e.kind==='hit'),move);
  await pause();await page.screenshot({path:'test-results/24-tais-'+pose+'-impact.png'});q=await state();assert(q.hp[1]<1000);if(key==='q')assert.equal(q.meter[0],0);await resume();
  await wait(()=>window.svfQA.state==='IDLE');
 }
 assert(pixels.q.count>16000,'Super ocupa área expressiva da arena');assert(pixels.q.height>300,'Frente do super tem altura de uma lutadora');
 assert(pixels.q.count>pixels.h.count*1.4,'Super tem presença maior que o Pulso Atlético');
 await approach();await page.keyboard.press('u');
 q=await observe(()=>window.svfQA.trace.find(q=>q.move==='uppercut:1'&&q.pose==='rise'&&q.y<600*256&&q.pose_index>=3));assert.equal(q.art_face_revision,17);
 await wait(()=>window.svfQA.last_contacts.some(e=>e.character==='tais'&&e.move==='uppercut:1'&&e.kind==='hit'));await shot('olympic-rise');
 await wait(()=>window.svfQA.state==='IDLE'&&window.svfQA.y[0]===625*256);
 for(const key of ['h','q']){await far();await page.keyboard.press('F2');await page.keyboard.press(key);await wait(()=>window.svfQA.last_contacts.some(e=>e.character==='tais'&&e.kind==='block'));await wait(()=>window.svfQA.state==='IDLE');}
 await page.keyboard.press('Escape');await page.keyboard.press('Escape');await wait(()=>window.svfQA.screen==='menu');
 await page.keyboard.press('ArrowUp');await page.keyboard.press('Enter');await wait(()=>window.svfQA.screen==='selection');await select('tais');
 await wait(()=>window.svfQA.screen==='story_dialog');await page.keyboard.press('Enter');await wait(()=>window.svfQA.screen==='story');q=await state();assert.equal(q.story.character,'tais');assert.equal(q.story.art_face_revision,17);
 const lane=q.story.ground_y;await page.keyboard.down('w');q=await observe(lane=>{const q=window.svfQA;return q.story.ground_y<lane&&q.story.pose==='walk'?q:null;},lane);
 assert.equal(q.story.y,q.story.ground_y);await shot('story');await page.keyboard.up('w');assert.deepEqual(errors,[]);
 fs.writeFileSync('test-results/tais-v17-smoke.json',JSON.stringify({status:'passed',pixels,checks:['Rosto original, Savate e corpo inteiro v17','Agachamento sem zoom','H: chassé com Pulso Atlético e núcleo ampliado','Q: quatro grandes ondas, rastro e explosão','Super ocupa área grande em pixels reais do render','U: Salto Olímpico fisicamente aéreo','H/Q bloqueáveis e custo original','História: caminhada em profundidade','Console limpo']},null,2));
 console.log('TAIS V17 WEB PASSED: original identity, Savate, large champion fronts, Olympic rise, block, Story',JSON.stringify(pixels));
})().catch(async e=>{console.error(e);if(page&&!page.isClosed()){await page.screenshot({path:'test-results/tais-v17-failure.png'}).catch(()=>{});console.error(JSON.stringify(await page.evaluate(()=>window.svfQA).catch(()=>({}))));}process.exitCode=1;}).finally(async()=>{if(browser)await browser.close();server.kill();});
