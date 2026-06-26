const app = document.getElementById('app');
const canvas = document.getElementById('uvCanvas');
const ctx = canvas.getContext('2d');

const state = {
  templates: {},
  myDesigns: [],
  marketplace: [],
  marketplaceEnabled: false,
  selectedMarketplaceDesign: null,
  activeTab: 'library',
  gender: 'male',
  category: 'tops',
  selectedTemplate: null,
  selectedSavedDesign: null,
  layers: [],
  selectedLayer: null,
  history: [],
  redo: [],
  currentDesignId: null,
  currentMode: 'select',
  gridEnabled: true,
  mirrorEnabled: false,
  aiEnabled: false,
  maxUploadMB: 4,
  uploadBridge: { enabled: false, chunkSize: 240000, failSaveIfUploadFails: false, uploadLayerAssets: false, failLayerUploadIfUploadFails: false },
  pendingUploads: {},
  dragging: null,
  drawing: false,
};

const $ = (id) => document.getElementById(id);
const searchInput = $('search');
const propX = $('propX');
const propY = $('propY');
const propRot = $('propRot');
const propOpacity = $('propOpacity');
const propBlend = $('propBlend');
const propText = $('propText');
const propColor = $('propColor');
const brushColor = $('brushColor');
const brushSize = $('brushSize');

function nui(name, data = {}) {
  const resource = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'realrpg_clothingstudio';
  return fetch(`https://${resource}/${name}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data)
  }).catch(() => {});
}

function uid() {
  return `l_${Math.random().toString(36).slice(2)}${Date.now()}`;
}

function cloneLayers(layers) {
  return JSON.parse(JSON.stringify(layers));
}

function pushHistory() {
  state.history.push(JSON.stringify(state.layers.map(stripRuntime)));
  if (state.history.length > 50) state.history.shift();
  state.redo = [];
}

function stripRuntime(layer) {
  const copy = { ...layer };
  delete copy.img;
  delete copy.uploadPromise;
  delete copy.localSrc;

  if (copy.type === 'image' && copy.assetUrl) {
    copy.src = copy.assetUrl;
    copy.cdn = true;
  }

  return copy;
}

function isDataUrl(value) {
  return typeof value === 'string' && value.startsWith('data:image/');
}

function safeCanvasDataUrl() {
  try {
    return canvas.toDataURL('image/png');
  } catch (error) {
    nui('notify', { message: `Canvas export hiba: ${error.message || error}`, type: 'error' });
    return null;
  }
}

function resetCanvasState() {
  state.layers = [];
  state.selectedLayer = null;
  state.currentDesignId = null;
  state.selectedSavedDesign = null;
  state.selectedMarketplaceDesign = null;
  state.history = [];
  state.redo = [];
  $('designName').textContent = 'Névtelen Design';
}

function drawGrid() {
  if (!state.gridEnabled) return;
  ctx.strokeStyle = 'rgba(0, 0, 0, 0.10)';
  ctx.lineWidth = 1;
  for (let i = 0; i <= 1024; i += 64) {
    ctx.beginPath(); ctx.moveTo(i, 0); ctx.lineTo(i, 1024); ctx.stroke();
    ctx.beginPath(); ctx.moveTo(0, i); ctx.lineTo(1024, i); ctx.stroke();
  }
}

function drawUvGuides() {
  ctx.save();
  ctx.strokeStyle = 'rgba(40, 40, 40, 0.14)';
  ctx.lineWidth = 2;
  ctx.strokeRect(128, 160, 768, 736);
  ctx.strokeRect(312, 72, 400, 110);
  ctx.strokeRect(64, 220, 180, 320);
  ctx.strokeRect(780, 220, 180, 320);
  ctx.restore();
}

function drawLayer(layer) {
  if (!layer.visible) return;

  ctx.save();
  ctx.globalAlpha = layer.opacity ?? 1;
  ctx.globalCompositeOperation = layer.blend || 'source-over';

  const scaleX = state.mirrorEnabled ? -1 : 1;
  ctx.translate(layer.x || 0, layer.y || 0);
  ctx.rotate(((layer.rotation || 0) * Math.PI) / 180);
  ctx.scale(scaleX, 1);

  if (layer.type === 'image' && layer.img) {
    ctx.drawImage(layer.img, -(layer.w / 2), -(layer.h / 2), layer.w, layer.h);
  } else if (layer.type === 'text') {
    ctx.fillStyle = layer.color || '#111111';
    ctx.font = `${layer.size || 72}px Arial Black`;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText(layer.text || 'TEXT', 0, 0);
  } else if (layer.type === 'shape') {
    ctx.fillStyle = layer.color || '#d7ff00';
    ctx.fillRect(-(layer.w / 2), -(layer.h / 2), layer.w, layer.h);
  } else if (layer.type === 'brush') {
    ctx.strokeStyle = layer.color || '#d7ff00';
    ctx.lineWidth = layer.size || 12;
    ctx.lineCap = 'round';
    ctx.lineJoin = 'round';
    const points = layer.points || [];
    if (points.length > 1) {
      ctx.beginPath();
      ctx.moveTo(points[0].x - layer.x, points[0].y - layer.y);
      for (let i = 1; i < points.length; i++) {
        ctx.lineTo(points[i].x - layer.x, points[i].y - layer.y);
      }
      ctx.stroke();
    }
  }

  ctx.restore();
}

function updateShirtPreview() {
  $('shirtDesign').style.backgroundImage = `url(${canvas.toDataURL('image/png')})`;
}

function drawUV() {
  ctx.clearRect(0, 0, 1024, 1024);
  ctx.fillStyle = '#f5f5f5';
  ctx.fillRect(0, 0, 1024, 1024);
  drawGrid();
  drawUvGuides();
  state.layers.forEach(drawLayer);

  // Kijelölt layer keret + sarok fogantyúk
  const sel = selectedLayer();
  if (sel && sel.visible) {
    const bounds = layerBounds(sel);
    ctx.save();
    ctx.strokeStyle = '#d4a853';
    ctx.lineWidth = 2;
    ctx.setLineDash([6, 4]);
    ctx.strokeRect(bounds.x, bounds.y, bounds.w, bounds.h);
    ctx.setLineDash([]);

    // Sarok fogantyúk (resize jelzők)
    const handleSize = 8;
    ctx.fillStyle = '#d4a853';
    const corners = [
      [bounds.x, bounds.y],
      [bounds.x + bounds.w, bounds.y],
      [bounds.x, bounds.y + bounds.h],
      [bounds.x + bounds.w, bounds.y + bounds.h]
    ];
    corners.forEach(([cx, cy]) => {
      ctx.fillRect(cx - handleSize / 2, cy - handleSize / 2, handleSize, handleSize);
    });
    ctx.restore();
  }

  updateShirtPreview();
  renderLayers();
}

function getTemplatesForCurrentView() {
  const list = (((state.templates[state.gender] || {})[state.category]) || []);
  const q = searchInput.value.trim().toLowerCase();
  return list.filter((item) => !q || `${item.label} ${item.id}`.toLowerCase().includes(q));
}

function getDesignsForCurrentView() {
  const q = searchInput.value.trim().toLowerCase();
  return state.myDesigns.filter((item) => {
    const matchesSearch = !q || `${item.label} ${item.design_id} ${item.category}`.toLowerCase().includes(q);
    const matchesCategory = item.category === state.category;
    const matchesGender = item.gender === state.gender;
    return matchesSearch && matchesCategory && matchesGender;
  });
}


function getMarketplaceForCurrentView() {
  const q = searchInput.value.trim().toLowerCase();
  return state.marketplace.filter((item) => {
    const haystack = `${item.label || ''} ${item.design_id || ''} ${item.category || ''} ${item.owner_name || ''}`.toLowerCase();
    const matchesSearch = !q || haystack.includes(q);
    const matchesCategory = item.category === state.category;
    const matchesGender = item.gender === state.gender;
    return matchesSearch && matchesCategory && matchesGender;
  });
}

function setActiveTab(tab) {
  state.activeTab = tab;
  document.querySelectorAll('.tab').forEach((el) => el.classList.toggle('active', el.dataset.tab === tab));
  $('useTemplate').classList.toggle('hidden', tab !== 'library');
  $('loadDesignBtn').classList.toggle('hidden', tab !== 'my');
  $('publishDesignBtn').classList.toggle('hidden', tab !== 'my');
  $('unpublishDesignBtn').classList.toggle('hidden', tab !== 'my');
  $('buyMarketBtn').classList.toggle('hidden', tab !== 'marketplace');

  const title = tab === 'library'
    ? 'SABLONOK <span id="count"></span>'
    : tab === 'my'
      ? 'DESIGNJAIM <span id="count"></span>'
      : 'PIACTÉR <span id="count"></span>';
  $('leftTitle').innerHTML = title;

  if (tab === 'marketplace') {
    nui('refreshMarketplace', { gender: state.gender, category: state.category, search: searchInput.value.trim() });
  }

  renderSidebar();
}

function renderSidebar() {
  const grid = $('templateGrid');
  grid.innerHTML = '';

  if (state.activeTab === 'library') {
    const list = getTemplatesForCurrentView();
    $('count').textContent = `${list.length} SABLON`;

    list.forEach((t) => {
      const div = document.createElement('div');
      div.className = 'tile' + (state.selectedTemplate?.id === t.id ? ' selected' : '');
      div.innerHTML = `<img src="${t.preview || 'assets/tshirt.png'}" alt=""><small>${t.label}</small>`;
      div.onclick = () => selectTemplate(t);
      grid.appendChild(div);
    });
  } else if (state.activeTab === 'my') {
    const list = getDesignsForCurrentView();
    $('count').textContent = `${list.length} DESIGN`;

    list.forEach((design) => {
      const div = document.createElement('div');
      div.className = 'tile designTile' + (state.selectedSavedDesign?.design_id === design.design_id ? ' selected' : '');
      div.innerHTML = `
        <img src="${design.preview_data || design.image_url || 'assets/tshirt.png'}" alt="">
        <small>${design.label}</small>
        <span class="tileMeta">${design.category}</span>
      `;
      div.onclick = () => selectSavedDesign(design);
      grid.appendChild(div);
    });
  } else {
    const list = getMarketplaceForCurrentView();
    $('count').textContent = `${list.length} HIRDETÉS`;

    list.forEach((design) => {
      const div = document.createElement('div');
      div.className = 'tile designTile' + (state.selectedMarketplaceDesign?.design_id === design.design_id ? ' selected' : '');
      div.innerHTML = `
        <img src="${design.preview_data || design.image_url || 'assets/tshirt.png'}" alt="">
        <small>${design.label}</small>
        <span class="tileMeta">$${design.price || 0}</span>
      `;
      div.onclick = () => selectMarketplaceDesign(design);
      grid.appendChild(div);
    });
  }
}

function selectTemplate(template) {
  state.selectedTemplate = template;
  $('details').innerHTML = `<b>${template.id}</b><br/>${template.label}<br/>Component: ${template.component}<br/>Drawable: ${template.drawable}`;
  $('activeTemplate').textContent = `${template.id} - 1024x1024`;
  renderSidebar();
  nui('previewClothing', { template });
}

function selectSavedDesign(design) {
  state.selectedSavedDesign = design;
  $('details').innerHTML = `<b>${design.design_id}</b><br/>${design.label}<br/>${design.gender} / ${design.category}`;
  renderSidebar();
}

function selectMarketplaceDesign(design) {
  state.selectedMarketplaceDesign = design;
  $('details').innerHTML = `<b>${design.design_id}</b><br/>${design.label}<br/>Creator: ${design.owner_name || 'Unknown'}<br/>${design.gender} / ${design.category}<br/>Price: $${design.price || 0}<br/>Sold: ${design.sold_count || 0}`;
  renderSidebar();
}

function findTemplate(gender, category, templateId) {
  const list = (((state.templates[gender] || {})[category]) || []);
  return list.find((t) => t.id === templateId) || null;
}

function selectedLayer() {
  return state.layers.find((layer) => layer.id === state.selectedLayer) || null;
}

function fillProps(layer) {
  if (!layer) return;
  propX.value = Math.round(layer.x || 0);
  propY.value = Math.round(layer.y || 0);
  propRot.value = Math.round(layer.rotation || 0);
  propOpacity.value = layer.opacity ?? 1;
  propBlend.value = layer.blend || 'source-over';
  propText.value = layer.type === 'text' ? (layer.text || '') : '';
  propColor.value = layer.color || '#d7ff00';
}

function renderLayers() {
  const wrap = $('layersList');
  $('layerCount').textContent = state.layers.length;

  if (!state.layers.length) {
    wrap.innerHTML = '<p class="muted">Még nincsenek rétegek</p>';
    return;
  }

  wrap.innerHTML = '';
  [...state.layers].reverse().forEach((layer) => {
    const div = document.createElement('div');
    div.className = 'layer' + (state.selectedLayer === layer.id ? ' active' : '');
    const status = layer.type === 'image'
      ? (layer.uploadState === 'uploading' ? 'uploading' : (layer.assetUrl ? 'cdn' : 'local'))
      : layer.type;
    div.innerHTML = `
      <div class="thumb" style="background-image:url(${layer.localSrc || layer.src || ''})"></div>
      <div class="layerInfo">
        <b>${layer.name || layer.type}</b>
        <small>${status}</small>
      </div>
      <div class="layerActions">
        <button data-action="toggle">${layer.visible ? '👁' : '🚫'}</button>
        <button data-action="up">↑</button>
        <button data-action="down">↓</button>
        <button data-action="dup">⧉</button>
        <button data-action="delete">✕</button>
      </div>
    `;

    div.onclick = (e) => {
      const action = e.target.dataset.action;
      if (action) {
        e.stopPropagation();
        handleLayerAction(layer.id, action);
        return;
      }
      state.selectedLayer = layer.id;
      fillProps(layer);
      drawUV();
    };

    wrap.appendChild(div);
  });
}

function moveLayer(id, direction) {
  const index = state.layers.findIndex((layer) => layer.id === id);
  if (index === -1) return;
  const target = direction === 'up' ? index + 1 : index - 1;
  if (target < 0 || target >= state.layers.length) return;
  [state.layers[index], state.layers[target]] = [state.layers[target], state.layers[index]];
}

function handleLayerAction(id, action) {
  const layer = state.layers.find((item) => item.id === id);
  if (!layer) return;
  pushHistory();

  if (action === 'toggle') {
    layer.visible = !layer.visible;
  } else if (action === 'delete') {
    state.layers = state.layers.filter((item) => item.id !== id);
    if (state.selectedLayer === id) state.selectedLayer = null;
  } else if (action === 'dup') {
    const copy = cloneLayers([stripRuntime(layer)])[0];
    copy.id = uid();
    copy.name = `${layer.name} Másolat`;
    copy.x = (copy.x || 0) + 24;
    copy.y = (copy.y || 0) + 24;
    state.layers.push(copy);
    state.selectedLayer = copy.id;
    reloadImages();
    return;
  } else if (action === 'up' || action === 'down') {
    moveLayer(id, action);
  }

  drawUV();
}

function addImage(src, options = {}) {
  const img = new Image();
  if (!isDataUrl(src)) img.crossOrigin = 'anonymous';

  img.onload = () => {
    pushHistory();
    const layer = {
      id: uid(),
      type: 'image',
      name: options.name || 'Kép Réteg',
      x: 512,
      y: 512,
      w: 360,
      h: Math.max(80, Math.round(360 * img.height / img.width)),
      rotation: 0,
      opacity: 1,
      blend: 'source-over',
      visible: true,
      src,
      localSrc: isDataUrl(src) ? src : null,
      assetUrl: options.assetUrl || null,
      uploadState: options.assetUrl ? 'cdn' : (isDataUrl(src) ? 'local' : 'remote'),
      uploadError: null,
      img,
      color: '#ffffff'
    };

    // JavaScript does not have nil; normalize for NUI runtime.
    layer.uploadError = null;

    state.layers.push(layer);
    state.selectedLayer = layer.id;
    fillProps(layer);
    drawUV();

    if (isDataUrl(src) && state.uploadBridge.enabled && state.uploadBridge.uploadLayerAssets) {
      startLayerAssetUpload(layer);
    }
  };

  img.onerror = () => {
    nui('notify', { message: 'Nem sikerült betölteni a képet.', type: 'error' });
  };

  img.src = src;
}


function addText() {
  pushHistory();
  const layer = {
    id: uid(),
    type: 'text',
    name: 'Szöveg Réteg',
    x: 512,
    y: 512,
    text: 'REALRPG',
    size: 72,
    color: brushColor.value,
    rotation: 0,
    opacity: 1,
    blend: 'source-over',
    visible: true,
  };
  state.layers.push(layer);
  state.selectedLayer = layer.id;
  fillProps(layer);
  drawUV();
}

function addShape() {
  pushHistory();
  const layer = {
    id: uid(),
    type: 'shape',
    name: 'Alakzat Réteg',
    x: 512,
    y: 512,
    w: 420,
    h: 260,
    color: brushColor.value,
    rotation: 0,
    opacity: 0.75,
    blend: 'source-over',
    visible: true,
  };
  state.layers.push(layer);
  state.selectedLayer = layer.id;
  fillProps(layer);
  drawUV();
}

function addBrushLayer(point) {
  pushHistory();
  const layer = {
    id: uid(),
    type: 'brush',
    name: 'Ecset Réteg',
    x: point.x,
    y: point.y,
    points: [point],
    color: brushColor.value,
    size: Number(brushSize.value),
    rotation: 0,
    opacity: 1,
    blend: 'source-over',
    visible: true,
  };
  state.layers.push(layer);
  state.selectedLayer = layer.id;
  fillProps(layer);
  return layer;
}

function canvasPoint(e) {
  const rect = canvas.getBoundingClientRect();
  const scaleX = canvas.width / rect.width;
  const scaleY = canvas.height / rect.height;
  return {
    x: (e.clientX - rect.left) * scaleX,
    y: (e.clientY - rect.top) * scaleY
  };
}

function layerBounds(layer) {
  if (layer.type === 'text') {
    const w = Math.max(120, (layer.text || 'TEXT').length * (layer.size || 72) * 0.7);
    const h = layer.size || 72;
    return { x: layer.x - w / 2, y: layer.y - h / 2, w, h };
  }
  if (layer.type === 'brush') {
    const points = layer.points || [];
    const xs = points.map((p) => p.x);
    const ys = points.map((p) => p.y);
    return {
      x: Math.min(...xs, layer.x) - 20,
      y: Math.min(...ys, layer.y) - 20,
      w: Math.max(...xs, layer.x) - Math.min(...xs, layer.x) + 40,
      h: Math.max(...ys, layer.y) - Math.min(...ys, layer.y) + 40,
    };
  }
  return {
    x: (layer.x || 0) - (layer.w || 100) / 2,
    y: (layer.y || 0) - (layer.h || 100) / 2,
    w: layer.w || 100,
    h: layer.h || 100,
  };
}

function hitTest(point) {
  for (let i = state.layers.length - 1; i >= 0; i--) {
    const layer = state.layers[i];
    if (!layer.visible) continue;
    const bounds = layerBounds(layer);
    if (point.x >= bounds.x && point.x <= bounds.x + bounds.w && point.y >= bounds.y && point.y <= bounds.y + bounds.h) {
      return layer;
    }
  }
  return null;
}

function applyPropChanges() {
  const layer = selectedLayer();
  if (!layer) return;
  layer.x = Number(propX.value);
  layer.y = Number(propY.value);
  layer.rotation = Number(propRot.value);
  layer.opacity = Number(propOpacity.value);
  layer.blend = propBlend.value;
  if (layer.type === 'text') layer.text = propText.value;
  if (layer.type === 'text' || layer.type === 'shape' || layer.type === 'brush') layer.color = propColor.value;
  drawUV();
}

function reloadImages(callback) {
  let pending = 0;
  state.layers.forEach((layer) => {
    const imageSource = layer.localSrc || layer.src || layer.assetUrl;
    if (layer.type === 'image' && imageSource) {
      pending++;
      layer.img = new Image();
      if (!isDataUrl(imageSource)) layer.img.crossOrigin = 'anonymous';
      layer.img.onload = () => {
        pending--;
        if (pending <= 0) {
          drawUV();
          if (callback) callback();
        }
      };
      layer.img.onerror = () => {
        pending--;
        if (pending <= 0) {
          drawUV();
          if (callback) callback();
        }
      };
      layer.img.src = imageSource;
    }
  });

  if (!pending) {
    drawUV();
    if (callback) callback();
  }
}

function loadDesignIntoEditor(payload) {
  if (!payload) return;
  state.gender = payload.gender || 'male';
  state.category = payload.category || 'tops';
  state.currentDesignId = payload.design_id;
  $('designName').textContent = payload.label || 'Untitled Design';

  document.querySelectorAll('.genderBtn').forEach((el) => el.classList.toggle('active', el.dataset.gender === state.gender));
  document.querySelectorAll('.cat').forEach((el) => el.classList.toggle('active', el.dataset.cat === state.category));

  state.selectedTemplate = findTemplate(state.gender, state.category, payload.template_id);
  if (state.selectedTemplate) {
    $('activeTemplate').textContent = `${state.selectedTemplate.id} - 1024x1024`;
    $('details').innerHTML = `<b>${state.selectedTemplate.id}</b><br/>${state.selectedTemplate.label}<br/>Component: ${state.selectedTemplate.component}<br/>Drawable: ${state.selectedTemplate.drawable}`;
    nui('previewClothing', { template: state.selectedTemplate });
  }

  const layers = (payload.design && Array.isArray(payload.design.layers)) ? payload.design.layers : [];
  state.layers = layers.map((layer) => ({ ...layer }));
  state.selectedLayer = state.layers.length ? state.layers[state.layers.length - 1].id : null;
  renderSidebar();
  reloadImages(() => fillProps(selectedLayer()));
}


function startLayerAssetUpload(layer) {
  if (!layer || layer.type !== 'image' || layer.assetUrl || !isDataUrl(layer.localSrc || layer.src)) return Promise.resolve(layer && layer.assetUrl);

  layer.uploadState = 'uploading';
  layer.uploadError = null;
  drawUV();

  layer.uploadPromise = uploadDataUrlChunked(layer.localSrc || layer.src, 'layer_asset')
    .then((url) => {
      if (!url) throw new Error('missing_asset_url');
      layer.assetUrl = url;
      layer.src = url;
      layer.uploadState = 'cdn';
      layer.uploadError = null;
      drawUV();
      return url;
    })
    .catch((error) => {
      layer.uploadState = 'failed';
      layer.uploadError = error.message || String(error);
      drawUV();
      nui('notify', { message: `Kép réteg feltöltése sikertelen: ${layer.uploadError}`, type: 'error' });
      if (state.uploadBridge.failLayerUploadIfUploadFails) throw error;
      return null;
    });

  return layer.uploadPromise;
}

async function ensureLayerAssetsUploaded() {
  if (!state.uploadBridge.enabled || !state.uploadBridge.uploadLayerAssets) return;

  const jobs = [];
  for (const layer of state.layers) {
    if (layer.type !== 'image') continue;
    if (layer.assetUrl) continue;
    if (layer.uploadPromise) jobs.push(layer.uploadPromise);
    else if (isDataUrl(layer.localSrc || layer.src)) jobs.push(startLayerAssetUpload(layer));
  }

  if (!jobs.length) return;
  nui('notify', { message: `Kép rétegek feltöltése (${jobs.length})...`, type: 'info' });
  await Promise.all(jobs);
}

function uploadDataUrlChunked(dataUrl, kind = 'design') {
  if (!state.uploadBridge.enabled) return Promise.resolve(null);

  const uploadId = `up_${Date.now()}_${Math.random().toString(36).slice(2)}`;
  const chunkSize = Number(state.uploadBridge.chunkSize || 240000);

  return new Promise(async (resolve, reject) => {
    state.pendingUploads[uploadId] = { resolve, reject };

    await nui('uploadBegin', { uploadId, total: dataUrl.length, kind });

    let index = 1;
    for (let offset = 0; offset < dataUrl.length; offset += chunkSize) {
      await nui('uploadChunk', {
        uploadId,
        index,
        chunk: dataUrl.slice(offset, offset + chunkSize)
      });
      index++;
    }

    await nui('uploadFinish', { uploadId });

    setTimeout(() => {
      if (state.pendingUploads[uploadId]) {
        delete state.pendingUploads[uploadId];
        reject(new Error('upload_timeout'));
      }
    }, 70000);
  });
}

async function buildSavePayload(label) {
  await ensureLayerAssetsUploaded();

  const dataUrl = safeCanvasDataUrl();
  let preview = dataUrl;
  let imageUrl = null;

  if (state.uploadBridge.enabled && dataUrl) {
    try {
      nui('notify', { message: 'Design feltöltése CDN-re...', type: 'info' });
      imageUrl = await uploadDataUrlChunked(dataUrl, 'design_final');
      preview = imageUrl || dataUrl;
    } catch (error) {
      nui('notify', { message: `Feltöltési hiba: ${error.message || error}`, type: 'error' });
      if (state.uploadBridge.failSaveIfUploadFails) throw error;
    }
  }

  if (!preview) {
    const firstAsset = state.layers.find((layer) => layer.type === 'image' && layer.assetUrl);
    preview = firstAsset ? firstAsset.assetUrl : null;
  }

  return {
    label,
    gender: state.gender,
    category: state.category,
    templateId: state.selectedTemplate.id,
    design: { layers: state.layers.map(stripRuntime) },
    preview,
    imageUrl
  };
}

$('closeBtn').onclick = () => { app.classList.add('hidden'); nui('close'); };
$('newBtn').onclick = () => { resetCanvasState(); drawUV(); };
$('saveBtn').onclick = async () => {
  if (!state.selectedTemplate) return nui('notify', { message: 'Válassz sablont először.', type: 'error' });
  const label = prompt('Design neve:', $('designName').textContent || 'Névtelen Design') || 'Névtelen Design';
  $('designName').textContent = label;

  try {
    const payload = await buildSavePayload(label);
    nui('saveDesign', payload);
  } catch (_) {
    nui('notify', { message: `A design mentése megszakadt feltöltési hiba miatt.`, type: 'error' });
  }
};
$('printBtn').onclick = () => {
  if (!state.currentDesignId) return nui('notify', { message: 'Először mentsd el a designt.', type: 'error' });
  nui('printDesign', { designId: state.currentDesignId });
};
$('readyBtn').onclick = () => $('printBtn').click();
$('useTemplate').onclick = () => { if (state.selectedTemplate) nui('previewClothing', { template: state.selectedTemplate }); };
$('loadDesignBtn').onclick = () => {
  if (!state.selectedSavedDesign) return nui('notify', { message: 'Válassz egy mentett designt.', type: 'error' });
  nui('loadDesign', { designId: state.selectedSavedDesign.design_id });
};

$('publishDesignBtn').onclick = () => {
  const designId = state.selectedSavedDesign?.design_id || state.currentDesignId;
  if (!designId) return nui('notify', { message: 'Először válassz vagy ments el egy designt.', type: 'error' });
  const priceRaw = prompt('Piactéri ár:', '5000');
  if (priceRaw === null) return;
  const price = Number(priceRaw);
  if (!Number.isFinite(price) || price <= 0) return nui('notify', { message: 'Érvénytelen ár.', type: 'error' });
  nui('publishDesign', { designId, price });
};
$('unpublishDesignBtn').onclick = () => {
  const designId = state.selectedSavedDesign?.design_id || state.currentDesignId;
  if (!designId) return nui('notify', { message: 'Válassz egy publikált designt.', type: 'error' });
  nui('unpublishDesign', { designId });
};
$('buyMarketBtn').onclick = () => {
  if (!state.selectedMarketplaceDesign) return nui('notify', { message: 'Válassz egy piactéri ruhát.', type: 'error' });
  const ok = confirm(`Megveszed és kinyomtatod: ${state.selectedMarketplaceDesign.label} ($${state.selectedMarketplaceDesign.price})?`);
  if (!ok) return;
  nui('buyMarketplaceDesign', { designId: state.selectedMarketplaceDesign.design_id });
};
$('imageBtn').onclick = () => $('fileInput').click();
$('textBtn').onclick = addText;
$('shapeBtn').onclick = addShape;
$('pasteBtn').onclick = async () => {
  if (!navigator.clipboard || !navigator.clipboard.read) {
    nui('notify', { message: 'A vágólap beillesztés nem támogatott.', type: 'error' });
    return;
  }
  try {
    const items = await navigator.clipboard.read();
    for (const item of items) {
      const imageType = item.types.find((type) => type.startsWith('image/'));
      if (!imageType) continue;
      const blob = await item.getType(imageType);
      const reader = new FileReader();
      reader.onload = () => addImage(reader.result);
      reader.readAsDataURL(blob);
      return;
    }
  } catch (_) {
    nui('notify', { message: 'Nem sikerült a beillesztés.', type: 'error' });
  }
};
$('undoBtn').onclick = () => {
  if (!state.history.length) return;
  state.redo.push(JSON.stringify(state.layers.map(stripRuntime)));
  state.layers = JSON.parse(state.history.pop());
  reloadImages();
};
$('redoBtn').onclick = () => {
  if (!state.redo.length) return;
  state.history.push(JSON.stringify(state.layers.map(stripRuntime)));
  state.layers = JSON.parse(state.redo.pop());
  reloadImages();
};
$('fileInput').onchange = (e) => {
  const file = e.target.files[0];
  if (!file) return;
  if (file.size > (state.maxUploadMB * 1024 * 1024)) {
    nui('notify', { message: `Maximum ${state.maxUploadMB} MB fájl tölthető fel.`, type: 'error' });
    return;
  }
  const reader = new FileReader();
  reader.onload = () => addImage(reader.result);
  reader.readAsDataURL(file);
  e.target.value = '';
};
$('gridBtn').onclick = () => { state.gridEnabled = !state.gridEnabled; $('gridBtn').classList.toggle('active', state.gridEnabled); drawUV(); };
$('mirrorBtn').onclick = () => { state.mirrorEnabled = !state.mirrorEnabled; $('mirrorBtn').classList.toggle('active', state.mirrorEnabled); drawUV(); };
$('lockBtn').onclick = () => { $('lockBtn').classList.toggle('active'); nui('notify', { message: 'UV zárolás vizuális jelző.', type: 'info' }); };

propX.oninput = applyPropChanges;
propY.oninput = applyPropChanges;
propRot.oninput = applyPropChanges;
propOpacity.oninput = applyPropChanges;
propBlend.oninput = applyPropChanges;
propText.oninput = applyPropChanges;
propColor.oninput = applyPropChanges;
brushColor.oninput = () => { if (selectedLayer()) applyPropChanges(); };
searchInput.oninput = () => {
  if (state.activeTab === 'marketplace') nui('refreshMarketplace', { gender: state.gender, category: state.category, search: searchInput.value.trim() });
  renderSidebar();
};

document.querySelectorAll('.cat').forEach((button) => {
  button.onclick = () => {
    document.querySelectorAll('.cat').forEach((el) => el.classList.remove('active'));
    button.classList.add('active');
    state.category = button.dataset.cat;
    if (state.activeTab === 'marketplace') nui('refreshMarketplace', { gender: state.gender, category: state.category, search: searchInput.value.trim() });
    renderSidebar();
  };
});

document.querySelectorAll('.genderBtn').forEach((button) => {
  button.onclick = () => {
    document.querySelectorAll('.genderBtn').forEach((el) => el.classList.remove('active'));
    button.classList.add('active');
    state.gender = button.dataset.gender;
    if (state.activeTab === 'marketplace') nui('refreshMarketplace', { gender: state.gender, category: state.category, search: searchInput.value.trim() });
    renderSidebar();
  };
});

document.querySelectorAll('.tab').forEach((button) => {
  button.onclick = () => setActiveTab(button.dataset.tab);
});

document.querySelectorAll('.tabAction').forEach((button) => {
  button.onclick = () => {
    document.querySelectorAll('.tabAction').forEach((el) => el.classList.remove('active'));
    button.classList.add('active');
    state.currentMode = button.dataset.mode;
  };
});

canvas.addEventListener('mousedown', (e) => {
  e.preventDefault();
  const point = canvasPoint(e);

  if (state.currentMode === 'brush') {
    state.drawing = true;
    const layer = addBrushLayer(point);
    state.dragging = { type: 'brush', layerId: layer.id };
    drawUV();
    return;
  }

  const hit = hitTest(point);
  if (hit) {
    pushHistory();
    state.selectedLayer = hit.id;
    fillProps(hit);
    state.dragging = { type: 'move', layerId: hit.id, offsetX: point.x - hit.x, offsetY: point.y - hit.y };
    drawUV();
  }
});

// Scroll = méretezés, Shift+Scroll = forgatás (kijelölt layeren)
canvas.addEventListener('wheel', (e) => {
  e.preventDefault();
  const layer = selectedLayer();
  if (!layer) return;

  pushHistory();
  const delta = e.deltaY > 0 ? -1 : 1;

  if (e.shiftKey) {
    // Forgatás: Shift + scroll
    layer.rotation = (layer.rotation || 0) + delta * 5;
  } else {
    // Méretezés: scroll
    const scaleFactor = 1 + delta * 0.08;
    if (layer.type === 'text') {
      layer.size = Math.max(8, Math.round((layer.size || 72) * scaleFactor));
    } else {
      layer.w = Math.max(20, Math.round((layer.w || 100) * scaleFactor));
      layer.h = Math.max(20, Math.round((layer.h || 100) * scaleFactor));
    }
  }

  fillProps(layer);
  drawUV();
}, { passive: false });

canvas.addEventListener('mousemove', (e) => {
  if (!state.dragging) return;
  e.preventDefault();
  const point = canvasPoint(e);

  if (state.currentMode === 'brush' && state.drawing && state.dragging) {
    const layer = state.layers.find((item) => item.id === state.dragging.layerId);
    if (!layer) return;
    layer.points.push(point);
    drawUV();
    return;
  }

  if (state.dragging && state.dragging.type === 'move') {
    const layer = state.layers.find((item) => item.id === state.dragging.layerId);
    if (!layer) return;
    layer.x = point.x - state.dragging.offsetX;
    layer.y = point.y - state.dragging.offsetY;
    fillProps(layer);
    drawUV();
  }
});

window.addEventListener('mouseup', () => {
  if (state.drawing || state.dragging) {
    state.drawing = false;
    state.dragging = null;
  }
});

window.addEventListener('paste', (event) => {
  const items = event.clipboardData?.items || [];
  for (const item of items) {
    if (item.type.startsWith('image/')) {
      const file = item.getAsFile();
      const reader = new FileReader();
      reader.onload = () => addImage(reader.result);
      reader.readAsDataURL(file);
      event.preventDefault();
      break;
    }
  }
});

window.addEventListener('message', (e) => {
  const msg = e.data || {};

  if (msg.action === 'open') {
    app.classList.remove('hidden');
    state.templates = msg.data.templates || {};
    state.myDesigns = msg.data.myDesigns || [];
    state.marketplace = msg.data.marketplace || [];
    state.marketplaceEnabled = !!msg.data.marketplaceEnabled;
    state.maxUploadMB = msg.data.maxUploadMB || 4;
    state.uploadBridge = msg.data.uploadBridge || { enabled: false, chunkSize: 240000, failSaveIfUploadFails: false, uploadLayerAssets: false, failLayerUploadIfUploadFails: false };
    resetCanvasState();
    setActiveTab('library');
    drawUV();
  }

  if (msg.action === 'designSaved') {
    state.currentDesignId = msg.design.design_id;
    const existingIndex = state.myDesigns.findIndex((d) => d.design_id === msg.design.design_id);
    const summary = {
      design_id: msg.design.design_id,
      label: msg.design.label,
      gender: msg.design.gender,
      category: msg.design.category,
      template_id: msg.design.template_id,
      preview_data: msg.design.preview_data,
      image_url: msg.design.image_url
    };
    if (existingIndex >= 0) state.myDesigns[existingIndex] = summary;
    else state.myDesigns.unshift(summary);
    nui('notify', { message: `Design elmentve: ${msg.design.label}`, type: 'success' });
    renderSidebar();
  }



  if (msg.action === 'uploadResult') {
    const result = msg.result || {};
    const pending = state.pendingUploads[result.uploadId];
    if (pending) {
      delete state.pendingUploads[result.uploadId];
      if (result.ok && result.url) pending.resolve(result.url);
      else pending.reject(new Error(result.error || 'upload_failed'));
    }
  }

  if (msg.action === 'marketplaceData') {
    state.marketplace = msg.marketplace || [];
    if (state.activeTab === 'marketplace') renderSidebar();
  }

  if (msg.action === 'marketplaceChanged') {
    nui('refreshMarketplace', { gender: state.gender, category: state.category, search: searchInput.value.trim() });
  }

  if (msg.action === 'loadDesign') {
    loadDesignIntoEditor(msg.design);
    nui('notify', { message: `Design betöltve: ${msg.design.label}`, type: 'success' });
  }
});

drawUV();
