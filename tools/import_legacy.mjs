/** Extracts approved artwork/data. No Canvas/JS game engine ships in the Godot build. */
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {execFileSync} from 'node:child_process';
import {pathToFileURL} from 'node:url';
const root=path.resolve(import.meta.dirname,'..');
const lock=JSON.parse(fs.readFileSync(path.join(root,'data/legacy/source-lock.json')));
const source=process.env.LEGACY_ROOT??path.join(root,'.tools/legacy-source');
if(!fs.existsSync(path.join(source,'.git'))){fs.mkdirSync(path.dirname(source),{recursive:true});execFileSync('git',['clone','--filter=blob:none','--no-checkout','--sparse',lock.repository,source],{stdio:'inherit'});}
if(!fs.existsSync(path.join(source,'src/engine.js'))||execFileSync('git',['rev-parse','HEAD'],{cwd:source,encoding:'utf8'}).trim()!==lock.commit){execFileSync('git',['fetch','origin',lock.commit],{cwd:source,stdio:'inherit'});execFileSync('git',['sparse-checkout','set','src','assets'],{cwd:source,stdio:'inherit'});execFileSync('git',['checkout','--detach',lock.commit],{cwd:source,stdio:'inherit'});}
const temp=fs.mkdtempSync(path.join(os.tmpdir(),'svf-migrate-'));
fs.cpSync(path.join(source,'src'),path.join(temp,'src'),{recursive:true});
fs.writeFileSync(path.join(temp,'package.json'),' {"type":"module"}');
fs.appendFileSync(path.join(temp,'src/engine.js'),'\nexport { moveData as migrationMoveData };\n');
const {CHARACTERS,Fighter,fighterPose,migrationMoveData}=await import(pathToFileURL(path.join(temp,'src/engine.js')));
const {FIGHTING_STYLES}=await import(pathToFileURL(path.join(temp,'src/styles.js')));
const {PREPARED_SPRITE_VERSIONS,MOTION_SPRITE_STEMS,ADDITIONAL_SPRITE_STEMS}=await import(pathToFileURL(path.join(temp,'src/sprite-loader.js')));
const portraitPath=id=>`assets/runtime/${id}-head-menu-v${['adriano','khauany','dienes'].includes(id)?1:['joao','gelton','tais'].includes(id)?4:3}.webp`;
const {SOUNDS}=await import(pathToFileURL(path.join(temp,'src/audio.js')));
const {SELECTION_QUOTES}=await import(pathToFileURL(path.join(temp,'src/selection-data.js')));
const story=await import(pathToFileURL(path.join(temp,'src/story-data.js')));
const {NATIVE_WALK_STRIDES}=await import(pathToFileURL(path.join(temp,'src/native-walk.js')));
const dest=path.join(root,'assets/legacy');fs.mkdirSync(dest,{recursive:true});
const files=new Set();
function copy(file){file=file.split('?')[0];if(!fs.existsSync(path.join(source,file)))throw Error('Missing approved asset '+file);const relative=file.replace(/^assets\//,'');const to=path.join(dest,relative);fs.mkdirSync(path.dirname(to),{recursive:true});fs.copyFileSync(path.join(source,file),to);files.add(relative);return 'res://assets/legacy/'+relative;}
function metadata(file){return JSON.parse(fs.readFileSync(path.join(source,file)));}
function sample(f){const pose=fighterPose(f);return {pose:[pose.atlas,pose.index],hurt:f.hurtboxes.map(b=>[Math.round(b.x-f.x),Math.round(b.y-f.y),Math.round(b.w),Math.round(b.h)])};}
const roster=[];
for(const [id,c]of Object.entries(CHARACTERS)){
 const stem=`assets/runtime/${id}-v${PREPARED_SPRITE_VERSIONS[id]}`;
 const meta=metadata(stem+'.json');const sheet=copy(stem+'.webp');const atlases={};
 for(const [name,p]of Object.entries(meta.atlases))atlases[name]={...p,image:sheet};
 if(MOTION_SPRITE_STEMS[id]){const m=MOTION_SPRITE_STEMS[id];atlases.motion={scale:1,frames:metadata(m+'.json'),image:copy(m+'.webp')};}
 for(const [name,m]of Object.entries(ADDITIONAL_SPRITE_STEMS[id]??{}))atlases[name]={...metadata(m+'.json'),image:copy(m+'.webp')};
 const animations={};
 for(const state of ['idle','walk','jump','crouch','block','lowBlock','hit','dizzy','ko','knockdown','wake','victory']){
  const f=new Fighter(id,0);f.state=state;f.input.down=['crouch','lowBlock'].includes(state);if(state==='jump')f.y-=100;if(state==='hit')f.hitstun=.3;
  animations[state]=[];
  for(let t=0;t<120;t++){f.animTime=t/120;f.walkTime=t/120;f.walkBlend=state==='walk'?1:0;f.walkDistance=t/120*(c.speed??330);f.wakeTime=state==='wake'?Math.max(0,.5-t/120):0;animations[state].push(sample(f));}
 }
 const moves={};
 for(const name of ['punch','kick','crouchPunch','sweep','airPunch','airKick','special','uppercut','super','drone','throw','guardCounter'])for(let strength=0;strength<3;strength++){
  const m=migrationMoveData(name,strength,id);if(!m)continue;
  const f=new Fighter(id,0);f.state=name;f.action=name;f.moveData=m;f.input.down=['crouchPunch','sweep'].includes(name);if(name.startsWith('air'))f.y-=100;
  const duration=Math.round((m.startup+m.active+m.recovery)*120);const frames=[];
  for(let t=0;t<duration;t++){f.actionTime=t/120;f.animTime=t/120;const s=sample(f);const b=f.attackbox;s.hit=b?[Math.round(b.x-f.x),Math.round(b.y-f.y),Math.round(b.w),Math.round(b.h)]:null;frames.push(s);}
  moves[`${name}:${strength}`]={...m,startup:Math.round(m.startup*60),active:Math.round(m.active*60),recovery:Math.round(m.recovery*60),hitstun:Math.round(m.stun*60),blockstun:Math.round(m.blockstun*60),frames,display_name:FIGHTING_STYLES[id]?.names?.[name]?.[strength]??c.powers?.[name]??name};
 }
 const voices={};for(const [key,file]of Object.entries(SOUNDS))if(key.startsWith(id+'-'))voices[key.substring(id.length+1)]=copy(file);
 roster.push({...c,style:FIGHTING_STYLES[id].name,combos:FIGHTING_STYLES[id].combos,selection_quote:SELECTION_QUOTES[id],portrait:copy(portraitPath(id)),stride:NATIVE_WALK_STRIDES[id],atlases,animations,moves,voices});
}
const sounds={};for(const [key,file]of Object.entries(SOUNDS))if(!Object.keys(CHARACTERS).some(id=>key.startsWith(id+'-')))sounds[key]=copy(file);
const animations=metadata('assets/story/enemy-animation-v5.json');for(const item of Object.values(animations))item.file=copy(item.file);
const props=metadata('assets/story/props-v3.json');for(const item of Object.values(props))item.file=copy(item.file);
const acts=story.STORY_ACTS.map(a=>({...a,background:copy(`assets/story/${a.id}-panorama-v2.webp`)}));
const enemies={};for(const [id,p]of Object.entries(story.ENEMY_TYPES))enemies[id]={...p,image:copy(`assets/story/enemy-${p.cell}.webp`),animation:animations[id]??null};
const data={schema:1,source:lock.commit,roster,sounds,arena:copy('assets/arena.webp'),story:{title:story.STORY_TITLE,premise:story.STORY_PREMISE,acts,enemies,props,rules:story.STORY_RULES},files:[...files]};
fs.writeFileSync(path.join(root,'data/legacy/catalog.json'),JSON.stringify(data));
fs.rmSync(temp,{recursive:true,force:true});
console.log(`MIGRATED ${roster.length} fighters, ${roster.reduce((n,c)=>n+Object.keys(c.moves).length,0)} moves, ${files.size} approved assets`);
