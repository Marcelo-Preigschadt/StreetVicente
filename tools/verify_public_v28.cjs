const {chromium}=require('playwright');
const assert=require('node:assert/strict'),fs=require('node:fs');
const base='https://marcelo-preigschadt.github.io/StreetVicente/';
const expected={commit:'1a18656735798cc4d0a995bfb393528fa271e322',pack:'index-67c069d27bd4.pck'};
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
(async()=>{let browser;try{
 fs.mkdirSync('test-results/public-v28',{recursive:true});
 let build;
 for(let i=0;i<20;i++){
  const response=await fetch(base+'build.json?verify='+Date.now(),{cache:'no-store'});
  if(response.ok){build=await response.json();if(build.commit===expected.commit)break;}
  await sleep(3000);
 }
 assert.equal(build?.presentation_revision,28);
 assert.equal(build.commit,expected.commit);assert.equal(build.pack,expected.pack);
 browser=await chromium.launch({headless:true,args:['--use-angle=swiftshader','--enable-unsafe-swiftshader']});
 const page=await browser.newPage({viewport:{width:1280,height:720}});
 const errors=[],packs=[];
 page.on('pageerror',e=>errors.push(String(e)));
 page.on('console',m=>{if(/SCRIPT ERROR|Parse Error|ERROR:/i.test(m.text()))errors.push(m.text());});
 page.on('response',r=>{if(r.url().includes(expected.pack))packs.push({url:r.url(),status:r.status()});});
 await page.goto(base+'?qa=1&v=28&build=1a18656',{waitUntil:'domcontentloaded',timeout:240000});
 const wait=fn=>page.waitForFunction(fn,null,{timeout:240000});
 await wait(()=>window.svfQA?.screen==='menu');
 for(let i=0;i<3;i++)await page.keyboard.press('ArrowDown');
 await page.keyboard.press('Enter');await wait(()=>window.svfQA.screen==='selection');
 let q=await page.evaluate(()=>window.svfQA);assert.equal(q.roster_ids.length,13);
 for(let i=0;i<(q.roster_ids.indexOf('marcelo')-q.cursor+13)%13;i++)await page.keyboard.press('ArrowRight');
 await page.keyboard.press('Enter');await wait(()=>window.svfQA.screen==='story_dialog');
 await page.keyboard.press('Enter');await wait(()=>window.svfQA.screen==='story');
 q=await page.evaluate(()=>window.svfQA.story);
 assert.equal(q.presentation_revision,28);assert(q.decorations>=12&&q.props.length>=9);
 assert(q.enemy_states.filter(e=>['cleaner','turnstile'].includes(e.kind)).every(e=>e.height>=340));
 assert(packs.some(p=>p.status===200));assert.deepEqual(errors,[]);
 await page.keyboard.press('Escape');await wait(()=>window.svfQA.paused);
 const preview=await page.screenshot({type:'jpeg',quality:45,path:'test-results/public-v28/preview.jpg'});
 const report={status:'passed',build,packs,props:q.props.length,decorations:q.decorations,enemies:q.enemy_states.map(e=>({kind:e.kind,height:e.height})),errors};
 fs.writeFileSync('test-results/public-v28/report.json',JSON.stringify(report,null,2));
 console.log('PUBLIC_CHECK_PASSED:'+JSON.stringify(report));
 const b64=preview.toString('base64');
 for(let i=0;i<b64.length;i+=8000)console.log('PUBLIC_PREVIEW_CHUNK:'+b64.slice(i,i+8000));
}finally{if(browser)await browser.close();}})().catch(e=>{console.error(e);process.exitCode=1;});
