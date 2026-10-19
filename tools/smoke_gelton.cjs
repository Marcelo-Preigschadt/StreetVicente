/* Real keyboard events in the exported WASM; svfQA is observation only. */
const {chromium}=require('playwright');const assert=require('node:assert/strict');
const fs=require('node:fs');const path=require('node:path');const {spawn}=require('node:child_process');
process.chdir(path.resolve(__dirname,'..'));fs.mkdirSync('test-results',{recursive:true});
if(!fs.existsSync('build/StreetVicente'))fs.symlinkSync('web','build/StreetVicente');
const server=spawn('python3',['-m','http.server','8065','--directory','build','--bind','127.0.0.1']);
const delay=ms=>new Promise(r=>setTimeout(r,ms));let browser,page;const errors=[];
(async()=>{
 for(let i=0;i<50;i++){try{if((await fetch('http://127.0.0.1:8065/StreetVicente/')).ok)break;}catch{}await delay(100);}
 browser=await chromium.launch({headless:true,args:['--use-angle=swiftshader','--enable-unsafe-swiftshader']});
 page=await browser.newPage({viewport:{width:1280,height:720}});
 page.on('pageerror',e=>errors.push(String(e)));page.on('console',m=>{if(/SCRIPT ERROR|Parse Error|ERROR:/i.test(m.text()))errors.push(m.text());});
 const state=()=>page.evaluate(()=>window.svfQA);
 const wait=(fn,arg=null)=>page.waitForFunction(fn,arg,{timeout:30000});
 const observe=async(fn,arg=null)=>{const h=await wait(fn,arg);try{return await h.jsonValue();}finally{await h.dispose();}};
 const shot=async name=>{await page.keyboard.press('Escape');await wait(()=>window.svfQA.paused);await page.screenshot({path:'test-results/'+name});await page.keyboard.press('Enter');await wait(()=>!window.svfQA.paused);};
 await page.goto('http://127.0.0.1:8065/StreetVicente/?qa=1',{timeout:120000});
 await wait(()=>window.svfQA?.screen==='menu');
 for(let i=0;i<4;i++)await page.keyboard.press('ArrowDown');await page.keyboard.press('Enter');await wait(()=>window.svfQA.screen==='selection');
 for(const [slot,id] of [[0,'gelton'],[1,'gustavo']]){
  const q=await state();for(let i=0;i<(q.roster_ids.indexOf(id)-q.cursor+13)%13;i++)await page.keyboard.press('ArrowRight');
  await page.keyboard.press('Enter');await wait(slot=>slot===0?window.svfQA.slot===1:window.svfQA.screen==='stage_selection',slot);
 }
 await page.keyboard.press('Enter');await wait(()=>window.svfQA.screen==='fight'&&window.svfQA.intro_ticks===0);
 assert.deepEqual((await state()).selected,['gelton','gustavo']);
 assert.match((await state()).art_sheet,/gelton\/arcade-v13\/walk/);
 const height=(await state()).art_height;await shot('21-gelton-ginga.png');
 const x=(await state()).x[0];await page.keyboard.down('d');await wait(x=>window.svfQA.x[0]>x+20*256,x);await page.keyboard.up('d');
 assert.match((await state()).art_sheet,/gelton\/arcade-v13\/walk/);
 await page.keyboard.down('s');await wait(()=>window.svfQA.state==='CROUCH');const low=(await state()).art_height;
 assert(low<height*.76);await page.keyboard.press('f');await wait(()=>window.svfQA.moves[0]==='crouchPunch:1');
 let q=await state();assert.equal(q.pose,'low');assert.equal(q.art_source,'low');assert(q.art_scale<=1);assert(Math.abs(q.art_height-low)<18);
 await shot('21-gelton-low.png');await page.keyboard.up('s');await wait(()=>window.svfQA.state==='IDLE');
 for(const [key,move] of [['h','special:1'],['u','uppercut:1'],['q','super:1']]){
  await page.keyboard.press('F8');await wait(()=>window.svfQA.state==='IDLE');await page.keyboard.press(key);
  if(key==='u'){
   // Read physics-rate observations: rendering/protocol latency must not lose
   // the brief airborne cels or the descent while a screenshot is being saved.
   const rise=await observe(()=>window.svfQA.trace.find(q=>q.move==='uppercut:1'&&q.y<600*256&&q.pose==='rise'&&q.pose_index>=3&&q.pose_index<=5));
   assert.match(rise.art_sheet,/gelton\/arcade-v13/);
   await shot('21-gelton-au.png');
   const descent=await observe(()=>window.svfQA.trace.find(q=>q.move==='uppercut:1'&&q.pose==='rise'&&q.pose_index===6));
   assert(descent.art_height>=height*.92,'Aú mantém o porte adulto na descida');
  }else{
   q=await observe(move=>{const q=window.svfQA;return q.moves[0]===move&&q.projectiles>0?q:null;},move);
   assert.match(q.art_sheet,/gelton\/arcade-v13/);assert.equal(q.pose,key==='q'?'wheel':'cast');
   assert(q.power_positions.every(p=>p.effect==='artPaint'));
   await shot(key==='q'?'21-gelton-roda.png':'21-gelton-pincelada.png');
   if(key==='q')await wait(()=>window.svfQA.emitted_waves===5);
   await wait(()=>window.svfQA.last_contacts.some(e=>e.character==='gelton'&&e.kind==='hit'));
  }
  await wait(()=>window.svfQA.state==='IDLE');
 }
 await page.keyboard.press('F8');await wait(()=>window.svfQA.state==='IDLE');await page.keyboard.press('F2');await page.keyboard.press('h');
 await wait(()=>window.svfQA.last_contacts.some(e=>e.character==='gelton'&&e.kind==='block'));
 await shot('21-gelton-paint-block.png');assert.deepEqual(errors,[]);
 fs.writeFileSync('test-results/gelton-v13-smoke.json',JSON.stringify({status:'passed',checks:['Seleção Gelton x Gustavo','Ginga e caminhada novas','Negativa e palmada baixa sem zoom','H: Pincelada Cromática com artPaint','U: aú aéreo e descida sem encolher','Q: bananeira e ondas de tinta','Defesa real do projétil','Console Web limpo']},null,2));
 console.log('GELTON V13 WEB PASSED: capoeira, low scale, palm paint, cartwheel, handstand, block');
})().catch(async e=>{console.error(e);if(page&&!page.isClosed()){await page.screenshot({path:'test-results/gelton-v13-failure.png'}).catch(()=>{});console.error(JSON.stringify(await page.evaluate(()=>window.svfQA).catch(()=>({}))));}process.exitCode=1;}).finally(async()=>{if(browser)await browser.close();server.kill();});
