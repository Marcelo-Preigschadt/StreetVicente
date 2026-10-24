/* Play the campaign through its public keyboard and read-only observations. */
const assert=require('node:assert/strict');
const delay=ms=>new Promise(r=>setTimeout(r,ms));
async function release(page){for(const key of ['a','d','w','s','r'])await page.keyboard.up(key);}
async function fightUntil(page,done,{timeout=60000,useSuper=true}={}){
 const deadline=Date.now()+timeout;let strike=0,statusAt=0;
 try{
  while(Date.now()<deadline){
   const q=await page.evaluate(()=>window.svfQA.story);assert(q,'Campaign observation exists');
   if(done(q))return q;
   if(Date.now()-statusAt>8000){console.log('STORY DRIVER',JSON.stringify({wave:q.wave,hp:q.hp,meter:q.meter,x:Math.round(q.x/256),state:q.state,foes:q.enemy_states.filter(e=>e.hp>0).map(e=>[e.kind,e.hp,Math.round(e.x/256)])}));statusAt=Date.now();}
   assert(q.hp>0,'Campaign hero stays alive while earning energy');
   const live=q.enemy_states.filter(e=>e.hp>0);
   if(useSuper&&live.length&&q.meter>=100){
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
    const reach=target.kind==='snack'||target.kind==='book'||target.kind==='archaeologist'?170:135;
    if(Math.abs(dx)>(reach+15)*256)desired.push(dx>0?'d':'a');
    else if(Math.abs(dx)<(reach-15)*256)desired.push(dx>0?'a':'d');
    if(Math.abs(dy)>12*256)desired.push(dy>0?'s':'w');
    if(Math.abs(dx)<(reach+25)*256&&Math.abs(dy)<25*256&&!desired.length)desired.push('r');
    for(const k of ['a','d','w','s','r'])await page.keyboard[desired.includes(k)?'down':'up'](k);
    if(Math.abs(dx)<240*256&&Math.abs(dy)<42*256&&Date.now()-strike>300){
     if(q.facing!==(dx>0?1:-1)&&['IDLE','WALK','BLOCK'].includes(q.state)){
      await page.keyboard.up('r');await page.keyboard.press(dx>0?'d':'a',{delay:40});
     }
     await page.keyboard.press(['snack','book','archaeologist'].includes(target.kind)?'g':'f');strike=Date.now();
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
