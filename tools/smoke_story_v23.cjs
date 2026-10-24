/* Real campaign inputs: earned energy, animated robots, furniture lift and throw. */
const {chromium}=require('playwright'),assert=require('node:assert/strict');
const fs=require('node:fs'),path=require('node:path'),{spawn}=require('node:child_process');
const {chargeStory,fightUntil,release,delay}=require('./story_driver.cjs');
process.chdir(path.resolve(__dirname,'..'));fs.mkdirSync('test-results',{recursive:true});
if(!fs.existsSync('build/StreetVicente'))fs.symlinkSync('web','build/StreetVicente');
const server=spawn('python3',['-m','http.server','8074','--directory','build','--bind','127.0.0.1'],{stdio:'ignore'});
const target=process.env.SVF_STORY_URL||'http://127.0.0.1:8074/StreetVicente/?qa=1';
let browser,page;const errors=[];const report={revision:24,checks:[],errors};
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
async function pickUp(prop){
 // A slow render/keyboard round trip can overshoot a waypoint. Correct
 // from the observed position until inside the real interaction region,
 // including a valid position stopped against the furniture footprint.
 const reach=(await state()).story.prop_sizes[prop.kind][0]/2+48;
 for(let i=0;i<20;i++){
  const q=(await state()).story;
  if(q.carry.kind===prop.kind)return;
  assert(q.hp>0,'Hero remains alive while approaching furniture');
  const dx=prop.x-q.x,dy=prop.lane-q.ground_y;
  if(Math.abs(dx)>=reach*256)await page.keyboard.press(dx>0?'d':'a',{delay:40});
  else if(Math.abs(dy)>40*256)await page.keyboard.press(dy>0?'s':'w',{delay:40});
  else await page.keyboard.press('e');
  await delay(120);
 }
 throw Error('Could not approach and pick up '+prop.kind+' through normal inputs');
}
(async()=>{
 for(let i=0;i<50;i++){try{if((await fetch('http://127.0.0.1:8074/StreetVicente/')).ok)break;}catch{}await delay(100);}
 const net={};if(process.env.SVF_STORY_URL&&(process.env.HTTPS_PROXY||process.env.HTTP_PROXY)){
  const u=new URL(process.env.HTTPS_PROXY||process.env.HTTP_PROXY);net.proxy={server:u.protocol+'//'+u.hostname+':'+u.port};
  if(u.username)net.proxy.username=decodeURIComponent(u.username);if(u.password)net.proxy.password=decodeURIComponent(u.password);
 }
 browser=await chromium.launch({...net,headless:true,args:['--use-angle=swiftshader','--enable-unsafe-swiftshader']});
 page=await browser.newPage({viewport:{width:1280,height:720},ignoreHTTPSErrors:true,
  ...(process.env.SVF_STORY_RECORD?{recordVideo:{dir:'test-results/story-motion',size:{width:1280,height:720}}}:{})});
 page.on('pageerror',e=>errors.push(String(e)));page.on('console',m=>{if(/SCRIPT ERROR|Parse Error|ERROR:/i.test(m.text()))errors.push(m.text());});
 await page.goto(target,{timeout:180000,waitUntil:'domcontentloaded'});await wait(()=>window.svfQA?.screen==='menu');
 for(let i=0;i<3;i++)await page.keyboard.press('ArrowDown');await page.keyboard.press('Enter');await wait(()=>window.svfQA.screen==='selection');
 let q=await state();for(let i=0;i<(q.roster_ids.indexOf('marcelo')-q.cursor+13)%13;i++)await page.keyboard.press('ArrowRight');
 await page.keyboard.press('Enter');await wait(()=>window.svfQA.screen==='story_dialog');await page.keyboard.press('Enter');await wait(()=>window.svfQA.screen==='story');
 q=(await state()).story;assert.equal(q.meter,0);assert.equal(q.presentation_revision,24);assert.equal(q.scene_scale,.8);
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
 await fightUntil(page,q=>q.wave>=2,{timeout:90000,useSuper:false});
 console.log('STORY V23: two waves defeated through normal combat');
 // Clear the third wave's melee machines before inspecting the furniture.
 // Screenshots pause the game, but resuming beside a live melee attacker
 // correctly interrupts a lift/throw. Leave the distant drone alive so the
 // scene stays in this act without changing any simulation state.
 await fightUntil(page,q=>q.wave>=2&&q.enemy_states.every(e=>e.hp<=0||e.kind==='snack'),{timeout:90000,useSuper:false});
 const table=(await state()).story.props.find(p=>p.kind==='table'&&!p.used);
 await walkTo(table.x+((await state()).story.prop_sizes.table[0]/2+24)*256,table.lane+20*256);
 await release(page);await wait(()=>window.svfQA.story.state==='IDLE');await shot('furniture-scale');
 await pickUp(table);
 await wait(()=>window.svfQA.story.carry.kind==='table');
 await shot('table-lift');await wait(()=>window.svfQA.story.pickup_ticks===0);
 assert.equal((await state()).story.carry.kind,'table');await shot('table-held');
 await page.keyboard.press('e');await wait(()=>window.svfQA.story.thrown.some(p=>p.kind==='table'&&!p.landed));
 q=await shot('table-throw');assert.equal(Object.keys(q.story.carry).length,0);
 report.checks.push('Reach a real table, lift, hold and release it during the actual throw phase');
 await fightUntil(page,q=>q.wave>=2,{timeout:90000});
 const chair=(await state()).story.props.find(p=>p.kind==='chair'&&!p.used&&p.lane>570*256);
 // Approach from the open front lane. Turning down beside the chair after
 // a long horizontal input can stop against its real ground footprint.
 await walkTo((await state()).story.x,chair.lane+24*256);
 await walkTo(chair.x+((await state()).story.prop_sizes.chair[0]/2+30)*256,(await state()).story.ground_y);await pickUp(chair);
 await wait(()=>window.svfQA.story.carry.kind==='chair');await wait(()=>window.svfQA.story.pickup_ticks===0);
 await shot('chair-held');await page.keyboard.press('e');await wait(()=>window.svfQA.story.thrown.some(p=>p.kind==='chair'));
 await shot('chair-throw');report.checks.push('Chair uses its own consistent scale, hand grip and flight');
 assert.deepEqual(errors,[]);report.status='passed';
 fs.writeFileSync('test-results/story-v23-smoke.json',JSON.stringify(report,null,2));
 console.log('STORY V23 WEB PASSED:',report.checks.join('; '));
})().catch(async e=>{console.error(e);if(page){console.error(JSON.stringify(await state().catch(()=>({}))));await page.screenshot({path:'test-results/30-story-v23-failure.png'}).catch(()=>{});}console.error('Browser errors',JSON.stringify(errors));process.exitCode=1;})
.finally(async()=>{if(browser)await browser.close();server.kill();});
