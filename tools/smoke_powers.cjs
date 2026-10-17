/* Actual keyboard input into the exported WASM. svfQA only observes state. */
const {chromium}=require('playwright');const assert=require('node:assert/strict');
const fs=require('node:fs');const path=require('node:path');const {spawn}=require('node:child_process');
process.chdir(path.resolve(__dirname,'..'));fs.mkdirSync('test-results',{recursive:true});
if(!fs.existsSync('build/StreetVicente'))fs.symlinkSync('web','build/StreetVicente');
const server=spawn('python3',['-m','http.server','8063','--directory','build','--bind','127.0.0.1']);
const delay=ms=>new Promise(r=>setTimeout(r,ms));let browser,page;const errors=[];
(async()=>{
 for(let i=0;i<50;i++){try{if((await fetch('http://127.0.0.1:8063/StreetVicente/')).ok)break;}catch{}await delay(100);}
 browser=await chromium.launch({headless:true,args:['--use-angle=swiftshader','--enable-unsafe-swiftshader']});
 page=await browser.newPage({viewport:{width:1280,height:720}});
 page.on('pageerror',e=>errors.push(String(e)));page.on('console',m=>{if(/SCRIPT ERROR|Parse Error|ERROR:/i.test(m.text()))errors.push(m.text());});
 const state=()=>page.evaluate(()=>window.svfQA);
 const wait=fn=>page.waitForFunction(fn,null,{timeout:25000});
 const fightReady=async()=>{await wait(()=>['fight','stage_selection'].includes(window.svfQA?.screen));if((await state()).screen==='stage_selection'){await page.keyboard.press('Enter');}await wait(()=>window.svfQA?.screen==='fight'&&window.svfQA.intro_ticks===0);};
 const shot=async file=>{await page.keyboard.press('Escape');await wait(()=>window.svfQA.paused);await page.screenshot({path:'test-results/'+file});await page.keyboard.press('Enter');await wait(()=>!window.svfQA.paused);};
 await page.goto('http://127.0.0.1:8063/StreetVicente/?qa=1',{timeout:120000});
 await wait(()=>window.svfQA?.screen==='menu');
 for(let i=0;i<4;i++)await page.keyboard.press('ArrowDown');await page.keyboard.press('Enter');await wait(()=>window.svfQA?.screen==='selection');
 let q=await state();for(let i=0;i<(q.roster_ids.indexOf('joao')-q.cursor+13)%13;i++)await page.keyboard.press('ArrowRight');
 await page.keyboard.press('Enter');await wait(()=>window.svfQA.slot===1);
 q=await state();for(let i=0;i<(q.roster_ids.indexOf('rafael')-q.cursor+13)%13;i++)await page.keyboard.press('ArrowRight');
 await page.keyboard.press('Enter');await fightReady();
 assert.deepEqual((await state()).selected,['joao','rafael']);
 await page.keyboard.press('h');await wait(()=>window.svfQA.moves[0]==='special:1');
 assert.equal((await state()).pose,'punch','H é Super Soco com quadros de soco');assert.equal((await state()).roll.phase,0);
 await wait(()=>window.svfQA.state==='IDLE');
 const start=(await state()).x[0];await page.keyboard.press('q');
 await wait(()=>window.svfQA?.roll?.phase===1);assert.equal((await state()).projectiles,0,'Rolinho não lança projétil no lugar do corpo');
 await shot('18-joao-roll-travel.png');
 await wait(()=>window.svfQA?.roll?.hits===3);q=await state();
 assert(q.last_contacts.some(e=>e.kind==='hit'&&e.effect==='electricRoll'&&e.combo===3),'Três pulsos no mesmo combo elétrico');
 assert(q.x[0]>start+100*256,'João viaja fisicamente até o adversário');
 await shot('18a-joao-roll-combo.png');await wait(()=>window.svfQA.state==='IDLE');
 assert.equal((await state()).y[0],625*256,'Recupera no chão após o rebote');
 await page.keyboard.press('F8');await delay(150);await page.keyboard.press('F2');await page.keyboard.press('q');
 await wait(()=>window.svfQA?.last_contacts?.some(e=>e.kind==='block'&&e.effect==='electricRoll'));
 await shot('18b-joao-roll-block.png');await wait(()=>window.svfQA.state==='IDLE');q=await state();
 assert.equal(q.roll.hits,0,'Defesa impede a sequência elétrica');
 const rebound=q.trace.filter(t=>t.roll_phase===3);assert(rebound.length>=2,'Rebote possui trajetória observável');
 assert(Math.max(...rebound.map(t=>t.x))-Math.min(...rebound.map(t=>t.x))>20*256,'Defesa devolve o corpo para trás');
 // Win a real round with successive close kicks. Q keeps its real meter cost. No health, positions or timers are injected.
 await page.keyboard.press('F8');await delay(150);
 for(let attempt=0;attempt<16&&(await state()).winner<0;attempt++){
  await page.keyboard.down('d');await wait(()=>window.svfQA.x[1]-window.svfQA.x[0]<170*256||window.svfQA.winner>=0);await page.keyboard.up('d');
  await page.keyboard.press('b');await wait(()=>window.svfQA.moves[0]==='kick:2'||window.svfQA.winner>=0);
  await wait(()=>window.svfQA.winner>=0||(window.svfQA.state==='IDLE'&&window.svfQA.states[1]==='IDLE'));
 }
 await wait(()=>window.svfQA.winner===0&&window.svfQA.round_wait>=45&&window.svfQA.round_wait<300);
 q=await state();assert.equal(q.freeze_ticks,0,'Hitstop final drenado no WASM');assert.equal(q.shake,0,'Sem tremedeira residual após K.O.');
 const victoryX=q.x[0];await delay(300);q=await state();assert.equal(q.x[0],victoryX,'Vencedor não desliza nem treme depois do round');assert.equal(q.shake,0);
 await shot('18c-round-end-stable.png');assert.deepEqual(errors,[],'Poderes e fim de round sem erros Web');
 fs.writeFileSync('test-results/powers-v10-smoke.json',JSON.stringify({status:'passed',checks:['Rolinho físico sem projétil','Três contatos no combo elétrico','Rebote e recuperação no acerto','Defesa cancela os choques e provoca recuo','K.O. real com hitstop finito','Fim de round sem vibração ou deslocamento residual','Console Web sem erros']},null,2));
 console.log('POWERS V10 WEB PASSED: roll hit, electric combo, block bounce, KO settlement');
})().catch(async e=>{console.error(e);if(page&&!page.isClosed()){await page.screenshot({path:'test-results/powers-v10-failure.png'}).catch(()=>{});console.error(JSON.stringify(await page.evaluate(()=>window.svfQA).catch(()=>({}))));}process.exitCode=1;}).finally(async()=>{if(browser)await browser.close();server.kill();});
