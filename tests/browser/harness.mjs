import * as d from '../../build/dev/javascript/gleam_drawer/gleam_drawer.mjs';
import * as dom from '../../build/dev/javascript/gleam_drawer/gleam_drawer/dom.mjs';
import * as m from '../../build/dev/javascript/gleam_drawer/gleam_drawer/model.mjs';
import { Ok, toList } from '../../build/dev/javascript/gleam_drawer/gleam.mjs';
import { Some, None } from '../../build/dev/javascript/gleam_stdlib/gleam/option.mjs';
const none = new None();
const ok = result => { if (!(result instanceof Ok)) throw new Error(result[0]); return result[0]; };
const style = document.createElement('style');
style.textContent = `body{margin:0} .portal{position:fixed;inset:0;pointer-events:none}.backdrop{position:absolute;inset:0;background:#0005;pointer-events:auto}.viewport{position:absolute;inset:0;display:grid;align-items:end;justify-items:center;pointer-events:none}.viewport[data-presentation=dialog]{place-items:center;padding:16px}.popup{position:relative;width:min(640px,100%);height:var(--drawer-height);background:white;pointer-events:auto;border-radius:20px 20px 0 0}.handle{height:30px;background:#ddd}.region-layer{padding:16px;box-sizing:border-box}.body-layer{min-height:500px}.footer-layer{height:76px}`;
document.head.append(style);
function create(id='one') {
  const portal=document.createElement('div'); portal.className='portal'; portal.id=id;
  portal.innerHTML=`<div class="backdrop"></div><div class="viewport"><section class="popup" aria-label="${id}"><div class="content"><header class="header"><div class="handle"></div><div class="header-layer region-layer">Heading</div></header><div class="body"><div class="body-layer region-layer"><input aria-label="value"><p>Body</p></div></div><footer class="footer"><div class="footer-layer region-layer"><button>Action</button></div></footer></div></section></div>`;
  document.body.append(portal);
  const c=ok(d.create(new Some(d.closed('initial')))); const binding=ok(dom.bind(c,dom.defaults()));
  const events=[]; d.subscribe(c,(snapshot,event)=>events.push({snapshot,event}));
  const parts={Portal:portal};
  for(const name of ['Backdrop','Viewport','Popup','Content','Header','Body','Footer','Handle']) parts[name]=portal.querySelector(`.${name.toLowerCase()}`);
  const cleanups={}; for(const [name,el] of Object.entries(parts)) cleanups[name]=ok(dom.register_part(binding,new m[name](),el));
  for(const [region,key] of [['HeaderRegion','header'],['BodyRegion','body'],['FooterRegion','footer']]) cleanups[key]=ok(dom.register_layer(binding,new m[region](),key,new m.Settled(),portal.querySelector(`.${key}-layer`)));
  ok(dom.register_part(binding,new m.InertTarget(),document.querySelector('#background')));
  let options=d.options(toList([new m.SnapPoint('half',new m.Ratio(0.45)),new m.SnapPoint('full',new m.Ratio(0.85)),new m.SnapPoint('content',new m.ContentSize(new Some(0.9)))]),'half');
  let serial=0;
  const makeOptions=(patch={})=>new m.OpenOptions(patch.snap_points??options.snap_points,patch.snap_point??options.snap_point,patch.presentation??options.presentation,patch.modality??options.modality,patch.draggable??options.draggable,patch.sequential??options.sequential,patch.resize_behavior??options.resize_behavior,patch.regions??options.regions);
  const sync=(patch={}, transition=d.transition(new m.ApiCause()))=>{options=makeOptions(patch); const id=`target-${++serial}`;ok(d.sync(c,new m.Open(id,options,transition,none)));return id;};
  const layer=(region,key,slot,text='Next')=>{const el=document.createElement('div');el.className='region-layer';el.textContent=text;parts[region].append(el);return {el,cleanup:ok(dom.register_layer(binding,new m[`${region}Region`](),key,new m[slot](),el))};};
  return {id,c,binding,parts,events,cleanups,sync,layer,options:()=>options,close:()=>ok(d.sync(c,d.closed(`closed-${++serial}`))),destroy:()=>ok(dom.destroy(binding))};
}
window.fixture={d,dom,m,Some,None,toList,ok,none,create,items:{}};
