const app = document.getElementById('app');
const canvas = document.getElementById('uvCanvas');
const ctx = canvas.getContext('2d');
let resource = 'realrpg_clothingstudio';
let state = {
  templates:{}, myDesigns:[], gender:'male', category:'tops',
  selectedTemplate:null, layers:[], selectedLayer:null,
  history:[], redo:[], currentDesignId:null, currentDesignLabel:'Untitled Design',
  activeTab:'library', designFilter:'all', designSearch:''
};


// ═══════════════════════════════════════════════════════════════
// UTILITY
// ═══════════════════════════════════════════════════════════════

function nui(name, data={}){ return fetch(`https://${typeof GetParentResourceName!=='undefined'?GetParentResourceName():resource}/${name}`, {method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(data)}).then(r=>r.json()).catch(()=>({})); }
function uid(){return 'l_'+Math.random().toString(36).slice(2)+Date.now()}
function pushHistory(){state.history.push(JSON.stringify(state.layers));if(state.history.length>40)state.history.shift();state.redo=[];updateStatusDot('unsaved');}

// DUI live preview - throttled
let _duiThrottleTimer = null;
const DUI_THROTTLE_MS = 150;
function sendDuiPreview(dataUrl){
  if(_duiThrottleTimer) return;
  _duiThrottleTimer = setTimeout(()=>{_duiThrottleTimer=null;}, DUI_THROTTLE_MS);
  nui('updatePreviewTexture',{image:dataUrl});
}

// Loading overlay
function showLoading(text){
  document.getElementById('loadingText').textContent = text||'Loading...';
  document.getElementById('loadingOverlay').classList.remove('hidden');
}
function hideLoading(){ document.getElementById('loadingOverlay').classList.add('hidden'); }

// Toast notifications
function showToast(title, message, type){
  let container = document.querySelector('.toastContainer');
  if(!container){container=document.createElement('div');container.className='toastContainer';document.getElementById('app').appendChild(container);}
  const toast = document.createElement('div');
  toast.className = 'toast ' + (type||'info');
  toast.innerHTML = `<div class="toastTitle">${title}</div><span>${message}</span>`;
  container.appendChild(toast);
  setTimeout(()=>{toast.classList.add('fadeOut');setTimeout(()=>toast.remove(),300);},3500);
}

// Confirm dialog
function showConfirm(title, text){ return new Promise(resolve=>{
  document.getElementById('confirmTitle').textContent=title;
  document.getElementById('confirmText').textContent=text;
  document.getElementById('confirmDialog').classList.remove('hidden');
  document.getElementById('confirmYes').onclick=()=>{document.getElementById('confirmDialog').classList.add('hidden');resolve(true);};
  document.getElementById('confirmNo').onclick=()=>{document.getElementById('confirmDialog').classList.add('hidden');resolve(false);};
});}


// ═══════════════════════════════════════════════════════════════
// CANVAS / UV EDITOR
// ═══════════════════════════════════════════════════════════════

function drawUV(){
  ctx.clearRect(0,0,1024,1024); ctx.fillStyle='#f7f7f7'; ctx.fillRect(0,0,1024,1024);
  ctx.strokeStyle='rgba(0,0,0,.12)'; ctx.lineWidth=1;
  for(let i=0;i<1024;i+=64){ctx.beginPath();ctx.moveTo(i,0);ctx.lineTo(i,1024);ctx.stroke();ctx.beginPath();ctx.moveTo(0,i);ctx.lineTo(1024,i);ctx.stroke();}
  for(const l of state.layers){ if(!l.visible) continue; ctx.save(); ctx.globalAlpha=l.opacity??1; ctx.globalCompositeOperation=l.blend||'source-over'; ctx.translate(l.x,l.y); ctx.rotate((l.rotation||0)*Math.PI/180);
    if(l.type==='image'&&l.img){ctx.drawImage(l.img,-l.w/2,-l.h/2,l.w,l.h)}
    if(l.type==='text'){ctx.fillStyle=l.color||'#111';ctx.font=`${l.size||64}px Arial Black`;ctx.textAlign='center';ctx.fillText(l.text||'TEXT',0,0)}
    if(l.type==='shape'){ctx.fillStyle=l.color||'#d7ff00';ctx.fillRect(-l.w/2,-l.h/2,l.w,l.h)}
    ctx.restore();
  }
  updateShirtPreview(); renderLayers();
}

function updateShirtPreview(){
  const dataUrl = canvas.toDataURL('image/png');
  document.getElementById('shirtDesign').style.backgroundImage = `url(${dataUrl})`;
  sendDuiPreview(dataUrl);
}


// ═══════════════════════════════════════════════════════════════
// TEMPLATE GRID RENDERING
// ═══════════════════════════════════════════════════════════════

function renderTemplates(){
  const grid=document.getElementById('templateGrid');grid.innerHTML='';
  const list=(((state.templates[state.gender]||{})[state.category])||[]);
  document.getElementById('count').textContent=list.length+' ITEMS';
  list.forEach(t=>{
    const div=document.createElement('div');
    div.className='tile'+(state.selectedTemplate?.id===t.id?' selected':'');
    const duiBadge = t.dui ? '<span class="duiBadge">DUI</span>' : '';
    div.innerHTML=`<img src="${t.preview||'assets/tshirt.png'}">${duiBadge}<small>${t.label}</small>`;
    div.onclick=()=>selectTemplate(t);
    grid.appendChild(div);
  });
}

function selectTemplate(t){
  state.selectedTemplate=t;
  const duiTag = t.dui ? ' <span style="color:#d7ff00">[DUI]</span>' : '';
  document.getElementById('details').innerHTML=`<b>${t.id}</b><br/>${t.label}<br/>Component: ${t.component}<br/>Drawable: ${t.drawable}${duiTag}`;
  document.getElementById('activeTemplate').textContent=`${t.id} - 1024x1024`;
  renderTemplates();
  nui('previewClothing',{template:t, garmentId:t.garmentId||null, gender:state.gender, category:state.category});
}


// ═══════════════════════════════════════════════════════════════
// MY DESIGNS PANEL
// ═══════════════════════════════════════════════════════════════

function renderMyDesigns(){
  const grid = document.getElementById('myDesignsGrid');
  const noMsg = document.getElementById('noDesigns');
  const detail = document.getElementById('designDetail');
  detail.classList.add('hidden');
  grid.innerHTML = '';

  let designs = state.myDesigns || [];
  // Filter by category
  if(state.designFilter !== 'all'){
    designs = designs.filter(d => d.category === state.designFilter);
  }
  // Search filter
  if(state.designSearch){
    const q = state.designSearch.toLowerCase();
    designs = designs.filter(d => (d.label||'').toLowerCase().includes(q));
  }

  if(!designs.length){
    noMsg.classList.remove('hidden');
    noMsg.textContent = state.myDesigns.length ? 'No matching designs' : 'No saved designs yet';
    return;
  }
  noMsg.classList.add('hidden');

  designs.forEach(d => {
    const card = document.createElement('div');
    card.className = 'designCard';
    const previewSrc = d.preview_data || d.image_url || 'assets/tshirt.png';
    const duiTag = d.garment_id ? '<span class="duiBadge small">DUI</span>' : '';
    card.innerHTML = `
      <div class="designCardImg"><img src="${previewSrc}" alt="${d.label}"/>${duiTag}</div>
      <div class="designCardInfo">
        <b>${d.label||'Untitled'}</b>
        <small>${d.category||'?'} &bull; ${d.gender||'?'} &bull; ${formatDate(d.created_at)}</small>
      </div>`;
    card.onclick = () => showDesignDetail(d);
    grid.appendChild(card);
  });
}

function formatDate(str){
  if(!str) return '?';
  try{ return new Date(str).toLocaleDateString('hu-HU',{year:'numeric',month:'short',day:'numeric'}); }
  catch(e){ return str; }
}

function showDesignDetail(d){
  const detail = document.getElementById('designDetail');
  detail.classList.remove('hidden');
  document.getElementById('designDetailImg').src = d.preview_data || d.image_url || 'assets/tshirt.png';
  document.getElementById('designDetailName').textContent = d.label || 'Untitled';
  document.getElementById('designDetailMeta').innerHTML = `
    Category: <b>${d.category}</b> | Gender: <b>${d.gender}</b><br/>
    Template: ${d.template_id||'?'}<br/>
    Created: ${formatDate(d.created_at)}${d.garment_id?' | <span style="color:#d7ff00">DUI Ready</span>':''}`;
  
  document.getElementById('loadDesignBtn').onclick = () => loadDesign(d);
  document.getElementById('deleteDesignBtn').onclick = () => deleteDesign(d);
}

async function loadDesign(d){
  showLoading('Loading design...');
  nui('loadDesign', { designId: d.design_id });
  // A szerver visszaküldi a designLoaded event-et ami a message handler-ben van kezelve
}

async function deleteDesign(d){
  const confirmed = await showConfirm('Delete Design', `Are you sure you want to delete "${d.label}"? This cannot be undone.`);
  if(!confirmed) return;
  showLoading('Deleting...');
  nui('deleteDesign', { designId: d.design_id });
  // A szerver designDeleted event-et küld vissza
}


// ═══════════════════════════════════════════════════════════════
// TAB SWITCHING
// ═══════════════════════════════════════════════════════════════

function switchTab(tab){
  state.activeTab = tab;
  document.querySelectorAll('.tab').forEach(b=>b.classList.toggle('active',b.dataset.tab===tab));
  document.getElementById('libraryContent').classList.toggle('hidden', tab!=='library');
  document.getElementById('myDesignsContent').classList.toggle('hidden', tab!=='my');
  if(tab==='my') renderMyDesigns();
  if(tab==='library') renderTemplates();
}

// ═══════════════════════════════════════════════════════════════
// LAYERS PANEL
// ═══════════════════════════════════════════════════════════════

function renderLayers(){
  const wrap=document.getElementById('layersList');
  document.getElementById('layerCount').textContent=state.layers.length;
  if(!state.layers.length){wrap.innerHTML='<p class="muted">No layers yet</p>';return;}
  wrap.innerHTML='';
  [...state.layers].reverse().forEach(l=>{
    const div=document.createElement('div');
    div.className='layer'+(state.selectedLayer===l.id?' active':'');
    div.innerHTML=`<div class="thumb" style="background-image:url(${l.src||''})"></div><b>${l.name||l.type}</b><span style="margin-left:auto">${l.visible?'&#128065;':'&mdash;'}</span>`;
    div.onclick=()=>{state.selectedLayer=l.id;fillProps(l);drawUV()};
    wrap.appendChild(div);
  });
}

function fillProps(l){
  document.getElementById('propX').value=Math.round(l.x||0);
  document.getElementById('propY').value=Math.round(l.y||0);
  document.getElementById('propRot').value=Math.round(l.rotation||0);
  document.getElementById('propOpacity').value=l.opacity??1;
  document.getElementById('propBlend').value=l.blend||'source-over';
}
function selected(){ return state.layers.find(l=>l.id===state.selectedLayer); }


// ═══════════════════════════════════════════════════════════════
// ADD LAYERS
// ═══════════════════════════════════════════════════════════════

function addImage(src){
  const img=new Image();
  img.onload=()=>{pushHistory();const l={id:uid(),type:'image',name:'Image Layer',x:512,y:512,w:360,h:Math.round(360*img.height/img.width),rotation:0,opacity:1,blend:'source-over',visible:true,src,img};state.layers.push(l);state.selectedLayer=l.id;drawUV();};
  img.src=src;
}
function addText(){pushHistory();const l={id:uid(),type:'text',name:'Text Layer',x:512,y:512,text:'REALRPG',size:72,color:'#111',rotation:0,opacity:1,blend:'source-over',visible:true};state.layers.push(l);state.selectedLayer=l.id;drawUV();}
function addShape(){pushHistory();const l={id:uid(),type:'shape',name:'Fill Layer',x:512,y:512,w:420,h:260,color:'#d7ff00',rotation:0,opacity:.75,blend:'source-over',visible:true};state.layers.push(l);state.selectedLayer=l.id;drawUV();}

function reloadImages(){
  let pending=0;
  state.layers.forEach(l=>{
    if(l.type==='image'&&l.src){pending++;l.img=new Image();l.img.onload=()=>{if(--pending<=0)drawUV()};l.img.src=l.src;}
  });
  if(!pending) drawUV();
}

// ═══════════════════════════════════════════════════════════════
// NEW DESIGN
// ═══════════════════════════════════════════════════════════════

function newDesign(){
  state.layers=[];state.selectedLayer=null;state.history=[];state.redo=[];
  state.currentDesignId=null;state.currentDesignLabel='Untitled Design';
  state.selectedTemplate=null;
  document.getElementById('designName').textContent='Untitled Design';
  document.getElementById('activeTemplate').textContent='empty - 1024x1024';
  document.getElementById('details').innerHTML='No model selected<br/>Choose from the library';
  renderTemplates();drawUV();
}


// ═══════════════════════════════════════════════════════════════
// EVENT BINDINGS
// ═══════════════════════════════════════════════════════════════

document.getElementById('closeBtn').onclick=()=>{app.classList.add('hidden');nui('close')};
document.getElementById('newBtn').onclick=newDesign;
document.getElementById('openBtn').onclick=()=>switchTab('my');

// Tabs
document.querySelectorAll('.tab').forEach(b=>b.onclick=()=>switchTab(b.dataset.tab));

// Categories
document.querySelectorAll('.cat').forEach(b=>b.onclick=()=>{
  document.querySelectorAll('.cat').forEach(x=>x.classList.remove('active'));
  b.classList.add('active');state.category=b.dataset.cat;renderTemplates();
});

// Gender
document.querySelectorAll('.genderBtn').forEach(b=>b.onclick=()=>{
  document.querySelectorAll('.genderBtn').forEach(x=>x.classList.remove('active'));
  b.classList.add('active');state.gender=b.dataset.gender;renderTemplates();
});

// Design category filter
document.querySelectorAll('.dfilt').forEach(b=>b.onclick=()=>{
  document.querySelectorAll('.dfilt').forEach(x=>x.classList.remove('active'));
  b.classList.add('active');state.designFilter=b.dataset.dcat;renderMyDesigns();
});

// Design search
document.getElementById('designSearch').oninput=e=>{state.designSearch=e.target.value;renderMyDesigns();};

// Template use
document.getElementById('useTemplate').onclick=()=>{if(state.selectedTemplate)nui('previewClothing',{template:state.selectedTemplate,garmentId:state.selectedTemplate.garmentId||null,gender:state.gender,category:state.category});};

// Image upload
document.getElementById('imageBtn').onclick=()=>document.getElementById('fileInput').click();
document.getElementById('fileInput').onchange=e=>{const f=e.target.files[0];if(!f)return;if(f.size>4*1024*1024)return alert('Maximum 4 MB.');const r=new FileReader();r.onload=()=>addImage(r.result);r.readAsDataURL(f);};

// Text & Shape
document.querySelector('[data-mode="text"]').onclick=addText;
document.getElementById('addShapeBtn').onclick=addShape;


// Save
document.getElementById('saveBtn').onclick=()=>{
  if(!state.selectedTemplate) return alert('Valassz sablont.');
  const label=prompt('Design neve:',state.currentDesignLabel)||'Untitled Design';
  state.currentDesignLabel=label;
  document.getElementById('designName').textContent=label;
  showLoading('Saving...');
  nui('saveDesign',{
    label, gender:state.gender, category:state.category,
    templateId:state.selectedTemplate.id,
    garmentId:state.selectedTemplate.garmentId||'',
    design:{layers:state.layers.map(l=>({...l,img:undefined}))},
    preview:canvas.toDataURL('image/png')
  }).then(()=>hideLoading());
};

// Print
document.getElementById('printBtn').onclick=()=>{
  if(!state.currentDesignId) return alert('Eloszor mentsd el a designt.');
  showLoading('Printing...');
  nui('printDesign',{designId:state.currentDesignId}).then(()=>hideLoading());
};
document.getElementById('readyBtn').onclick=()=>document.getElementById('printBtn').click();

// Undo/Redo
document.getElementById('undoBtn').onclick=()=>{if(!state.history.length)return;state.redo.push(JSON.stringify(state.layers));state.layers=JSON.parse(state.history.pop());reloadImages();};
document.getElementById('redoBtn').onclick=()=>{if(!state.redo.length)return;state.history.push(JSON.stringify(state.layers));state.layers=JSON.parse(state.redo.pop());reloadImages();};

// Layer properties
['propX','propY','propRot','propOpacity','propBlend'].forEach(id=>
  document.getElementById(id).oninput=()=>{
    const l=selected();if(!l)return;
    l.x=+document.getElementById('propX').value;
    l.y=+document.getElementById('propY').value;
    l.rotation=+document.getElementById('propRot').value;
    l.opacity=+document.getElementById('propOpacity').value;
    l.blend=document.getElementById('propBlend').value;
    drawUV();
  }
);


// ═══════════════════════════════════════════════════════════════
// NUI MESSAGE HANDLER
// ═══════════════════════════════════════════════════════════════

window.addEventListener('message', e=>{
  const msg = e.data || {};

  if(msg.action==='open'){
    app.classList.remove('hidden');
    state.templates = msg.data.templates || {};
    state.myDesigns = msg.data.myDesigns || [];
    renderTemplates();
    drawUV();
  }

  if(msg.action==='designSaved'){
    state.currentDesignId = msg.design.design_id;
    state.currentDesignLabel = msg.design.label || state.currentDesignLabel;
    document.getElementById('designName').textContent = state.currentDesignLabel;
    hideLoading();
    showToast('Saved', `"${state.currentDesignLabel}" saved successfully.`, 'success');
    // Save pulse animation
    const saveBtn = document.getElementById('saveBtn');
    saveBtn.classList.add('savePulse');
    setTimeout(()=>saveBtn.classList.remove('savePulse'),700);
    // Update status dot
    updateStatusDot('saved');
    // Add to local myDesigns
    const exists = state.myDesigns.find(d=>d.design_id===msg.design.design_id);
    if(!exists){
      state.myDesigns.unshift({
        design_id: msg.design.design_id,
        label: msg.design.label,
        gender: msg.design.gender,
        category: msg.design.category,
        template_id: msg.design.template_id,
        garment_id: msg.design.garment_id,
        preview_data: msg.design.preview_data,
        image_url: msg.design.image_url,
        created_at: new Date().toISOString()
      });
    }
  }

  if(msg.action==='designDeleted'){
    state.myDesigns = state.myDesigns.filter(d=>d.design_id!==msg.designId);
    hideLoading();
    showToast('Deleted', 'Design successfully deleted.', 'success');
    document.getElementById('designDetail').classList.add('hidden');
    renderMyDesigns();
  }

  if(msg.action==='designLoaded'){
    hideLoading();
    if(msg.design){
      const design = msg.design;
      state.currentDesignId = design.design_id;
      state.currentDesignLabel = design.label || 'Untitled';
      document.getElementById('designName').textContent = state.currentDesignLabel;
      state.gender = design.gender || 'male';
      state.category = design.category || 'tops';
      document.querySelectorAll('.genderBtn').forEach(b=>b.classList.toggle('active',b.dataset.gender===state.gender));
      document.querySelectorAll('.cat').forEach(b=>b.classList.toggle('active',b.dataset.cat===state.category));
      const t=((state.templates[state.gender]||{})[state.category]||[]).find(x=>x.id===design.template_id);
      if(t) selectTemplate(t);
      let layerData=[];
      try{const parsed=typeof design.design_json==='string'?JSON.parse(design.design_json):design.design_json;layerData=parsed.layers||[];}catch(e){}
      state.layers=layerData.map(l=>({...l,id:l.id||uid(),visible:l.visible!==false}));
      state.history=[];state.redo=[];
      reloadImages();
      switchTab('library');
      document.getElementById('activeTemplate').textContent=`${design.template_id} - 1024x1024`;
      updateStatusDot('saved');
      showToast('Loaded', `"${design.label}" opened for editing.`, 'info');
    }
  }

  if(msg.action==='designLoadFailed'){
    hideLoading();
    showToast('Error', 'Failed to load design.', 'error');
  }
});

// ═══════════════════════════════════════════════════════════════
// STATUS DOT (saved/unsaved indicator)
// ═══════════════════════════════════════════════════════════════

function updateStatusDot(status){
  const nameEl = document.getElementById('designName');
  let dot = nameEl.previousElementSibling;
  if(!dot || !dot.classList.contains('statusDot')){
    dot = document.createElement('span');
    dot.className='statusDot';
    nameEl.parentElement.insertBefore(dot, nameEl);
  }
  dot.className = 'statusDot ' + (status||'empty');
}

// ═══════════════════════════════════════════════════════════════
// INIT
// ═══════════════════════════════════════════════════════════════

drawUV();
