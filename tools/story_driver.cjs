/* Play the campaign through its public keyboard and read-only observations. */
const assert=require('node:assert/strict');
const delay=ms=>new Promise(r=>setTimeout(r,ms));
async function release(page){for(const key of ['a','d','w','s','r'])await page.keyboard.up(key);}
async function fightUntil(page,done,{timeout=60000}={}){
 const deadline=Date.now()+timeout;let strike=0,jump=0;
 try{
  while(Date.now()<deadline){
   const q=await page.evaluate(()=>window.svfQA.story);assert(q,'Campaign observation exists');
   if(done(q))return q;
   assert(q.hp>0,'Campaign hero stays alive while earning energy');
   const live=q.enemy_states.filter(e=>e.hp>0);
   const ground=live.filter(e=>!['snack','book','archaeologist'].includes(e.kind));
   if(!ground.length&&live.length&&q.meter>=100){
    await release(page);
    await page.waitForFunction(()=>window.svfQA.story.state==='IDLE',null,{timeout:4000});
    await page.keyboard.press('q');await delay(500);continue;
   }
   const target=(ground.length?ground:live).sort((a,b)=>Math.abs(a.x-q.x)-Math.abs(b.x-q.x))[0];
   const desired=[];
   if(target){
    const dx=target.x-q.x,dy=target.lane-q.ground_y;
    if(Math.abs(dx)>(ground.length?105:135)*256)desired.push(dx>0?'d':'a');
    const lane=625*256-q.ground_y;if(Math.abs(lane)>8*256)desired.push(lane>0?'s':'w');
    if(Math.abs(dx)<(ground.length?125:150)*256&&Math.abs(dy)<45*256)desired.push('r');
    for(const k of ['a','d','w','s','r'])await page.keyboard[desired.includes(k)?'down':'up'](k);
    if(Math.abs(dx)<200*256&&Math.abs(dy)<45*256){
     if(!ground.length&&Date.now()-jump>1200){
      await page.keyboard.up('r');await page.keyboard.press('Space');
      try{await page.waitForFunction(()=>window.svfQA.story.y<window.svfQA.story.ground_y-60*256,null,{timeout:900});await page.keyboard.press('g');}catch(e){if(e.name!=='TimeoutError')throw e;}jump=Date.now();
     }else if(ground.length&&Date.now()-strike>350){await page.keyboard.press('f');strike=Date.now();}
    }
   }else{
    await release(page);await page.keyboard.down('d');
   }
   await delay(90);
  }
  throw Error('Campaign keyboard driver did not reach its combat goal');
 }finally{await release(page);}
}
async function chargeStory(page,minimum){
 const result=await fightUntil(page,q=>q.meter>=minimum);
 assert(result.meter>=minimum,'Energy was earned through actual combat');
 return result;
}
module.exports={chargeStory,fightUntil,release,delay};
