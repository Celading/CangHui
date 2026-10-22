#!/usr/bin/env node
/** Compile native observations and reviewed source operations into an editable design set. */
import fs from 'node:fs';import path from 'node:path';import {createHash} from 'node:crypto';import {pathToFileURL} from 'node:url';
const args=process.argv.slice(2),arg=(name)=>{const i=args.indexOf(name);if(i<0||!args[i+1])throw Error('Missing '+name);return args[i+1];};
const input=path.resolve(arg('--input')),base=JSON.parse(fs.readFileSync(arg('--base'),'utf8')),root=path.resolve(arg('--source-root')),design=path.resolve(arg('--design-root')),output=path.resolve(arg('--output'));
if(fs.existsSync(output))throw Error('Output exists; choose a new candidate');
const lib=await import(pathToFileURL(path.join(design,'dist/haomo-design.js')).href);
if(typeof lib.auditNativeMotion!=='function')throw Error('Selected design library lacks reviewed native motion support');
const sha=x=>createHash('sha256').update(x).digest('hex'),read=p=>{const real=fs.realpathSync(path.resolve(root,p));if(!real.startsWith(root+path.sep))throw Error('Source escapes reviewed root');return fs.readFileSync(real);},sources=['examples/motion-lab/src/view.cj','examples/motion-lab/src/model.cj','packages/kit/src/motion_visuals.cj','packages/kit/src/rolling_number.cj','packages/kit/src/motion_style.cj','sdl/src/renderer.cj','sdl/src/draw_ir.cj','src/core/probe.cj'];
const captureProof=JSON.parse(fs.readFileSync(path.join(input,'capture-proof.json'),'utf8'));if(captureProof.schema!=='canghui.native-motion-capture/v1')throw Error('Native capture proof required');
const sourceManifest=Object.fromEntries(sources.map(p=>[p,sha(read(p))]));const source=(p,symbol)=>({path:p,symbol,digest:sourceManifest[p]});
const names=['Bounce','Digital','Focus Light','Choreography','Archive'],families=['bounce','digital','focus-light','choreography','archive'];
const old=new Map(base.nodes.map(n=>[n.id,n]));const doc={...base,revision:base.revision+1,nodes:[],pages:base.pages,adaptive:{schema:'haomodesign-adaptive/v1',defaultSceneId:'motion-0-1060-light-full',scenes:[],rules:[],motions:[]},behaviors:[],extensions:{...base.extensions},resources:[...(base.resources||[])]};
const observations=[],imports=[],frames=[],defaults={},bindings={},controls={},variables={family:{initial:0,values:[0,1,2,3,4]},width:{initial:1060,values:[390,1060]},dark:{initial:false},reduced:{initial:false},shown:{initial:true},replay:{initial:0,min:0,max:Number.MAX_SAFE_INTEGER},number:{initial:'128'}};
for(let f=0;f<5;f++)controls['family-'+f]={variable:'family',mode:'set',value:f,label:`0${f+1}  ${families[f]}`,source:source(sources[0],'motionLabView')};
controls.theme={variable:'dark',mode:'toggle',label:'Toggle palette',source:source(sources[0],'motionLabView')};controls.reduced={variable:'reduced',mode:'toggle',label:'Reduced motion',source:source(sources[0],'motionLabView')};
controls.replay={variable:'number',mode:'integer-step',delta:1,integerWrap:'0',label:'Replay',source:source(sources[1],'MotionLabState.repeat'),effects:[{toggle:['shown'],increment:{replay:1}}]};
controls.digits={variable:'number',mode:'map',cases:{'9':'10','10':'9','128':'9','129':'9','9223372036854775807':'9','-9223372036854775808':'9'},label:'9 → 10',source:source(sources[0],'motionLabActions'),effects:[]};
// Native handler chooses9 for every other value; retain that default without numeric rounding.
controls.digits.defaultValue='9';controls['integer-limit']={variable:'number',mode:'set',value:'9223372036854775807',label:'Largest integer',source:source(sources[0],'motionLabActions')};
const rules=[];
function color(v){return '#'+['r','g','b'].map(k=>v[k].toString(16).padStart(2,'0')).join('');}
for(let f=0;f<5;f++)for(const width of [1060,390])for(const dark of [false,true])for(const reduced of [false,true]){
 const file=`family-${f}-w${width}-dark${dark}-reduced${reduced}-t1600.json`,raw=fs.readFileSync(path.join(input,file)),capture=JSON.parse(raw),v1=capture.content.base.content,draw=v1.drawIr;
 if(draw.some(c=>c.kind==='text'&&(c.data.metricsBackend!=='native'||c.data.textOrigin!=='top-left')))throw Error('Real native metrics required: '+file);
 const compiled=lib.compileCangHuiDesignSnapshot(capture,{documentId:doc.id,documentName:doc.name,context:doc.context});if(!compiled.document||compiled.receipt.status==='rejected')throw Error('Native hard compile rejected');
 const basic=!dark&&!reduced,prefix=`f${f}-w${width}-`+(basic?'':`dark${dark}-reduced${reduced}-`),id=x=>prefix+x,pageId='study-'+f,rootId=id('screen:motion.'+f);
 if(captureProof.snapshotSha256[file]!==sha(raw))throw Error('Stale or modified native observation: '+file);
 for(const [p,d]of Object.entries(captureProof.sourceFiles))if(sha(read(p))!==d)throw Error('Source drift since native capture: '+p);
 const palette={};const tk=doc.appKit.tokens.filter(t=>t.group===['Bounce','Digital','FocusLight','Choreography','Archive'][f]);for(const t of tk)palette[t.id.split('.').at(-1)]=t.values[dark?'dark':'light'];
 const members=[];
 for(const incoming of compiled.document.nodes){let n={...old.get(id(incoming.id)),...incoming,id:id(incoming.id),pageId,parentId:incoming.parentId?id(incoming.parentId):undefined,extensions:{...old.get(id(incoming.id))?.extensions,...incoming.extensions,sourceObservation:{file,sha256:sha(raw),nodeId:incoming.id}}};
  n.sourceBinding={provider:'CangHui',relativePath:sources[0],symbol:'motionLabView',sourceDigest:sourceManifest[sources[0]]};
  if(n.id===rootId){n.visible=basic&&width===1060;n.fill=palette.background;defaults[rootId]={family:f,width,dark,reduced,number:'128',shown:true,replay:0};}
  if(incoming.id.startsWith('control-semantic:')){const key=incoming.id.slice('control-semantic:'.length);if(controls[key]){bindings[n.id]=key;n.semantic={...n.semantic,layer:'atomic'};}}
  if(incoming.id==='stage'||incoming.id==='stage:number'||incoming.id==='stage:terminal'){
   const family=incoming.id.endsWith(':number')?'rolling-number':incoming.id.endsWith(':terminal')?'terminal':families[f];const p=family==='rolling-number'?sources[3]:sources[2];
   n.extensions['haomodesign.native-motion/v1']={family,palette,source:source(p,family==='rolling-number'?'kitRollingNumber':family==='terminal'?'kitTerminal':'kit'+names[f].replaceAll(' ','')),textMetrics:draw.filter(c=>c.kind==='text'&&c.scope===incoming.id).map(c=>({text:c.data.text,pointSize:c.data.pointSize,bold:c.data.bold===true,width:c.data.measuredWidth,height:c.data.measuredHeight})),fontFamily:'HarmonyOS Sans SC',fontSize:48,focusNodeId:id('control-semantic:replay')};n.semantic={...n.semantic,layer:'component'};
  }
  const fill=String(n.fill||'').match(/^rgba\((\d+), (\d+), (\d+), 1\)$/);if(fill){const value=color({r:+fill[1],g:+fill[2],b:+fill[3]});const token=tk.find(t=>t.values[dark?'dark':'light']===value);if(token)n.styleRefs={...n.styleRefs,fill:token.id};}
  // Each captured theme keeps its observed literal fallback; token resolution uses source mode rules below.
  for(const field of ['fill','stroke'])if(n[field]&&n[field]!=='transparent'){
   const tokenId='captured.'+sha(n[field]).slice(0,16);if(!doc.appKit.tokens.some(t=>t.id===tokenId))doc.appKit.tokens.push({id:tokenId,name:'Native paint / '+n[field],type:'color',group:'Captured native paint',values:{light:n[field],dark:n[field]}});n.styleRefs={...n.styleRefs,[field]:tokenId};
  }
  // An opaque source clear may be retained beneath the first isolated coverage mesh.
  // Refuse this optimization when any prior non-background paint intersects the mesh.
  const mesh=n.extensions?.['canghui.paint-mesh/v1'];
  if(mesh){
   const xs=mesh.vertices.filter((_,i)=>i%3===0),ys=mesh.vertices.filter((_,i)=>i%3===1),box={x:Math.floor(n.x+Math.min(...xs)),y:Math.floor(n.y+Math.min(...ys)),right:Math.ceil(n.x+Math.max(...xs)),bottom:Math.ceil(n.y+Math.max(...ys))};
   const clip=n.extensions['canghui.clip/v1'];if(clip){box.x=Math.max(box.x,n.x+clip.x);box.y=Math.max(box.y,n.y+clip.y);box.right=Math.min(box.right,n.x+clip.x+clip.width);box.bottom=Math.min(box.bottom,n.y+clip.y+clip.height);}
   const overlaps=members.some(p=>{const draw=p.extensions?.['canghui.draw-command/v1'];if(!draw)return false;const clip=p.extensions['canghui.clip/v1'],left=Math.max(p.x,clip?p.x+clip.x:-Infinity),top=Math.max(p.y,clip?p.y+clip.y:-Infinity),right=Math.min(p.x+p.width,clip?p.x+clip.x+clip.width:Infinity),bottom=Math.min(p.y+p.height,clip?p.y+clip.y+clip.height:Infinity);return left<box.right&&right>box.x&&top<box.bottom&&bottom>box.y&&!(left<=box.x&&top<=box.y&&right>=box.right&&bottom>=box.bottom&&p.radius===0&&['scene.begin','paint.fill'].includes(draw.command.kind)&&draw.command.data.color?.a===255&&color(draw.command.data.color)===palette.background);});
   if(!overlaps)n.extensions['canghui.uniform-backdrop/v1']={fill:palette.background,x:n.x,y:n.y,width:n.width,height:n.height,paint:n.fill,sourceObservation:sha(raw)};
  }
  if(mesh){const previous=members.at(-1),backdrop=previous?.extensions?.['canghui.uniform-backdrop/v1'];
   if(backdrop&&previous.parentId===n.parentId&&previous.extensions['canghui.paint-mesh/v1']){
    previous.extensions['canghui.mesh-batch/v1']=[previous,n].map(p=>({id:p.id,x:p.x,y:p.y,width:p.width,height:p.height,fill:p.fill}));
    n.extensions['canghui.mesh-batch-owner/v1']=previous.id;
   }
  }
  members.push(n);
 }
 doc.nodes.push(...members);
 const scene={...compiled.document.adaptive.scenes[0],id:`motion-${f}-${width}-${dark?'dark':'light'}-${reduced?'reduced':'full'}`,name:`${names[f]} · ${width} · ${dark?'Dark':'Light'}${reduced?' · Reduced':''}`,pageId,rootNodeId:rootId,environment:{...compiled.document.adaptive.scenes[0].environment,theme:dark?'dark':'light',reducedMotion:reduced}};doc.adaptive.scenes.push(scene);
 frames.push({screenIds:[],when:{family:f,width,dark,reduced},frameId:rootId});
 const losses=compiled.receipt.losses.filter(l=>!(l.code==='unsupported-draw-command'&&l.message.includes('paint.clear')&&draw.filter(c=>c.kind==='paint.clear').every(c=>color(c.data.color)===palette.background))&&!['missing-source-binding','missing-motion'].includes(l.code)&&!(l.code==='structure'&&l.sourcePath==='content.scenes')&&!(l.code==='unsupported-draw-command'&&l.message.includes('scene.end')));
 observations.push({viewId:scene.id,route:'/study/'+f,nodeIds:members.map(n=>n.id),controls:members.filter(n=>bindings[n.id]).map(n=>n.id),viewport:{width,height:900},losses:losses.map(l=>l.code+': '+l.message)});imports.push({file,receipt:compiled.receipt,remainingLosses:losses});
}
const rootIds=frames.map(f=>f.frameId);for(const f of frames)f.screenIds=rootIds;
for(const scene of doc.adaptive.scenes)scene.nodeOverrides=Object.fromEntries(rootIds.filter(id=>doc.nodes.find(n=>n.id===id).pageId===scene.pageId).map(id=>[id,{visible:id===scene.rootNodeId}]));
const ids=new Set(doc.nodes.map(n=>n.id));for(const n of base.nodes)if(!ids.has(n.id))doc.nodes.push({...n,visible:false,extensions:{...n.extensions,sourceSuperseded:{reason:'native measured layout replaces heuristic layout',preserveIdentity:true}}});
for(const n of doc.nodes)if(bindings[n.id]){n.extensions={...n.extensions,'haomodesign.prototype-control/v1':bindings[n.id]};if(bindings[n.id]==='theme')n.accessibility={...n.accessibility,name:'Toggle palette'};}
rules.push({when:{},patches:rootIds.map(nodeId=>({nodeId,set:{visible:false}}))});for(const f of frames)rules.push({when:f.when,patches:[{nodeId:f.frameId,set:{visible:true}}]});
const model={variables,controls,rules,frames,initialByFrame:defaults,baseFrameByFrame:Object.fromEntries(rootIds.map(id=>[id,id]))};doc.extensions['haomodesign.prototype-state/v1']=model;
doc.extensions['haomodesign.product-capture/v1']={captureId:'native-motion-source',observations};doc.extensions['haomodesign.design-set/v1']={id:doc.id,application:'CangHui Motion Studio',sourceDocuments:[]};
doc.extensions['motionStudy']={...base.extensions.motionStudy,state:'source-bound-candidate',sourceManifest,sourceCounts:observations.map(o=>({viewId:o.viewId,nodes:o.nodeIds.length})),nativeMeasurements:true,pendingControls:[],gaps:['Installed player requires the reviewed motion runtime candidate','Source-recorded coverage meshes and measured text constraints require same-state browser/native verification','Capability and owner acceptance remain unverified'],remainingLosses:imports.flatMap(i=>i.remainingLosses),ownerAcceptance:false};
doc.resources=doc.resources.filter(r=>r.id!=='motion-original-font');
const font=read('assets/fonts/HarmonyOS_Sans_SC.ttf');if(font.byteLength>=24*1024*1024)throw Error('Original font exceeds resource limit');doc.resources.push({id:'motion-original-font',kind:'font',name:'HarmonyOS Sans SC',provider:'CangHui bundled original font',digest:sha(font),fallback:false,provenance:'document',font:{family:'HarmonyOS Sans SC',weight:400,weightRange:[40,900],style:'normal',dataUrl:'data:font/ttf;base64,'+font.toString('base64')}});
doc.extensions.fontProvenance={relativePath:'assets/fonts/HarmonyOS_Sans_SC.ttf',sha256:sha(font),license:read('assets/fonts/HARMONYOS_SANS_LICENSE.txt').toString(),unmodified:true};
doc.capabilityWorkbook={schema:'haomodesign-capability-workbook/v1',rows:names.map((name,f)=>({id:'motion-'+families[f],capabilityId:'canghui.motion.'+families[f],title:name,designStatus:'draft',notes:'Source-linked visual study; native and editor acceptance recorded separately.',source:{status:'source-owned',version:'unreleased',proof:'native captured observations',matrixRef:'',matrixRevision:''},links:[{documentId:doc.id,pageId:'study-'+f,nodeId:`f${f}-w1060-`+(f===1?'stage:terminal':'stage'),projectRef:doc.context.projectRef,memberRef:doc.context.memberRef,observedRevision:doc.revision}]}))};
const profile={schema:'haomodesign-style/v1',id:'motion-source-style',name:'Motion Studio source recipes',version:1,description:'Measured source layouts and original five-family palettes.',principles:['Preserve source typography','One motion subject per study','Passive decoration keeps input ownership','Reduced motion uses final states'],lighting:{azimuth:0,elevation:90,softness:0,ambient:'#ffffff',shadow:'#101828',directionTolerance:0},constraints:{accentAreaMax:.55,maxFocalObjects:5,maxElevationLevels:2,maxLiteralColorRatio:.35,minimumWhitespaceRatio:.15},materials:[],components:[],required:[{id:'source',summary:'Match source geometry and timing',detail:'Use captured native source and original font bytes.'}],forbidden:[{id:'fake',summary:'Do not substitute flattened screenshots',detail:'All native geometry remains editable.'}],provenance:{kind:'authored',ownerReviewed:false,referencesPrivate:false,note:'Derived from source-owned original motion Kit.'},createdAt:new Date().toISOString()};doc.styleProfiles=[...(base.styleProfiles||[]).filter(p=>p.id!==profile.id),profile];doc.activeStyleProfileId=profile.id;
// Bind the captured source objects without inventing materials or visual acceptance.
for(const n of doc.nodes)if(n.extensions?.sourceObservation)n.styleBinding={profileId:profile.id,profileVersion:profile.version,emphasis:n.extensions['haomodesign.native-motion/v1']&&/^f[0-4]-w1060-stage(?::.*)?$/.test(n.id)?'focal':n.kind==='text'?'support':'chrome'};
const errors=[...lib.auditPrototypeState(doc),...lib.auditNativeMotion(doc)];if(errors.length)throw Error(errors.join('\n'));const text=JSON.stringify(doc);if(Buffer.byteLength(text)>40*1024*1024)throw Error('Design set exceeds40MiB');fs.writeFileSync(output,text+'\n',{flag:'wx'});fs.writeFileSync(output+'.proof.json',JSON.stringify({sourceManifest,fontSha256:sha(font),fontBytes:font.byteLength,pages:doc.pages.length,views:observations.length,nodes:doc.nodes.length,sourceControls:Object.keys(bindings).length,originalIdsPreserved:base.nodes.every(n=>doc.nodes.some(x=>x.id===n.id)),remainingLosses:imports.flatMap(i=>i.remainingLosses),sourceControlBindings:bindings},null,2));
console.log(JSON.stringify({output,pages:doc.pages.length,views:observations.length,nodes:doc.nodes.length,controls:Object.keys(bindings).length,bytes:Buffer.byteLength(text)}));
