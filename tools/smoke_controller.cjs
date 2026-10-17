/* Synthetic browser Gamepad API devices exercise the actual exported Godot input
 * path. This is automated compatibility coverage, not a physical USB certification. */
const {chromium}=require('playwright');const assert=require('node:assert/strict');
const {spawn}=require('node:child_process');const fs=require('node:fs');const path=require('node:path');
process.chdir(path.resolve(__dirname,'..'));fs.mkdirSync('test-results',{recursive:true});
if(!fs.existsSync('build/StreetVicente'))fs.symlinkSync('web','build/StreetVicente');
const delay=ms=>new Promise(r=>setTimeout(r,ms));let browser,page;const errors=[];
const server=spawn('python3',['-m','http.server','8062','--directory','build','--bind','127.0.0.1']);
(async()=>{
 for(let i=0;i<50;i++){try{if((await fetch('http://127.0.0.1:8062/StreetVicente/')).ok)break;}catch{}await delay(100);}
 browser=await chromium.launch({headless:true,args:['--use-angle=swiftshader','--enable-unsafe-swiftshader']});
 page=await browser.newPage({viewport:{width:1280,height:720}});
 page.on('pageerror',e=>errors.push(String(e)));
 page.on('console',m=>{if(/SCRIPT ERROR|Parse Error|ERROR:/i.test(m.text()))errors.push(m.text());});
 await page.addInitScript(()=>{
  const pads=[0,1].map(index=>({index,id:`SVF synthetic USB ${index}`,mapping:'standard',connected:true,timestamp:0,axes:[0,0,0,0],buttons:Array.from({length:17},()=>({pressed:false,touched:false,value:0}))}));
  window.testPads=pads;
  Object.defineProperty(navigator,'getGamepads',{configurable:true,value:()=>pads.map(p=>p.connected?{...p,timestamp:performance.now()}:null)});
 });
 await page.goto('http://127.0.0.1:8062/StreetVicente/?qa=1',{timeout:120000});
 const wait=(fn,arg)=>page.waitForFunction(fn,arg,{timeout:30000});
 const state=()=>page.evaluate(()=>window.svfQA);
 await wait(()=>window.svfQA?.screen==='menu'&&window.svfQA.controller_devices?.filter(d=>d>=0).length===2);
 const button=async(index,down,pad=0)=>page.evaluate(({index,down,pad})=>{window.testPads[pad].buttons[index]={pressed:down,touched:down,value:down?1:0};},{index,down,pad});
 const tap=async(index,pad=0)=>{await button(index,true,pad);await delay(170);await button(index,false,pad);await delay(100);};
 // The selector must show the actual USB, not its keyboard placeholder.
 await page.keyboard.press('F10');await wait(()=>window.svfQA?.controls_open);
 assert.match((await state()).controller_ui.device_label,/USB 0.*SVF synthetic USB 0/);
 assert.equal((await state()).controller_ui.device_id,0);
 // Select keyboard and then the first USB through the real OptionButton popup.
 await page.mouse.click(500,170);await wait(()=>window.svfQA?.controller_ui?.popup_open);
 await page.mouse.click(500,203);
 await wait(()=>window.svfQA?.controller_devices[0]===-1&&!window.svfQA.controller_ui.popup_open);
 assert.equal((await state()).controller_ui.device_label,'Somente teclado');
 await page.mouse.click(500,170);await wait(()=>window.svfQA?.controller_ui?.popup_open);
 await page.mouse.click(500,230);
 await wait(()=>window.svfQA?.controller_devices[0]===0&&!window.svfQA.controller_ui.popup_open);
 assert.match((await state()).controller_ui.device_label,/USB 0.*SVF synthetic USB 0/);
 await page.keyboard.press('Escape');await wait(()=>!window.svfQA?.controls_open);
 // Confirm from the first USB, movement from a non-keyboard input source.
 await tap(0);await wait(()=>window.svfQA?.screen==='fight'&&window.svfQA.intro_ticks===0);
 const x=(await state()).x[0];
 await page.evaluate(()=>{window.testPads[0].axes[0]=0.8;});await delay(250);
 await page.evaluate(()=>{window.testPads[0].axes[0]=0;});
 assert((await state()).x[0]>x+20*256,'Analog USB moves the fighter');
 // Controller panel capture: Soco occupies row2 column3. Swap X with B.
 await page.keyboard.press('F10');await wait(()=>window.svfQA?.controls_open);
 await page.mouse.click(1000,260);await tap(1); // HTML standard B -> Godot B.
 assert.match((await state()).controller_ui.device_label,/SVF synthetic USB 0/);
 await page.screenshot({path:'test-results/18-controller-remap.png'});
 await page.keyboard.press('Escape');await wait(()=>!window.svfQA?.controls_open);
 await page.keyboard.press('F8');await delay(120);await tap(1);
 await wait(()=>window.svfQA?.trace?.some(e=>e.move==='punch:1'));
 await page.keyboard.press('F8');await delay(100);
 await tap(9);await wait(()=>window.svfQA?.paused);
 await tap(9);await wait(()=>window.svfQA?.paused===false);
 // Actual browser reload must restore the saved remap, not only its label.
 await page.reload({timeout:120000});await wait(()=>window.svfQA?.screen==='menu');
 await tap(0);await wait(()=>window.svfQA?.screen==='fight'&&window.svfQA.intro_ticks===0);
 await tap(1);await wait(()=>window.svfQA?.trace?.some(e=>e.move==='punch:1'));
 // Disconnect event neutralizes input and pauses; it cannot leave a walking hold.
 await page.evaluate(()=>{
  const pad=window.testPads[0];pad.connected=false;
  const event=new Event('gamepaddisconnected');Object.defineProperty(event,'gamepad',{value:pad});window.dispatchEvent(event);
 });
 await wait(()=>window.svfQA?.paused&&window.svfQA.controller_devices[0]===-1);
 await page.screenshot({path:'test-results/18a-controller-disconnected.png'});
 assert.deepEqual(errors,[],'Gamepad export without script errors');
 fs.writeFileSync('test-results/controller-smoke.json',JSON.stringify({status:'passed',source:'synthetic browser Gamepad API; no physical USB attached',checks:['two USB devices assigned','actual device name in selector','keyboard/USB switching through UI','USB menu confirmation','analog movement','physical-button capture and conflict swap','remapped attack','Start pause and resume','remap survives browser reload','disconnect clears and pauses']},null,2));
 console.log('CONTROLLER WEB SMOKE PASSED');
})().catch(async error=>{console.error(error);console.error(errors);if(page){await page.screenshot({path:'test-results/controller-failure.png'}).catch(()=>{});console.error(await page.evaluate(()=>window.svfQA).catch(()=>null));}process.exitCode=1;}).finally(async()=>{if(browser)await browser.close();server.kill();});
