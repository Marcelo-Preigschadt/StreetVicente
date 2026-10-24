/* Two independent WASM clients, real Supabase relay, normal UI input only. */
const { chromium } = require('playwright');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { spawn } = require('node:child_process');
process.chdir(path.resolve(__dirname, '..'));
fs.mkdirSync('test-results', {recursive:true});
if (!fs.existsSync('build/StreetVicente')) fs.symlinkSync('web','build/StreetVicente');
const server = spawn('python3',['-m','http.server','8073','--directory','build','--bind','127.0.0.1'],{stdio:'ignore'});
const delay = ms => new Promise(r => setTimeout(r,ms));
let browser; const clients = []; const errors = []; const checks = [];
const progress = setInterval(async()=>{for(const c of clients){try{const q=await state(c);console.log('STATE',c.name,q.screen,q.online.phase,q.online.status,q.online.tick);}catch{}}},15000);
const target = process.env.SVF_ONLINE_URL || 'http://127.0.0.1:8073/StreetVicente/?qa=1';
const proxyValue = process.env.HTTPS_PROXY || process.env.HTTP_PROXY;
const network = {};
if (proxyValue) {
 const u = new URL(proxyValue); network.proxy = {server:u.protocol+'//'+u.hostname+':'+u.port,bypass:'127.0.0.1,localhost'};
 if(u.username) network.proxy.username=decodeURIComponent(u.username);
 if(u.password) network.proxy.password=decodeURIComponent(u.password);
}
async function client(name) {
 const context=await browser.newContext({viewport:{width:1280,height:720},ignoreHTTPSErrors:true});
 const page=await context.newPage(); const c={name,page,context};clients.push(c);console.log('ONLINE: loading',name);
 page.on('pageerror',e=>errors.push(name+': '+e));
 page.on('response',r=>{if(r.url().includes('/rest/v1/') && r.status()>=400)console.log('HTTP',name,r.status());});
 page.on('console',m=>{if(c.expectedOffline && /^TypeError: Failed to fetch/.test(m.text()))return; if(/SCRIPT ERROR|Parse Error|ERROR:/i.test(m.text())){if(errors.length<4)console.log('CONSOLE',name,m.text());errors.push(name+': '+m.text());}});
 await page.setExtraHTTPHeaders({'Cache-Control':'no-cache','Pragma':'no-cache'});
 await page.goto(target,{waitUntil:'domcontentloaded',timeout:180000});
 await page.waitForFunction(()=>window.svfQA?.screen==='menu',null,{timeout:180000});
 console.log('ONLINE: ready',name); return c;
}
const state = c => c.page.evaluate(()=>window.svfQA);
const wait = (c,fn,arg=null,timeout=45000) => c.page.waitForFunction(fn,arg,{timeout}).then(h=>h.dispose());
async function menu(c,mode='versus') {
 await c.page.mouse.click(300,588);await wait(c,()=>window.svfQA.screen==='online');
 if(mode==='story')await c.page.mouse.click(875,156);
}
async function join(c,code) {
 await c.page.mouse.click(240,417);await c.page.keyboard.press('ControlOrMeta+A');await c.page.keyboard.type(code,{delay:40});await c.page.keyboard.press('Enter');
 await wait(c,()=>window.svfQA.screen==='selection');
}
async function choose(c,id) {
 const q=await state(c);const n=q.roster_ids.length;
 for(let i=0;i<n && (await state(c)).roster_ids[(await state(c)).cursor]!==id;i++) {await c.page.keyboard.press('ArrowRight');await delay(110);}
 await wait(c,id=>window.svfQA.online.pair[window.svfQA.online.slot]===id,id);
 await c.page.keyboard.press('Enter');
}
async function playing(a,b,screen='fight') {
 for(const c of [a,b])await wait(c,screen=>window.svfQA.screen===screen&&window.svfQA.online.phase==='playing',screen,90000);
}
async function equalCheckpoint(a,b) {
 const deadline=Date.now()+40000;
 while(Date.now()<deadline){
  const [x,y]=await Promise.all([state(a),state(b)]);
  if(x.online.hash_tick>0&&x.online.hash_tick===y.online.hash_tick&&x.online.confirmed_hash===y.online.confirmed_hash)return x.online.hash_tick;
  await delay(100);
 }
 throw Error('Confirmed checkpoint hashes did not agree');
}
async function leave(c) {
 const q=await state(c);
 if(q.screen==='menu')return;
 if(q.screen==='selection'||q.screen==='online')await c.page.keyboard.press('Escape');
 else {
  if(q.online.phase!=='paused') {
   await c.page.keyboard.press('Escape');
   // A resync can begin after the observation: Escape then closes the
   // session directly. The menu is already the intended terminal state.
   await wait(c,()=>window.svfQA.online.phase==='paused'||window.svfQA.screen==='menu');
   if((await state(c)).screen==='menu')return;
  }
  await c.page.keyboard.press('Escape');
 }
 await wait(c,()=>window.svfQA.screen==='menu');
}
async function pause(a,b){
 await a.page.keyboard.press('Escape');
 for(const c of [a,b])await wait(c,()=>window.svfQA.online.phase==='paused');
 const before=await state(a);await delay(400);assert.equal((await state(a)).online.tick,before.online.tick);
}
async function reloadResume(c,other) {
 const room=(await state(c)).online.room;
 await delay(2200);await c.page.reload({waitUntil:'domcontentloaded',timeout:180000});
 await wait(c,()=>window.svfQA?.screen==='menu',null,180000);
 await menu(c);await c.page.mouse.click(654,661);
 await playing(c,other,(await state(other)).screen);
 assert.equal((await state(c)).online.room,room);
 await equalCheckpoint(c,other);
}
(async()=>{
 for(let i=0;i<60;i++){try{if((await fetch('http://127.0.0.1:8073/StreetVicente/')).ok)break;}catch{}await delay(100);}
 browser=await chromium.launch({...network,headless:true,args:['--use-angle=swiftshader','--enable-unsafe-swiftshader','--disable-background-timer-throttling','--disable-renderer-backgrounding','--disable-backgrounding-occluded-windows']});
 const host=await client('host');const guest=await client('guest');await menu(host);
 await host.page.screenshot({path:'test-results/29-online-directory.png'});
 await host.page.mouse.click(235,325);
 await wait(host,()=>window.svfQA.online.phase==='lobby',null,60000);
 const code=(await state(host)).online.room;assert.match(code,/^[A-HJ-NP-Z2-9]{8}$/);
 console.log('ONLINE: host room created',code);
 await menu(guest);await join(guest,code);
 assert.equal((await state(guest)).online.slot,1);
 await choose(host,'khauany');await choose(guest,'tais');
 await playing(host,guest);console.log('ONLINE: versus started');
 for(const c of [host,guest])await wait(c,()=>window.svfQA.intro_ticks===0);
 assert.deepEqual((await state(host)).selected,['khauany','tais']);
 const old=(await state(guest)).x[1];await guest.page.keyboard.down('d');
 await wait(guest,old=>window.svfQA.x[1]>old+30*256,old);await guest.page.keyboard.up('d');
 await equalCheckpoint(host,guest);checks.push('Independent players, confirmed deterministic states');
 await pause(host,guest);await host.page.screenshot({path:'test-results/29-online-versus-paused.png'});
 await guest.page.keyboard.press('Enter');await playing(host,guest);
 checks.push('Synchronized pause and resume from either player');
 guest.expectedOffline=true;await guest.context.setOffline(true);await delay(3500);
 const stalled=await state(host);assert(['reconnecting','syncing'].includes(stalled.online.phase)||stalled.online.stalled);
 await guest.context.setOffline(false);await playing(host,guest);await equalCheckpoint(host,guest);guest.expectedOffline=false;
 console.log('ONLINE: disconnect recovered');checks.push('Disconnect freezes bounded prediction and recovers same match');
 await reloadResume(guest,host);console.log('ONLINE: guest refresh recovered');
 await reloadResume(host,guest);console.log('ONLINE: host refresh recovered');
 checks.push('Both guest and host browser refresh can resume their seat');
 // Check actual powers through the peer, without training helpers or state setters.
 await host.page.keyboard.press('h');
 await wait(guest,()=>window.svfQA.projectiles>0||window.svfQA.power_bursts.length>0);
 await host.page.screenshot({path:'test-results/29-online-versus-power.png'});
 await equalCheckpoint(host,guest);checks.push('Real special move transmitted to peer');
 const finishDeadline=Date.now()+120000;
 while(Date.now()<finishDeadline && !(await state(host)).match_over){
  const q=await state(host);
  if(q.winner<0 && q.intro_ticks===0 && q.state==='IDLE')await host.page.keyboard.press('h');
  await delay(650);
 }
 assert((await state(host)).match_over,'Two rounds ended through real attacks');
 const terminalTick=(await state(host)).tick;
 for(const c of [host,guest])await wait(c,t=>window.svfQA.match_over&&window.svfQA.online.confirmed>=t,terminalTick);
 await equalCheckpoint(host,guest);
 await host.page.keyboard.press('Enter');await guest.page.keyboard.press('Enter');
 for(const c of [host,guest])await wait(c,()=>window.svfQA.screen==='selection');
 checks.push('Two genuine KOs, both confirm return to character selection');
 await leave(guest);await wait(host,()=>window.svfQA.screen==='selection');
 await leave(host);console.log('ONLINE: versus cleaned');
 await menu(host,'story');await host.page.mouse.click(235,325);
 await wait(host,()=>window.svfQA.online.phase==='lobby',null,60000);
 const coop=(await state(host)).online.room;assert.equal((await state(host)).online.mode,'story');
 await menu(guest,'story');await join(guest,coop);
 await choose(host,'marcelo');await choose(guest,'khauany');
 await playing(host,guest,'story');console.log('ONLINE: co-op started');
 for(const c of [host,guest])await wait(c,()=>window.svfQA.story?.players?.length===2);
 const before=(await state(guest)).story.players[1].x;
 await guest.page.keyboard.down('d');await wait(guest,x=>window.svfQA.story.players[1].x>x+30*256,before);await guest.page.keyboard.up('d');
 await equalCheckpoint(host,guest);await pause(host,guest);
 await host.page.screenshot({path:'test-results/29-online-coop.png'});
 await host.page.keyboard.press('Enter');await playing(host,guest,'story');
 checks.push('Co-op shared world, two independent heroes and state agreement');
 await leave(guest);await wait(host,()=>window.svfQA.screen==='selection');await leave(host);
 assert.deepEqual(errors,[]);
 fs.writeFileSync('test-results/online-v22-smoke.json',JSON.stringify({status:'passed',checks,errors},null,2));
 console.log('ONLINE V22 WEB PASSED:',checks.join('; '));
})().catch(async e=>{
 console.error(e);
 for(const c of clients){if(!c.page.isClosed()){
  await c.page.screenshot({path:'test-results/online-v22-failure-'+c.name+'.png'}).catch(()=>{});
  const q=await state(c).catch(()=>({}));console.error(c.name,JSON.stringify({screen:q.screen,online:q.online,story:q.story,selected:q.selected}));
 }}
 console.error('Browser errors',JSON.stringify([...new Set(errors)]));process.exitCode=1;
}).finally(async()=>{clearInterval(progress);if(browser)await browser.close();server.kill();});
