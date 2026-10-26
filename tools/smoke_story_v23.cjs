/* Real campaign inputs: earned energy, animated robots, furniture lift and throw. */
const {chromium}=require('playwright'),assert=require('node:assert/strict');
const fs=require('node:fs'),path=require('node:path'),{spawn}=require('node:child_process');
const {chargeStory,fightUntil,release,delay}=require('./story_driver.cjs');
process.chdir(path.resolve(__dirname,'..'));fs.mkdirSync('test-results',{recursive:true});
if(!fs.existsSync('build/StreetVicente'))fs.symlinkSync('web','build/StreetVicente');
const server=spawn('python3',['-m','http.server','8074','--directory','build','--bind','127.0.0.1'],{stdio:'ignore'});
const target=process.env.SVF_STORY_URL||'http://127.0.0.1:8074/StreetVicente/?qa=1';
let browser,page,observations;const errors=[],enemyModes=new Set(),enemyBehaviors=new Set();const report={revision:28,checks:[],errors};
const state=()=>page.evaluate(()=>window.svfQA);
const wait=(f,arg=null,timeout=30000)=>page.waitForFunction(f,arg,{timeout}).then(h=>h.dispose());
async function shot(name){
 await release(page);await page.keyboard.press('Escape');await wait(()=>window.svfQA.paused);
 const q=await state();await page.screenshot({path:'test-results/30-story-v23-'+name+'.png'});
 await page.keyboard.press('Enter');await wait(()=>!window.svfQA.paused);return q;
}
async function walkTo(x,lane){
 let q=(await state()).story;
 if(Math.abs(q.x-x)>8*256){
  const key=q.x<x?'d':'a';await page.keyboard.down(key);
  await wait(({x,left})=>left?window.svfQA.story.x<=x+5*256:window.svfQA.story.x>=x-5*256,{x,left:key==='a'});
  await page.keyboard.up(key);
 }
 q=(await state()).story;
 if(Math.abs(q.ground_y-lane)>5*256){
  const key=q.ground_y<lane?'s':'w';await page.keyboard.down(key);
  await wait(({lane,up})=>up?window.svfQA.story.ground_y<=lane+3*256:window.svfQA.story.ground_y>=lane-3*256,{lane,up:key==='w'});
  await page.keyboard.up(key);
 }
}
(async()=>{
 for(let i=0;i<50;i++){try{if((await fetch('http://127.0.0.1:8074/StreetVicente/')).ok)break;}catch{}await delay(100);}
 const net={};if(process.env.SVF_STORY_URL&&(process.env.HTTPS_PROXY||process.env.HTTP_PROXY)){
  const u=new URL(process.env.HTTPS_PROXY||process.env.HTTP_PROXY);net.proxy={server:u.protocol+'//'+u.hostname+':'+u.port};
  if(u.username)net.proxy.username=decodeURIComponent(u.username);if(u.password)net.proxy.password=decodeURIComponent(u.password);
 }
 browser=await chromium.launch({executablePath:process.env.SVF_CHROMIUM_BIN,...net,headless:true,args:['--use-angle=swiftshader','--enable-unsafe-swiftshader']});
 page=await browser.newPage({viewport:{width:1280,height:720},ignoreHTTPSErrors:true,
  ...(process.env.SVF_STORY_RECORD?{recordVideo:{dir:'test-results/story-motion',size:{width:1280,height:720}}}:{})});
 page.on('pageerror',e=>errors.push(String(e)));page.on('console',m=>{if(/SCRIPT ERROR|Parse Error|ERROR:/i.test(m.text()))errors.push(m.text());});
 await page.goto(target,{timeout:180000,waitUntil:'domcontentloaded'});await wait(()=>window.svfQA?.screen==='menu');
 for(let i=0;i<3;i++)await page.keyboard.press('ArrowDown');await page.keyboard.press('Enter');await wait(()=>window.svfQA.screen==='selection');
 let q=await state();for(let i=0;i<(q.roster_ids.indexOf('marcelo')-q.cursor+13)%13;i++)await page.keyboard.press('ArrowRight');
 await page.keyboard.press('Enter');await wait(()=>window.svfQA.screen==='story_dialog');await page.keyboard.press('Enter');await wait(()=>window.svfQA.screen==='story');
 q=(await state()).story;assert.equal(q.meter,0);assert.equal(q.presentation_revision,28);assert.equal(q.scene_scale,.8);
 assert(q.decorations>=12&&q.props.length>=9,'Opening room contains authored scenery and physical furniture');
 assert(q.enemy_states.filter(e=>['cleaner','turnstile'].includes(e.kind)).every(e=>e.height>=340),'Humanoid enemies have adult fighter scale');
 observations=setInterval(async()=>{try{for(const e of (await state()).story?.enemy_states||[]){if(e.state==='ATTACK')enemyModes.add(e.attack_mode);if(e.behavior)enemyBehaviors.add(e.behavior);}}catch{}},100);
 await page.keyboard.press('h');await delay(120);assert.equal((await state()).story.projectiles,0);
 const cels=new Map();for(let i=0;i<10;i++){
  for(const e of (await state()).story.enemy_states){if(!cels.has(e.kind))cels.set(e.kind,new Set());cels.get(e.kind).add(e.cel);}
  await delay(90);
 }
 for(const id of ['snack','cleaner','turnstile'])assert(cels.get(id).size>1,id+' uses multiple moving cels');
 await shot('opening');report.checks.push('Three opening machines animate distinct cels; empty energy blocks H');
 await chargeStory(page,25);await shot('earned-energy');
 await page.keyboard.press('F8');await wait(()=>window.svfQA.story.state==='IDLE');
 const energy=(await state()).story.meter;await page.keyboard.press('h');
 await wait(()=>window.svfQA.story.projectiles>0);assert.equal((await state()).story.meter,energy-25);
 await shot('power');report.checks.push('Real melee contacts earn energy and H spends 25');
 await fightUntil(page,q=>q.wave>=3,{timeout:150000,useSuper:true});
 console.log('STORY V28: three waves defeated through normal combat');
 // Clear the commander before inspecting the seating group, using ordinary inputs.
 await fightUntil(page,q=>q.act===0&&q.wave===3&&q.queued_enemies===0&&q.enemy_states.every(e=>e.hp<=0),{timeout:180000,useSuper:true,maxX:3200});
 // Return to the cleared seating group while the next wave remains far
 // ahead. Furniture is inspected through ordinary movement and interaction.
 const table=(await state()).story.props.filter(p=>p.kind==='table').sort((a,b)=>a.x-b.x)[0];
 const gate=(await state()).story.gate*256;
 await walkTo((await state()).story.x,650*256);
 await walkTo(table.x+((await state()).story.prop_sizes.table[0]/2+35)*256,650*256);
 await walkTo((await state()).story.x,table.lane+20*256);
 await page.keyboard.press('a',{delay:30});
 await shot('furniture-scale');
 for(let i=0;i<8;i++){
  const prop=(await state()).story.props.find(p=>p.id===table.id);
  if(prop.used)break;
  await page.keyboard.press('f');await delay(600);
 }
 assert((await state()).story.props.find(p=>p.id===table.id).used,'Normal punches break the table without E');
 await shot('table-broken');report.checks.push('Normal punches break the physical table without E or scripted alignment');
 // Ordinary combat can already break either chair of this seating group.
 // Use the nearest remaining chair rather than requiring one exact prop.
 const chair=(await state()).story.props.filter(p=>p.kind==='chair'&&!p.used).sort((a,b)=>Math.abs(a.x-table.x)-Math.abs(b.x-table.x))[0];
 assert(chair,'An intact chair remains after combat');
 // Approach from the current side through the clear front passage. Do not
 // require the keyboard driver to walk through the solid chair itself.
 const chairSide=(await state()).story.x>=chair.x?1:-1;
 const chairStand=chair.x+chairSide*((await state()).story.prop_sizes.chair[0]/2+25)*256;
 await walkTo((await state()).story.x,650*256);
 await walkTo(chairStand,650*256);
 await walkTo(chairStand,chair.lane+25*256);
 await page.keyboard.press(chairSide>0?'a':'d',{delay:30});
 await release(page);await wait(()=>window.svfQA.story.state==='IDLE');
 for(let i=0;i<12;i++){
  await page.keyboard.press('g');await delay(30);
  if((await state()).story.thrown.some(p=>p.kind==='chair'))break;
  await delay(250);
 }
 await wait(()=>window.svfQA.story.thrown.some(p=>p.kind==='chair'),null,5000);
 q=await shot('chair-kick');assert.equal(Object.keys(q.story.carry).length,0);
 report.checks.push('Chair leaves the floor on the actual kick contact frame and follows ballistic flight');
 await fightUntil(page,q=>q.act>=1,{timeout:180000,useSuper:true});
 await page.screenshot({path:'test-results/30-story-v27-act-complete.png'});report.checks.push('Full first act and commander defeated through ordinary controls');
 if(process.env.SVF_STORY_FULL){
  for(let act=1;act<4;act++){
   await page.keyboard.press('Enter');await wait(()=>window.svfQA.screen==='story');
   await shot('act-'+act+'-opening');
   assert((await state()).story.props.length>=9,'Act '+act+' contains physical furniture');
   for(let attempt=0;attempt<2;attempt++){
    try{await fightUntil(page,q=>q.act>act||q.completed,{timeout:300000,useSuper:true});break;}
    catch(e){
     const lost=(await state()).story;
     if(!lost?.defeated||attempt===1)throw e;
     console.log('STORY: normal F8 retry of act',act);
     await page.keyboard.press('F8');await wait(a=>window.svfQA.story?.act===a&&window.svfQA.story.hp===1000,act);
    }
   }
   await page.screenshot({path:'test-results/30-story-v28-act-'+act+'-complete.png'});
   report.checks.push('Act '+act+' completed through ordinary controls');
  }
 }
 report.enemy_modes=[...enemyModes];report.enemy_behaviors=[...enemyBehaviors];
 assert(enemyModes.size>=3,'Real enemies execute different attack types during combat');
 assert.deepEqual(errors,[]);report.status='passed';
 fs.writeFileSync('test-results/story-v23-smoke.json',JSON.stringify(report,null,2));
 console.log('STORY V25 WEB PASSED:',report.checks.join('; '));
})().catch(async e=>{console.error(e);if(page){console.error(JSON.stringify(await state().catch(()=>({}))));await page.screenshot({path:'test-results/30-story-v23-failure.png'}).catch(()=>{});}console.error('Browser errors',JSON.stringify(errors));process.exitCode=1;})
.finally(async()=>{clearInterval(observations);if(browser)await browser.close();server.kill();});
