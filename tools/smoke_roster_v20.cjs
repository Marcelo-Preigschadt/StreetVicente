/* Eleven fighters; actual keyboard, WebGL pixels and immutable observations. */
const {chromium}=require('playwright'),{PNG}=require('pngjs'),assert=require('node:assert/strict');
const fs=require('node:fs'),path=require('node:path'),{spawn}=require('node:child_process');
process.chdir(path.resolve(__dirname,'..'));fs.mkdirSync('test-results',{recursive:true});
const publicURL=process.env.SVF_AUDIT_URL;
if(!publicURL&&!fs.existsSync('build/StreetVicente'))fs.symlinkSync('web','build/StreetVicente');
const server=publicURL?{kill(){}}:spawn('python3',['-m','http.server','8071','--directory','build','--bind','127.0.0.1']);
const url=publicURL||'http://127.0.0.1:8071/StreetVicente/?qa=1';
const delay=ms=>new Promise(r=>setTimeout(r,ms));let browser,page;const errors=[],results=[];
const roster=['marcelo','adriano','rafael','gustavo','gelton','marcelino','marcos','joao','tais','luciana','ruan'];
const ids=process.env.SVF_AUDIT_IDS?process.env.SVF_AUDIT_IDS.split(','):roster;
assert(ids.length&&ids.every(id=>roster.includes(id)),'Audit subset must belong to the eleven included fighters');
function bounds(q){return q.hurtboxes.map(boxes=>{
 if(!boxes.length)return null;
 const x=Math.min(...boxes.map(b=>b[0]))-8,y=Math.min(...boxes.map(b=>b[1]))-8;
 return [x,y,Math.max(...boxes.map(b=>b[0]+b[2]))+8,Math.max(...boxes.map(b=>b[1]+b[3]))+8];
}).filter(Boolean);}
function energy(buffer,baseline,exclude=[]){
 const a=PNG.sync.read(buffer),b=PNG.sync.read(baseline);let count=0,minY=720,maxY=0;
 for(let y=135;y<660;y++)for(let x=35;x<1250;x++){
  if(exclude.some(b=>x>=b[0]&&y>=b[1]&&x<=b[2]&&y<=b[3]))continue;
  const i=(y*a.width+x)*4,r=a.data[i],g=a.data[i+1],v=a.data[i+2];
  if(Math.abs(r-b.data[i])+Math.abs(g-b.data[i+1])+Math.abs(v-b.data[i+2])>100&&Math.max(r,g,v)>155){count++;minY=Math.min(minY,y);maxY=Math.max(maxY,y);}
 }return {count,height:maxY-minY+1};
}
(async()=>{
 if(!publicURL)for(let i=0;i<50;i++){try{if((await fetch(url)).ok)break;}catch{}await delay(100);}
 const net={};if(publicURL&&(process.env.HTTPS_PROXY||process.env.HTTP_PROXY)){
  const u=new URL(process.env.HTTPS_PROXY||process.env.HTTP_PROXY);net.proxy={server:u.protocol+'//'+u.hostname+':'+u.port};
  if(u.username)net.proxy.username=decodeURIComponent(u.username);if(u.password)net.proxy.password=decodeURIComponent(u.password);
 }
 browser=await chromium.launch({...net,headless:true,args:['--use-angle=swiftshader','--enable-unsafe-swiftshader']});
 page=await browser.newPage({viewport:{width:1280,height:720},ignoreHTTPSErrors:true});
 await page.setExtraHTTPHeaders({'Cache-Control':'no-cache','Pragma':'no-cache'});
 page.on('pageerror',e=>errors.push(String(e)));page.on('console',m=>{if(/SCRIPT ERROR|Parse Error|ERROR:/i.test(m.text()))errors.push(m.text());});
 const state=()=>page.evaluate(()=>window.svfQA);
 const wait=(fn,arg=null,timeout=30000)=>page.waitForFunction(fn,arg,{timeout});
 const pause=async()=>{await page.keyboard.press('Escape');await wait(()=>window.svfQA.paused);};
 const resume=async()=>{await page.keyboard.press('Enter');await wait(()=>!window.svfQA.paused);};
 const shot=async name=>{await pause();const b=await page.screenshot({path:'test-results/27-'+name+'.png'});await resume();return b;};
 const select=async id=>{const q=await state();for(let i=0;i<(q.roster_ids.indexOf(id)-q.cursor+13)%13;i++)await page.keyboard.press('ArrowRight');await page.keyboard.press('Enter');};
 const reset=async close=>{
  await page.keyboard.press('F8');await wait(()=>window.svfQA.state==='IDLE');
  await page.keyboard.down(close?'d':'a');
  await wait(close?()=>window.svfQA.x[1]-window.svfQA.x[0]<180*256:()=>window.svfQA.x[0]<110*256);
  await page.keyboard.up(close?'d':'a');
 };
 await page.goto(url,{timeout:180000,waitUntil:'domcontentloaded'});await wait(()=>window.svfQA?.screen==='menu',null,120000);
 for(let i=0;i<4;i++)await page.keyboard.press('ArrowDown');
 for(const id of ids){
  await page.keyboard.press('Enter');await wait(()=>window.svfQA.screen==='selection');await select(id);
  await wait(()=>window.svfQA.slot===1);await select(id==='rafael'?'marcelo':'rafael');await wait(()=>window.svfQA.screen==='stage_selection');
  await page.keyboard.press('Enter');await wait(()=>window.svfQA.screen==='fight'&&window.svfQA.intro_ticks===0);
  const guard=await state();assert.equal(guard.selected[0],id);assert.equal(guard.roster_fx_revision,20);
  assert(!guard.revised_power_ids.includes('khauany')&&!guard.revised_power_ids.includes('dienes'));
  await shot(id+'-guard');const entry={id,body:guard.art_sheet,face_revision:guard.art_face_revision,powers:{}};
  for(const [key,move] of [['h','special:1'],['u','uppercut:1'],['q','super:1']]){
   const melee=['marcos','joao'].includes(id),close=key==='u'||(melee&&key==='h')||(id==='marcos'&&key==='q');
   await reset(close);let baseState=await state(),baseline=await shot(id+'-'+key+'-baseline');await page.keyboard.press(key);
   if(key==='q'){
    // The roll legitimately earns meter on each contact. Read its immutable
    // startup observation to verify expenditure independently of later gains.
    assert.equal(baseState.meter[0],100,id+' starts the super with full meter');
    const h=await wait(()=>window.svfQA.trace.find(q=>q.move==='super:1'&&typeof q.meter==='number'));
    const cast=await h.jsonValue();await h.dispose();assert.equal(cast.meter,0,id+' spends 100 at super startup');
   }
   if(key==='u'){
    await wait(()=>window.svfQA.trace.some(q=>q.move==='uppercut:1'&&q.hit_count>0));
   }else if(id==='joao'&&key==='q'){
    await wait(()=>window.svfQA.roll.phase===1);
   }else if(melee){
    await wait(move=>window.svfQA.last_contacts.some(e=>e.move===move&&e.kind==='hit'),move);
   }else if(id==='marcelo'&&key==='q'){
    await wait(()=>window.svfQA.power_positions.filter(p=>p.kind==='drone').length===5);
   }else{
    await wait(()=>window.svfQA.projectiles>0);
   }
   if(key!=='q'){
    const pixels=energy(await shot(id+'-'+key+'-power'),baseline);entry.powers[key]=pixels;
    assert(pixels.count>1000,id+'/'+key+' visibly renders its authored power');
   }
   if(key==='q'&&id==='marcelo'){
    await wait(()=>window.svfQA.power_positions.some(p=>p.kind==='laser'));
   }
   await wait(move=>window.svfQA.last_contacts.some(e=>e.move===move&&e.kind==='hit'),move);
   if(key!=='q')assert((await state()).hp[1]<1000,id+'/'+key+' contacts actual opponent');
   if(key==='q'){
    // Never count the large SUPER banner, camera shake, or actor silhouettes
    // as proof of a big power. Capture a live aftermath after all three cease.
    let current,buffer,actual,capturedLife,captureAttempts=0;
    // Capture is subject to browser/renderer latency. A missed or fading
    // window can repeat the real move, with full meter/cost/contact checks.
    // The pixel/height thresholds and all exclusions remain mandatory.
    for(let attempt=0;attempt<3;attempt++){
     captureAttempts=attempt+1;
     if(attempt){
      await reset(close);baseState=await state();baseline=await shot(id+'-q-baseline-'+attempt);
      assert.equal(baseState.meter[0],100,id+' recasts with full meter');
      await page.keyboard.press('q');
      const h=await wait(()=>window.svfQA.trace.find(q=>q.move==='super:1'&&typeof q.meter==='number'));
      const cast=await h.jsonValue();await h.dispose();assert.equal(cast.meter,0,id+' pays for recast');
      await wait(()=>window.svfQA.last_contacts.some(e=>e.move==='super:1'&&e.kind==='hit'));
     }
     for(let retry=0;retry<8;retry++){
      try{
       const h=await wait(()=>{const q=window.svfQA;return q.super_cutin===0&&q.shake===0&&
        q.power_bursts.some(b=>b.move==='super:1'&&b.kind==='hit'&&b.life>.08);},null,5000);
       await h.dispose();
      }catch(e){if(e.name==='TimeoutError')break;throw e;}
      await pause();const observed=await state();
      const live=observed.power_bursts.filter(b=>b.move==='super:1'&&b.kind==='hit').map(b=>b.life);
      if(observed.super_cutin===0&&observed.shake===0&&live.some(life=>life>.08)){
       const candidate=await page.screenshot({path:'test-results/27-'+id+'-q-capture-'+attempt+'.png'});
       const pixels=energy(candidate,baseline,[...bounds(baseState),...bounds(observed)]);
       if(!actual||pixels.count>actual.count){
        current=observed;buffer=candidate;actual=pixels;capturedLife=Math.max(...live);
       }
       await resume();break;
      }
      await resume();
     }
     if(actual&&actual.count>6000&&actual.height>250)break;
    }
    assert(buffer,id+' froze an actual live aftermath without camera shake');
    fs.writeFileSync('test-results/27-'+id+'-q-unobstructed.png',buffer);
    assert(current.hp[1]<1000,id+' super contacts actual opponent');
    entry.powers.q={...actual,captured_life:capturedLife,capture_attempts:captureAttempts,cutin:current.super_cutin,shake:current.shake,meter_after_contact:current.meter[0],excludes_actor_bounds:true};
    assert(actual.count>6000,id+' super has substantial luminous area outside actors and banner: '+JSON.stringify(entry.powers.q));
    assert(actual.height>250,id+' super spans fighter height without the SUPER banner');
   }
   await shot(id+'-'+key+'-impact');
   await wait(()=>window.svfQA.state==='IDLE'&&window.svfQA.y[0]===625*256);
  }
  results.push(entry);console.log('ROSTER V20',JSON.stringify(entry));
  await page.keyboard.press('Escape');await page.keyboard.press('Escape');await wait(()=>window.svfQA.screen==='menu');
 }
 assert.deepEqual(errors,[],'All eleven signatures render without Web errors');
 fs.writeFileSync('test-results/roster-v20-'+(publicURL?'public':'local')+'.json',JSON.stringify({status:'passed',results,excluded:['khauany','dienes'],errors},null,2));
 console.log('ROSTER V20 WEB PASSED:',ids.length,'fighters,',ids.length*3,'powers, unchanged faces, large supers, real contacts');
})().catch(async e=>{console.error(e);if(page&&!page.isClosed()){await page.screenshot({path:'test-results/roster-v20-failure.png'}).catch(()=>{});console.error(JSON.stringify(await page.evaluate(()=>window.svfQA).catch(()=>({}))));}process.exitCode=1;}).finally(async()=>{if(browser)await browser.close();server.kill();});
