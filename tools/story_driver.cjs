/* Play the campaign through its public keyboard and read-only observations. */
const assert=require('node:assert/strict');
const delay=ms=>new Promise(r=>setTimeout(r,ms));
async function release(page){for(const key of ['a','d','w','s','r'])await page.keyboard.up(key);}
async function fightUntil(page,done,{timeout=60000}={}){
 const deadline=Date.now()+timeout;let strike=0,statusAt=0;
 try{
  while(Date.now()<deadline){
   const q=await page.evaluate(()=>window.svfQA.story);assert(q,'Campaign observation exists');
   if(done(q))return q;
   if(Date.now()-statusAt>8000){console.log('STORY DRIVER',JSON.stringify({wave:q.wave,hp:q.hp,meter:q.meter,x:Math.round(q.x/256),state:q.state,foes:q.enemy_states.filter(e=>e.hp>0).map(e=>[e.kind,e.hp,Math.round(e.x/256)])}));statusAt=Date.now();}
   assert(q.hp>0,'Campaign hero stays alive while earning energy');
   const live=q.enemy_states.filter(e=>e.hp>0);
   if(live.length&&q.meter>=100){
    await release(page);
    for(let i=0;i<30;i++){
     await page.keyboard.press('q');await delay(70);
     if((await page.evaluate(()=>window.svfQA.story.meter))<100)break;
    }
    await delay(500);continue;
   }
   const target=live.sort((a,b)=>Math.abs(a.x-q.x)-Math.abs(b.x-q.x))[0];
   const desired=[];
   if(target){
    const dx=target.x-q.x,dy=target.lane-q.ground_y;
    // Use the actual reach of the approved attacks, with room to defend.
    // Low machines are knocked down by the sweep; a head-height drone
    // is reached by the standing punch rather than a low kick.
    if(Math.abs(dx)>195*256)desired.push(dx>0?'d':'a');
    else if(Math.abs(dx)<180*256)desired.push(dx>0?'a':'d');
    const lane=625*256-q.ground_y;if(Math.abs(lane)>8*256)desired.push(lane>0?'s':'w');
    if(Math.abs(dx)>=180*256&&Math.abs(dx)<220*256&&Math.abs(dy)<45*256&&!desired.some(k=>k==='a'||k==='d'))desired.push('r');
    for(const k of ['a','d','w','s','r'])await page.keyboard[desired.includes(k)?'down':'up'](k);
    if(Math.abs(dx)>=75*256&&Math.abs(dx)<230*256&&Math.abs(dy)<45*256&&Date.now()-strike>350){
     await page.keyboard.press(target.kind==='snack'?'f':'g');strike=Date.now();
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
