const app = document.getElementById('app');
const canvas = document.getElementById('uvCanvas');
const ctx = canvas.getContext('2d');
let resource = 'realrpg_clothingstudio';
let state = { templates:{}, myDesigns:[], gender:'male', category:'tops', selectedTemplate:null, layers:[], selectedLayer:null, history:[], redo:[], currentDesignId:null };

function nui(name, data={}){ return fetch(`https://${GetParentResourceName ? GetParentResourceName() : resource}/${name}`, { method:'POST', headers:{'Content-Type':'application/json'}, body:JSON.stringify(data)}).catch(()=>{}); }
function uid(){return 'l_'+Math.random().toString(36).slice(2)+Date.now()}
function pushHistory(){ state.history.push(JSON.stringify(state.layers)); if(state.history.length>40) state.history.shift(); state.redo=[]; }

// DUI live preview - throttled canvas snapshot küldés a kliensnek
let _duiThrottleTimer = null;
const DUI_THROTTLE_MS = 150;
function sendDuiPreview(dataUrl) {
  if (_duiThrottleTimer) return;
  _duiThrottleTimer = setTimeout(() => { _duiThrottleTimer = null; }, DUI_THROTTLE_MS);
  nui('updatePreviewTexture', { image: dataUrl });
}

function drawUV(){
  ctx.clearRect(0,0,1024,1024); ctx.fillStyle='#f7f7f7'; ctx.fillRect(0,0,1024,1024);
  ctx.strokeStyle='rgba(0,0,0,.12)'; ctx.lineWidth=1;
  for(let i=0;i<1024;i+=64){ctx.beginPath();ctx.moveTo(i,0);ctx.lineTo(i,1024);ctx.stroke();ctx.beginPath();ctx.moveTo(0,i);ctx.lineTo(1024,i);ctx.stroke();}
  ctx.strokeStyle='rgba(0,0,0,.18)'; for(let i=0;i<60;i++){ctx.beginPath();ctx.moveTo(Math.random()*1024,Math.random()*1024);ctx.lineTo(Math.random()*1024,Math.random()*1024);ctx.stroke();}
  for(const l of state.layers){ if(!l.visible) continue; ctx.save(); ctx.globalAlpha=l.opacity??1; ctx.globalCompositeOperation=l.blend||'source-over'; ctx.translate(l.x,l.y); ctx.rotate((l.rotation||0)*Math.PI/180); if(l.type==='image'&&l.img){ctx.drawImage(l.img,-l.w/2,-l.h/2,l.w,l.h)} if(l.type==='text'){ctx.fillStyle=l.color||'#111';ctx.font=`${l.size||64}px Arial Black`;ctx.textAlign='center';ctx.fillText(l.text||'TEXT',0,0)} if(l.type==='shape'){ctx.fillStyle=l.color||'#d7ff00';ctx.fillRect(-l.w/2,-l.h/2,l.w,l.h)} ctx.restore(); }
  updateShirtPreview(); renderLayers();
}
function updateShirtPreview(){ const dataUrl = canvas.toDataURL('image/png'); document.getElementById('shirtDesign').style.backgroundImage = `url(${dataUrl})`; sendDuiPreview(dataUrl); }
function renderTemplates(){
  const grid=document.getElementById('templateGrid'); grid.innerHTML=''; const list=(((state.templates[state.gender]||{})[state.category])||[]); document.getElementById('count').textContent=list.length+' ITEMS';
  list.forEach(t=>{const div=document.createElement('div');div.className='tile'+(state.selectedTemplate?.id===t.id?' selected':'');div.innerHTML=`<img src="${t.preview||'assets/tshirt.png'}"><small>${t.label}</small>`;div.onclick=()=>selectTemplate(t);grid.appendChild(div)});
}
function selectTemplate(t){ state.selectedTemplate=t; document.getElementById('details').innerHTML=`<b>${t.id}</b><br/>${t.label}<br/>Component: ${t.component}<br/>Drawable: ${t.drawable}${t.dui?' <span style="color:#d7ff00">[DUI]</span>':''}`; document.getElementById('activeTemplate').textContent=`${t.id} - 1024x1024`; renderTemplates(); nui('previewClothing',{template:t, garmentId:t.garmentId||null, gender:state.gender, category:state.category}); }
function renderLayers(){
  const wrap=document.getElementById('layersList'); document.getElementById('layerCount').textContent=state.layers.length; if(!state.layers.length){wrap.innerHTML='<p class="muted">No layers yet</p>';return} wrap.innerHTML='';
  [...state.layers].reverse().forEach(l=>{const div=document.createElement('div');div.className='layer'+(state.selectedLayer===l.id?' active':'');div.innerHTML=`<div class="thumb" style="background-image:url(${l.src||''})"></div><b>${l.name||l.type}</b><span style="margin-left:auto">${l.visible?'👁':'—'}</span>`;div.onclick=()=>{state.selectedLayer=l.id;fillProps(l);drawUV()};wrap.appendChild(div)});
}
function fillProps(l){ document.getElementById('propX').value=Math.round(l.x||0);document.getElementById('propY').value=Math.round(l.y||0);document.getElementById('propRot').value=Math.round(l.rotation||0);document.getElementById('propOpacity').value=l.opacity??1;document.getElementById('propBlend').value=l.blend||'source-over'; }
function selected(){ return state.layers.find(l=>l.id===state.selectedLayer); }
function addImage(src){ const img=new Image(); img.onload=()=>{ pushHistory(); const l={id:uid(),type:'image',name:'Image Layer',x:512,y:512,w:360,h:Math.round(360*img.height/img.width),rotation:0,opacity:1,blend:'source-over',visible:true,src,img}; state.layers.push(l); state.selectedLayer=l.id; drawUV();}; img.src=src; }
function addText(){ pushHistory(); const l={id:uid(),type:'text',name:'Text Layer',x:512,y:512,text:'REALRPG',size:72,color:'#111',rotation:0,opacity:1,blend:'source-over',visible:true}; state.layers.push(l); state.selectedLayer=l.id; drawUV(); }
function addShape(){ pushHistory(); const l={id:uid(),type:'shape',name:'Fill Layer',x:512,y:512,w:420,h:260,color:'#d7ff00',rotation:0,opacity:.75,blend:'source-over',visible:true}; state.layers.push(l); state.selectedLayer=l.id; drawUV(); }

document.getElementById('closeBtn').onclick=()=>{app.classList.add('hidden');nui('close')};
document.querySelectorAll('.cat').forEach(b=>b.onclick=()=>{document.querySelectorAll('.cat').forEach(x=>x.classList.remove('active'));b.classList.add('active');state.category=b.dataset.cat;renderTemplates()});
document.querySelectorAll('.genderBtn').forEach(b=>b.onclick=()=>{document.querySelectorAll('.genderBtn').forEach(x=>x.classList.remove('active'));b.classList.add('active');state.gender=b.dataset.gender;renderTemplates()});
document.getElementById('useTemplate').onclick=()=>{ if(state.selectedTemplate) nui('previewClothing',{template:state.selectedTemplate}); };
document.getElementById('imageBtn').onclick=()=>document.getElementById('fileInput').click();
document.getElementById('fileInput').onchange=e=>{const f=e.target.files[0]; if(!f) return; if(f.size > 4*1024*1024) return alert('Maximum 4 MB.'); const r=new FileReader(); r.onload=()=>addImage(r.result); r.readAsDataURL(f);};
document.querySelector('[data-mode="text"]').onclick=addText; document.getElementById('addShapeBtn').onclick=addShape;
document.getElementById('saveBtn').onclick=()=>{ if(!state.selectedTemplate) return alert('Válassz sablont.'); const label=prompt('Design neve:',document.getElementById('designName').textContent||'Untitled Design')||'Untitled Design'; document.getElementById('designName').textContent=label; nui('saveDesign',{label,gender:state.gender,category:state.category,templateId:state.selectedTemplate.id,garmentId:state.selectedTemplate.garmentId||'',design:{layers:state.layers.map(l=>({...l,img:undefined}))},preview:canvas.toDataURL('image/png')}); };
document.getElementById('printBtn').onclick=()=>{ if(!state.currentDesignId) return alert('Először mentsd el a designt.'); nui('printDesign',{designId:state.currentDesignId}); };
document.getElementById('readyBtn').onclick=()=>document.getElementById('printBtn').click();
document.getElementById('undoBtn').onclick=()=>{ if(!state.history.length)return; state.redo.push(JSON.stringify(state.layers)); state.layers=JSON.parse(state.history.pop()); reloadImages(); };
document.getElementById('redoBtn').onclick=()=>{ if(!state.redo.length)return; state.history.push(JSON.stringify(state.layers)); state.layers=JSON.parse(state.redo.pop()); reloadImages(); };
['propX','propY','propRot','propOpacity','propBlend'].forEach(id=>document.getElementById(id).oninput=()=>{const l=selected(); if(!l)return; l.x=+propX.value; l.y=+propY.value; l.rotation=+propRot.value; l.opacity=+propOpacity.value; l.blend=propBlend.value; drawUV();});
function reloadImages(){ let pending=0; state.layers.forEach(l=>{ if(l.type==='image'&&l.src){pending++;l.img=new Image();l.img.onload=()=>{if(--pending<=0)drawUV()};l.img.src=l.src;}}); if(!pending) drawUV(); }
window.addEventListener('message',e=>{ const msg=e.data||{}; if(msg.action==='open'){ app.classList.remove('hidden'); state.templates=msg.data.templates||{}; state.myDesigns=msg.data.myDesigns||[]; renderTemplates(); drawUV(); } if(msg.action==='designSaved'){ state.currentDesignId=msg.design.design_id; alert('Design elmentve: '+msg.design.label); }});
drawUV();
