// Targeted Playwright regressions for graph gestures and asynchronous imports.
async (page) => {
  const assertions=[];
  function check(condition,name){if(!condition)throw new Error(name);assertions.push(name);}
  await page.setViewportSize({width:1440,height:1000});
  await page.goto('http://localhost:8090');
  await page.waitForFunction(()=>window.studio?.model);
  await page.locator('#layout').selectOption('pca');
  const node=page.locator('#graph .node').nth(5);
  const before=await node.getAttribute('transform'),box=await node.boundingBox();
  await page.mouse.move(box.x+box.width/2,box.y+box.height/2);
  await page.mouse.down();await page.mouse.move(box.x+box.width/2+35,box.y+box.height/2+20,{steps:8});await page.mouse.up();
  check(await node.getAttribute('transform')!==before,'Node drag updates position');
  check(await page.evaluate(()=>studio.selected.length)===0,'Dragging a node does not select it');
  const bounds=await page.locator('#graph').boundingBox();
  const panBefore=await page.locator('#graph').getAttribute('viewBox');
  await page.mouse.move(bounds.x+20,bounds.y+20);await page.mouse.down();
  await page.mouse.move(bounds.x+65,bounds.y+40,{steps:5});await page.mouse.up();
  check(await page.locator('#graph').getAttribute('viewBox')!==panBefore,'Background drag pans the graph');
  const zoomBefore=await page.locator('#graph').getAttribute('viewBox');
  await page.locator('#zoom-in').click();
  const zoomAfter=await page.locator('#graph').getAttribute('viewBox');
  check(Number(zoomAfter.split(' ')[2])<Number(zoomBefore.split(' ')[2]),'Zoom reduces the visible coordinate extent');
  await page.locator('#fit').click();await page.locator('#mode-select').click();
  await page.mouse.move(bounds.x+2,bounds.y+2);await page.mouse.down();
  await page.mouse.move(bounds.x+bounds.width-3,bounds.y+bounds.height-35,{steps:10});await page.mouse.up();
  check(await page.evaluate(()=>studio.selected.length)===600,'Rectangle selection deduplicates all original rows');
  await page.locator('#clear-selection').click();await page.locator('#mode-pan').click();
  // Hold a CSV import while the user asks for a different dataset.
  let releaseImport,noticeImport;
  const held=new Promise(resolve=>releaseImport=resolve),intercepted=new Promise(resolve=>noticeImport=resolve);
  await page.route('**/api/import',async route=>{noticeImport();await held;await route.continue();});
  await page.locator('#csv-file').setInputFiles({name:'delayed.csv',mimeType:'text/csv',buffer:Buffer.from('x,y\n1,2\n2,4\n3,6\n4,8\n')});
  await intercepted;
  await page.locator('[data-tab="data"]').click();
  await page.locator('#dataset').selectOption('circle');await page.locator('#dataset').selectOption('branches');
  await page.waitForFunction(()=>studio.dataset.name==='Three branches'&&studio.model?.dataset_id===studio.dataset.id);
  check(await page.evaluate(()=>studio.dataset.name==='Three branches'&&studio.model.dataset_id===studio.dataset.id),'Rapid dataset changes retain the latest model and data');
  check((await page.locator('#graph').getAttribute('viewBox')).split(' ').map(Number).every(Number.isFinite),'Rebuilding with the graph hidden retains finite SVG coordinates');
  await page.locator('[data-tab="mapper"]').click();
  const imported=page.waitForResponse(response=>response.url().endsWith('/api/import'));
  releaseImport();await imported;await page.waitForTimeout(100);
  check(await page.evaluate(()=>studio.dataset.name==='Three branches'),'Delayed CSV response cannot overwrite the latest dataset');
  await page.unroute('**/api/import');
  // A new table with an invalid scientific configuration cannot display the old graph.
  const workspace=await page.evaluate(()=>studio.workspace());
  workspace.dataset.name='Invalid geometry';workspace.config.columns=['x'];workspace.config.metric='correlation';
  await page.locator('#workspace-file').setInputFiles({name:'invalid-workspace.json',mimeType:'application/json',buffer:Buffer.from(JSON.stringify(workspace))});
  await page.waitForFunction(()=>document.getElementById('graph-metrics').textContent.includes('Model unavailable'));
  check(await page.locator('#graph .node').count()===0&&await page.evaluate(()=>studio.model===null),'Failed new-table reconstruction clears the previous graph');
  await page.goto('http://localhost:8090');await page.waitForFunction(()=>window.studio?.model);
  return {passed:assertions.length,assertions};
}
