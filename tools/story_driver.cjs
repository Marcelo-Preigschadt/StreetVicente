/* Play the campaign through its public keyboard and read-only observations. */
const assert=require('node:assert/strict');
const delay=ms=>new Promise(r=>setTimeout(r,ms));
async function release(page){for(const key of ['a','d','w','s','r'])await page.keyboard.up(key);}
// Plan through the actual furniture footprints when a checkpoint is clear.
// Observations stay read-only; the route is executed with normal keyboard keys.
function corridorKeys(q){
 const unit=256,step=8,x0=q.x/unit,y0=q.ground_y/unit;
 const gate=Math.min(3560,880+q.wave*820);
 const minX=Math.ceil((Math.max(70,x0-400)-x0)/step),maxX=Math.floor((gate-55-x0)/step);
 const minY=Math.ceil((535-y0)/step),maxY=Math.floor((655-y0)/step);
 const props=q.props.filter(p=>!p.used&&p.hp>0&&p.kind!=='medkit');
 const blocked=(ix,iy)=>{
  const x=x0+ix*step,y=y0+iy*step;
  return props.some(p=>Math.abs(x-p.x/unit)<Math.round(q.prop_sizes[p.kind][0]*.38)+18&&Math.abs(y-p.lane/unit)<(p.kind==='table'?32:24));
 };
 const nodes=[{x:0,y:0,parent:-1}],seen=new Set(['0,0']);let found=-1;
 for(let at=0;at<nodes.length;at++){
  const n=nodes[at];
  if(x0+n.x*step>=gate-100&&y0+n.y*step>=640){found=at;break;}
  for(const [dx,dy] of [[0,1],[1,0],[-1,0],[0,-1]]){
   const x=n.x+dx,y=n.y+dy,key=x+','+y;
   if(x<minX||x>maxX||y<minY||y>maxY||seen.has(key)||blocked(x,y))continue;
   seen.add(key);nodes.push({x,y,parent:at});
  }
 }
 if(found<0)return y0<640?['s']:['d'];
 const route=[];for(let i=found;nodes[i].parent>=0;i=nodes[i].parent)route.push(nodes[i]);route.reverse();
 if(!route.length)return ['d'];
 const first=route[0];return first.x>0?['d']:first.x<0?['a']:first.y>0?['s']:['w'];
}
async function fightUntil(page,done,{timeout=60000,useSuper=true}={}){
 const deadline=Date.now()+timeout;let strike=0,statusAt=0,navigating=false;
 try{
  while(Date.now()<deadline){
   const q=await page.evaluate(()=>window.svfQA.story);assert(q,'Campaign observation exists');
   if(done(q))return q;
   if(Date.now()-statusAt>8000){console.log('STORY DRIVER',JSON.stringify({wave:q.wave,hp:q.hp,meter:q.meter,x:Math.round(q.x/256),state:q.state,foes:q.enemy_states.filter(e=>e.hp>0).map(e=>[e.kind,e.hp,Math.round(e.x/256)])}));statusAt=Date.now();}
   assert(q.hp>0,'Campaign hero stays alive while earning energy');
   const live=q.enemy_states.filter(e=>e.hp>0);
   if(useSuper&&live.length&&q.meter>=100&&['IDLE','WALK','BLOCK'].includes(q.state)&&q.facing===(live.slice().sort((a,b)=>Math.abs(a.x-q.x)-Math.abs(b.x-q.x))[0].x>q.x?1:-1)){
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
    if(navigating&&q.ground_y>=640*256)navigating=false;
    const barrier=Math.abs(dx)>(reach+15)*256&&q.props.some(p=>!p.used&&p.hp>0&&p.kind!=='medkit'&&
     (p.x-q.x)*Math.sign(dx)>0&&Math.abs(p.x-q.x)<=(q.prop_sizes[p.kind][0]*.38+30)*256&&
     Math.abs(p.lane-q.ground_y)<(p.kind==='table'?34:26)*256);
    if(navigating||barrier){
     navigating=true;const route=corridorKeys(q);
     for(const key of ['a','d','w','s','r'])await page.keyboard[route.includes(key)?'down':'up'](key);
     await delay(90);continue;
    }
    if(Math.abs(dx)>(reach+15)*256)desired.push(dx>0?'d':'a');
    else if(Math.abs(dx)<70*256)desired.push(dx>0?'a':'d');
    if(Math.abs(dy)>12*256)desired.push(dy>0?'s':'w');
    if(Math.abs(dx)<(reach+25)*256&&Math.abs(dy)<25*256&&!desired.length)desired.push('r');
    for(const k of ['a','d','w','s','r'])await page.keyboard[desired.includes(k)?'down':'up'](k);
    // Let the current attack finish before turning. Queuing more attacks
    // while facing away would intentionally keep a real player facing away.
    if(q.facing!==(dx>0?1:-1)&&Math.abs(dx)>=70*256){
     await release(page);await page.keyboard.press(dx>0?'d':'a',{delay:50});continue;
    }
    if(Math.abs(dx)>=75*256&&Math.abs(dx)<240*256&&Math.abs(dy)<42*256&&Date.now()-strike>300){
     await release(page);
     await page.keyboard.press(['snack','book','archaeologist'].includes(target.kind)?'g':'f');strike=Date.now();
    }
   }else{
    const route=corridorKeys(q);
    for(const key of ['a','d','w','s','r'])await page.keyboard[route.includes(key)?'down':'up'](key);
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
