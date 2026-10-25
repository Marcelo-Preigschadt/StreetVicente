/* A real browser throw: no simulation writes, teleports or injected health. */
const {chromium}=require('playwright');
const assert=require('node:assert/strict');
const {spawn}=require('node:child_process');
const fs=require('node:fs');
const path=require('node:path');
const {release,delay}=require('./story_driver.cjs');
process.chdir(path.resolve(__dirname,'..'));
fs.mkdirSync('test-results',{recursive:true});
if(!fs.existsSync('build/StreetVicente'))fs.symlinkSync('web','build/StreetVicente');
const server=spawn('python3',['-m','http.server','8075','--directory','build','--bind','127.0.0.1'],{stdio:'ignore'});
let browser,page;const errors=[];
const state=()=>page.evaluate(()=>window.svfQA);
const wait=(fn,arg=null,timeout=15000)=>page.waitForFunction(fn,arg,{timeout}).then(h=>h.dispose());
(async()=>{
 browser=await chromium.launch({executablePath:process.env.SVF_CHROMIUM_BIN,headless:true,
  args:['--use-angle=swiftshader','--enable-unsafe-swiftshader']});
 page=await browser.newPage({viewport:{width:1280,height:720}});
 page.on('pageerror',e=>errors.push(String(e)));
 page.on('console',m=>{if(/SCRIPT ERROR|Parse Error|ERROR:/i.test(m.text()))errors.push(m.text());});
 await page.goto('http://127.0.0.1:8075/StreetVicente/?qa=1',{waitUntil:'domcontentloaded',timeout:180000});
 await wait(()=>window.svfQA?.screen==='menu',null,60000);
 for(let i=0;i<3;i++)await page.keyboard.press('ArrowDown');
 await page.keyboard.press('Enter');await wait(()=>window.svfQA.screen==='selection');
 let q=await state();
 for(let i=0,n=(q.roster_ids.indexOf('marcos')-q.cursor+q.roster_ids.length)%q.roster_ids.length;i<n;i++)await page.keyboard.press('ArrowRight');
 await page.keyboard.press('Enter');await wait(()=>window.svfQA.screen==='story_dialog');
 await page.keyboard.press('Enter');await wait(()=>window.svfQA.screen==='story');
 let grabbed=null;const deadline=Date.now()+35000;
 while(Date.now()<deadline){
  q=(await state()).story;
  assert(q.hp>0,'Hero survives the approach through ordinary input');
  if(q.campaign_combo.grab_target>=0){grabbed=q;break;}
  const target=q.enemy_states.filter(e=>e.hp>0&&e.y===e.lane&&!['KNOCKDOWN','WAKEUP','KO'].includes(e.state))
   .sort((a,b)=>Math.abs(a.x-q.x)+Math.abs(a.lane-q.ground_y)-Math.abs(b.x-q.x)-Math.abs(b.lane-q.ground_y))[0];
  if(!target){await delay(40);continue;}
  const dx=target.x-q.x,dz=target.lane-q.ground_y,keys=[];
  if(Math.abs(dx)>108*256)keys.push(dx>0?'d':'a');
  if(Math.abs(dz)>12*256)keys.push(dz>0?'s':'w');
  for(const key of ['a','d','w','s','r'])await page.keyboard[keys.includes(key)?'down':'up'](key);
  if(Math.abs(dx)<115*256&&Math.abs(dz)<22*256&&['IDLE','WALK','CROUCH'].includes(q.state)){
   await release(page);await page.keyboard.press('e');await delay(20);
  }else await delay(45);
 }
 assert(grabbed,'E links a grounded enemy using normal browser input');
 assert.equal(grabbed.move,'throw:1');
 const victim=grabbed.enemy_states.find(e=>e.id===grabbed.campaign_combo.grab_target);
 assert(victim,'Linked victim is a real campaign entity');
 assert(Math.abs(victim.x-grabbed.x)<=88*256,'Linked actors remain at physical grab range');
 await release(page);
 await wait(({id,hp})=>window.svfQA.story.enemy_states.some(e=>e.id===id&&e.hp<hp&&e.y<e.lane-25*256),{id:victim.id,hp:victim.hp});
 await page.keyboard.press('Escape');await wait(()=>window.svfQA.paused);
 const after=(await state()).story;
 assert.equal(after.presentation_revision,27);
 assert(after.enemy_states.find(e=>e.id===victim.id).hp<victim.hp,'Release delivers damage to the linked victim');
 await page.screenshot({path:'test-results/31-story-v26-throw.png'});
 assert.deepEqual(errors,[]);
 fs.writeFileSync('test-results/story-v26-smoke.json',JSON.stringify({status:'passed',revision:27,
  checks:['Real keyboard approach','E links a grounded enemy','Authored release frame damages and tosses the victim','No browser script errors'],errors},null,2));
 console.log('STORY V26 WEB PASSED: real approach, grab link, release, airborne victim');
})().catch(async e=>{console.error(e);if(page){console.error(JSON.stringify(await state().catch(()=>({}))));await page.screenshot({path:'test-results/31-story-v26-failure.png'}).catch(()=>{});}process.exitCode=1;})
.finally(async()=>{if(browser)await browser.close();server.kill();});
