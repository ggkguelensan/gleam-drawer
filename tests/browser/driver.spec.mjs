import { test, expect } from '@playwright/test';
test.beforeEach(async ({page})=>{
  await page.goto('/__driver_test.html');
  await page.waitForFunction(()=>!!window.fixture);
});
const settled = async (page,name='one') => expect.poll(()=>page.evaluate(name=>{
  const {d,m,items}=window.fixture;
  return d.snapshot(items[name].c).phase instanceof m.OpenPhase;
},name)).toBe(true);

test('registration replacement is stale-safe and teardown restores only owned values',async({page})=>{
  await page.evaluate(()=>{
    const f=window.fixture, x=f.items.one=f.create();
    x.parts.Popup.style.color='rgb(11, 22, 33)';
    x.parts.Popup.setAttribute('data-consumer','keep');
    const replacement=document.createElement('div'); replacement.className='handle';
    x.parts.Header.prepend(replacement);
    x.newHandle=replacement;
    x.newCleanup=f.ok(f.dom.register_part(x.binding,new f.m.Handle(),replacement));
    x.cleanups.Handle(); // must not unregister the replacement
    x.sync();
  });
  await settled(page);
  expect(await page.evaluate(()=>window.fixture.items.one.newHandle.style.touchAction)).toBe('pan-x');
  await page.evaluate(()=>{
    const x=window.fixture.items.one;
    x.parts.Popup.style.overflow='clip'; // external mutation after library ownership
    x.destroy(); x.destroy(); x.newCleanup();
  });
  expect(await page.evaluate(()=>{
    const x=window.fixture.items.one;
    return {overflow:x.parts.Popup.style.overflow,color:x.parts.Popup.style.color,
      height:x.parts.Popup.style.height,role:x.parts.Popup.getAttribute('role'),
      consumer:x.parts.Popup.getAttribute('data-consumer'),handle:x.newHandle.style.touchAction,
      inert:document.querySelector('#background').inert,body:document.body.style.overflow,
      animations:x.parts.Popup.getAnimations().length};
  })).toEqual({overflow:'clip',color:'rgb(11, 22, 33)',height:'',role:null,consumer:'keep',handle:'',inert:false,body:'',animations:0});
});

test('target waits for matching regions, crossfades and preserves unchanged inputs',async({page})=>{
  await page.evaluate(()=>{const f=window.fixture,x=f.items.one=f.create();x.sync();});
  await settled(page);
  await page.locator('#one input').fill('preserved');
  await page.evaluate(()=>{
    const f=window.fixture,x=f.items.one,o=x.options();
    x.sync({regions:new f.m.Regions(new f.m.RegionTarget('next',new f.m.Crossfade()),o.regions.body,o.regions.footer)});
  });
  expect(await page.evaluate(()=>window.fixture.d.snapshot(window.fixture.items.one.c).phase instanceof window.fixture.m.Preparing)).toBe(true);
  await page.evaluate(()=>{
    const f=window.fixture,x=f.items.one;
    x.cleanups.header();
    f.ok(f.dom.register_layer(x.binding,new f.m.HeaderRegion(),'header',new f.m.Outgoing(),x.parts.Header.querySelector('.header-layer')));
    x.incoming=x.layer('Header','next','Incoming','Next header');
    const surface=document.createElement('div');x.parts.Header.append(surface);
    f.ok(f.dom.register_surface(x.binding,new f.m.HeaderRegion(),surface));
  });
  await settled(page);
  await expect(page.locator('#one input')).toHaveValue('preserved');
  await expect(page.locator('#one [data-layer=incoming]')).toHaveAttribute('data-active','');
  await expect(page.locator('#one [data-layer=outgoing]')).toHaveAttribute('inert','');
});

test('rapid target replacement settles only the last transition',async({page})=>{
  await page.evaluate(()=>{const f=window.fixture,x=f.items.one=f.create();x.sync();});
  await settled(page);
  await page.evaluate(()=>{const f=window.fixture,x=f.items.one;x.sync({snap_point:'full'});});
  await expect.poll(()=>page.locator('#one .popup').evaluate(e=>e.getAnimations().length)).toBeGreaterThan(0);
  const final=await page.evaluate(()=>{const f=window.fixture,x=f.items.one;return x.sync({snap_point:'half',presentation:new f.m.Dialog()});});
  await settled(page);
  expect(await page.evaluate(()=>{
    const {d,items}=window.fixture;return d.snapshot(items.one.c).settled_target[0].id;
  })).toBe(final);
  await expect(page.locator('#one .popup')).toHaveAttribute('data-presentation','dialog');
  await expect.poll(()=>page.locator('#one .popup').evaluate(e=>e.getAnimations().length)).toBe(0);
});

test('non-modal transition and nested bindings retain locks until their final release',async({page})=>{
  await page.evaluate(()=>{const f=window.fixture;f.items.one=f.create();f.items.one.sync();});
  await settled(page);
  await page.evaluate(()=>{const f=window.fixture;f.items.two=f.create('two');f.items.two.sync();});
  await settled(page,'two');
  await page.evaluate(()=>window.fixture.items.two.destroy());
  await expect(page.locator('#background')).toHaveAttribute('inert','');
  expect(await page.evaluate(()=>document.body.style.overflow)).toBe('hidden');
  await page.evaluate(()=>{const f=window.fixture;f.items.one.sync({modality:new f.m.NonModal()});});
  await settled(page);
  await expect(page.locator('#background')).not.toHaveAttribute('inert');
  await expect(page.locator('#one .popup')).not.toHaveAttribute('aria-modal');
  expect(await page.evaluate(()=>document.body.style.overflow)).toBe('');
});

test('content resizing follows animate and keep-snap-and-scroll policies',async({page})=>{
  await page.evaluate(()=>{const f=window.fixture,x=f.items.one=f.create();x.parts.Body.querySelector('.body-layer').style.minHeight='80px';x.sync({snap_point:'content'});});
  await settled(page);
  const initial=await page.locator('#one .popup').boundingBox();
  await page.evaluate(()=>{const x=window.fixture.items.one;x.parts.Body.querySelector('.body-layer').style.minHeight='200px';});
  await expect.poll(async()=> (await page.locator('#one .popup').boundingBox()).height).toBeGreaterThan(initial.height+80);
  await page.evaluate(()=>{const f=window.fixture;f.items.one.sync({resize_behavior:new f.m.KeepSnapAndScroll()});});
  await settled(page);
  const kept=await page.locator('#one .popup').boundingBox();
  await page.evaluate(()=>{window.fixture.items.one.parts.Body.querySelector('.body-layer').style.minHeight='500px';});
  await page.waitForTimeout(350);
  expect((await page.locator('#one .popup').boundingBox()).height).toBeCloseTo(kept.height,0);
});

test('rejected drag request returns to the authoritative snap and destroy cancels gesture',async({page})=>{
  await page.evaluate(()=>{const f=window.fixture,x=f.items.one=f.create();x.sync();});
  await settled(page);
  const popup=page.locator('#one .popup'), handle=page.locator('#one .handle');
  const initial=await popup.boundingBox(), h=await handle.boundingBox();
  await page.mouse.move(h.x+h.width/2,h.y+15);await page.mouse.down();
  await page.mouse.move(h.x+h.width/2,h.y-100);
  await expect(popup).toHaveAttribute('data-swiping');
  await page.mouse.up();
  await settled(page);
  await expect.poll(async()=> (await popup.boundingBox()).y).toBeCloseTo(initial.y,0);
  const next=await handle.boundingBox();
  await page.mouse.move(next.x+next.width/2,next.y+15);await page.mouse.down();
  await page.mouse.move(next.x+next.width/2,next.y-70);
  await expect(popup).toHaveAttribute('data-swiping');
  await page.evaluate(()=>window.fixture.items.one.destroy());
  await page.mouse.up();
  await expect(popup).not.toHaveAttribute('data-swiping');
  expect(await popup.evaluate(e=>e.getAnimations().length)).toBe(0);
});
