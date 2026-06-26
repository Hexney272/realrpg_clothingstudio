/*
    RealRPG Clothing Studio - NUI App v1.2.0
    Canvas-based UV editor with layer system, props support, pack export
*/

const app = document.getElementById('app');
const canvas = document.getElementById('uvCanvas');
const ctx = canvas.getContext('2d');
let resource = 'realrpg_clothingstudio';

let state = {
    templates: {},
    categories: {},
    myDesigns: [],
    gender: 'male',
    category: 'tops',
    selectedTemplate: null,
    layers: [],
    selectedLayer: null,
    history: [],
    redo: [],
    currentDesignId: null,
    renderMode: 'runtime',
    packExportEnabled: false,
    marketplaceEnabled: false,
    // Pack export selection
    selectedForExport: new Set(),
};

// ═══════════════════════════════════════════════════════════════
// UTILITIES
// ═══════════════════════════════════════════════════════════════

function nui(name, data = {}) {
    const resName = typeof GetParentResourceName === 'function' ? GetParentResourceName() : resource;
    return fetch(`https://${resName}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data)
    }).catch(() => {});
}

function uid() { return 'l_' + Math.random().toString(36).slice(2) + Date.now(); }

function pushHistory() {
    state.history.push(JSON.stringify(state.layers));
    if (state.history.length > 40) state.history.shift();
    state.redo = [];
}

// ═══════════════════════════════════════════════════════════════
// CATEGORY SYSTEM (Components + Props)
// ═══════════════════════════════════════════════════════════════

const ALL_CATEGORIES = [
    // Components
    { key: 'tops', label: 'TOPS', type: 'component' },
    { key: 'undershirt', label: 'UNDER', type: 'component' },
    { key: 'pants', label: 'PANTS', type: 'component' },
    { key: 'shoes', label: 'SHOES', type: 'component' },
    { key: 'torso', label: 'TORSO', type: 'component' },
    { key: 'bags', label: 'BAGS', type: 'component' },
    { key: 'accessories', label: 'ACC', type: 'component' },
    { key: 'armor', label: 'ARMOR', type: 'component' },
    { key: 'decals', label: 'DECALS', type: 'component' },
    // Props
    { key: 'hats', label: 'HATS', type: 'prop' },
    { key: 'glasses', label: 'GLASS', type: 'prop' },
    { key: 'ears', label: 'EARS', type: 'prop' },
    { key: 'watches', label: 'WATCH', type: 'prop' },
    { key: 'bracelets', label: 'BRACE', type: 'prop' },
];

function renderCategories() {
    const container = document.querySelector('.categories');
    container.innerHTML = '';

    // Component categories
    const compDiv = document.createElement('div');
    compDiv.className = 'cat-group';
    compDiv.innerHTML = '<small class="cat-label">COMPONENTS</small>';

    const propDiv = document.createElement('div');
    propDiv.className = 'cat-group';
    propDiv.innerHTML = '<small class="cat-label">PROPS</small>';

    ALL_CATEGORIES.forEach(cat => {
        const btn = document.createElement('button');
        btn.className = 'cat' + (state.category === cat.key ? ' active' : '');
        btn.dataset.cat = cat.key;
        btn.textContent = cat.label;
        btn.onclick = () => {
            state.category = cat.key;
            renderCategories();
            renderTemplates();
        };
        if (cat.type === 'component') {
            compDiv.appendChild(btn);
        } else {
            propDiv.appendChild(btn);
        }
    });

    container.appendChild(compDiv);
    container.appendChild(propDiv);
}

// ═══════════════════════════════════════════════════════════════
// CANVAS RENDERING
// ═══════════════════════════════════════════════════════════════

function drawUV() {
    ctx.clearRect(0, 0, 1024, 1024);
    ctx.fillStyle = '#f7f7f7';
    ctx.fillRect(0, 0, 1024, 1024);

    // Grid
    ctx.strokeStyle = 'rgba(0,0,0,.08)';
    ctx.lineWidth = 1;
    for (let i = 0; i < 1024; i += 64) {
        ctx.beginPath(); ctx.moveTo(i, 0); ctx.lineTo(i, 1024); ctx.stroke();
        ctx.beginPath(); ctx.moveTo(0, i); ctx.lineTo(1024, i); ctx.stroke();
    }

    // UV guide lines
    ctx.strokeStyle = 'rgba(0,0,0,.06)';
    ctx.setLineDash([4, 4]);
    ctx.beginPath(); ctx.moveTo(512, 0); ctx.lineTo(512, 1024); ctx.stroke();
    ctx.beginPath(); ctx.moveTo(0, 512); ctx.lineTo(1024, 512); ctx.stroke();
    ctx.setLineDash([]);

    // Render layers
    for (const l of state.layers) {
        if (!l.visible) continue;
        ctx.save();
        ctx.globalAlpha = l.opacity ?? 1;
        ctx.globalCompositeOperation = l.blend || 'source-over';
        ctx.translate(l.x, l.y);
        ctx.rotate((l.rotation || 0) * Math.PI / 180);

        if (l.type === 'image' && l.img) {
            ctx.drawImage(l.img, -l.w / 2, -l.h / 2, l.w, l.h);
        }
        if (l.type === 'text') {
            ctx.fillStyle = l.color || '#111';
            ctx.font = `${l.size || 64}px Arial Black`;
            ctx.textAlign = 'center';
            ctx.textBaseline = 'middle';
            ctx.fillText(l.text || 'TEXT', 0, 0);
        }
        if (l.type === 'shape') {
            ctx.fillStyle = l.color || '#d7ff00';
            if (l.shape === 'circle') {
                ctx.beginPath();
                ctx.ellipse(0, 0, l.w / 2, l.h / 2, 0, 0, Math.PI * 2);
                ctx.fill();
            } else {
                ctx.fillRect(-l.w / 2, -l.h / 2, l.w, l.h);
            }
        }
        ctx.restore();
    }

    updateShirtPreview();
    renderLayers();
}

function updateShirtPreview() {
    const el = document.getElementById('shirtDesign');
    if (el) el.style.backgroundImage = `url(${canvas.toDataURL('image/png')})`;
}

// ═══════════════════════════════════════════════════════════════
// TEMPLATE GRID
// ═══════════════════════════════════════════════════════════════

function renderTemplates() {
    const grid = document.getElementById('templateGrid');
    grid.innerHTML = '';
    const templates = state.templates[state.gender];
    const list = (templates && templates[state.category]) || [];
    document.getElementById('count').textContent = list.length + ' ITEMS';

    list.forEach(t => {
        const div = document.createElement('div');
        div.className = 'tile' + (state.selectedTemplate?.id === t.id ? ' selected' : '');
        const isPropBadge = t.isProp ? '<span class="prop-badge">P</span>' : '';
        div.innerHTML = `<img src="${t.preview || 'assets/tshirt.png'}" alt="${t.label}">${isPropBadge}<small>${t.label}</small>`;
        div.onclick = () => selectTemplate(t);
        grid.appendChild(div);
    });
}

function selectTemplate(t) {
    state.selectedTemplate = t;
    const isProp = t.isProp || t.prop !== undefined;
    const typeLabel = isProp ? 'Prop' : 'Component';
    const idValue = isProp ? t.prop : t.component;

    document.getElementById('details').innerHTML = `
        <b>${t.id}</b><br/>
        ${t.label}<br/>
        Type: ${typeLabel}<br/>
        ${typeLabel} ID: ${idValue}<br/>
        Drawable: ${t.drawable}
    `;
    document.getElementById('activeTemplate').textContent = `${t.id} - 1024x1024`;
    renderTemplates();
    nui('previewClothing', { template: t });
}

// ═══════════════════════════════════════════════════════════════
// LAYER MANAGEMENT
// ═══════════════════════════════════════════════════════════════

function renderLayers() {
    const wrap = document.getElementById('layersList');
    document.getElementById('layerCount').textContent = state.layers.length;

    if (!state.layers.length) {
        wrap.innerHTML = '<p class="muted">No layers yet</p>';
        return;
    }

    wrap.innerHTML = '';
    [...state.layers].reverse().forEach(l => {
        const div = document.createElement('div');
        div.className = 'layer' + (state.selectedLayer === l.id ? ' active' : '');
        div.innerHTML = `
            <div class="thumb" style="background-image:url(${l.src || ''})"></div>
            <b>${l.name || l.type}</b>
            <span class="layer-actions">
                <button class="layer-vis" data-id="${l.id}">${l.visible ? '&#128065;' : '&mdash;'}</button>
                <button class="layer-del" data-id="${l.id}">&times;</button>
            </span>
        `;
        div.onclick = (e) => {
            if (e.target.classList.contains('layer-vis')) {
                l.visible = !l.visible;
                drawUV();
                return;
            }
            if (e.target.classList.contains('layer-del')) {
                pushHistory();
                state.layers = state.layers.filter(x => x.id !== l.id);
                if (state.selectedLayer === l.id) state.selectedLayer = null;
                drawUV();
                return;
            }
            state.selectedLayer = l.id;
            fillProps(l);
            drawUV();
        };
        wrap.appendChild(div);
    });
}

function fillProps(l) {
    document.getElementById('propX').value = Math.round(l.x || 0);
    document.getElementById('propY').value = Math.round(l.y || 0);
    document.getElementById('propRot').value = Math.round(l.rotation || 0);
    document.getElementById('propOpacity').value = l.opacity ?? 1;
    document.getElementById('propBlend').value = l.blend || 'source-over';
}

function selected() {
    return state.layers.find(l => l.id === state.selectedLayer);
}

// ═══════════════════════════════════════════════════════════════
// ADD LAYERS
// ═══════════════════════════════════════════════════════════════

function addImage(src) {
    const img = new Image();
    img.onload = () => {
        pushHistory();
        const l = {
            id: uid(), type: 'image', name: 'Image Layer',
            x: 512, y: 512, w: 360, h: Math.round(360 * img.height / img.width),
            rotation: 0, opacity: 1, blend: 'source-over', visible: true, src, img
        };
        state.layers.push(l);
        state.selectedLayer = l.id;
        drawUV();
    };
    img.src = src;
}

function addText() {
    const text = prompt('Szöveg:', 'REALRPG') || 'REALRPG';
    pushHistory();
    const l = {
        id: uid(), type: 'text', name: 'Text: ' + text.substring(0, 12),
        x: 512, y: 512, text, size: 72, color: '#111',
        rotation: 0, opacity: 1, blend: 'source-over', visible: true
    };
    state.layers.push(l);
    state.selectedLayer = l.id;
    drawUV();
}

function addShape() {
    pushHistory();
    const l = {
        id: uid(), type: 'shape', name: 'Shape Layer', shape: 'rect',
        x: 512, y: 512, w: 420, h: 260, color: '#d7ff00',
        rotation: 0, opacity: 0.75, blend: 'source-over', visible: true
    };
    state.layers.push(l);
    state.selectedLayer = l.id;
    drawUV();
}

// ═══════════════════════════════════════════════════════════════
// PACK EXPORT UI
// ═══════════════════════════════════════════════════════════════

function renderMyDesigns() {
    const grid = document.getElementById('templateGrid');
    grid.innerHTML = '';

    if (!state.myDesigns.length) {
        grid.innerHTML = '<p class="muted">Nincsenek mentett designok</p>';
        return;
    }

    document.getElementById('count').textContent = state.myDesigns.length + ' DESIGNS';

    state.myDesigns.forEach(d => {
        const div = document.createElement('div');
        const isSelected = state.selectedForExport.has(d.design_id);
        div.className = 'tile' + (isSelected ? ' selected' : '');
        const preview = d.image_url || d.preview_data || 'assets/tshirt.png';
        div.innerHTML = `
            <img src="${preview}" alt="${d.label}">
            <small>${d.label}</small>
            ${state.packExportEnabled ? `<input type="checkbox" class="export-check" data-id="${d.design_id}" ${isSelected ? 'checked' : ''}>` : ''}
        `;
        div.onclick = (e) => {
            if (e.target.classList.contains('export-check')) {
                if (e.target.checked) {
                    state.selectedForExport.add(d.design_id);
                } else {
                    state.selectedForExport.delete(d.design_id);
                }
                updateExportBtn();
                return;
            }
            // Load design into editor
            state.currentDesignId = d.design_id;
            document.getElementById('designName').textContent = d.label;
        };
        grid.appendChild(div);
    });

    updateExportBtn();
}

function updateExportBtn() {
    const btn = document.getElementById('exportPackBtn');
    if (!btn) return;
    const count = state.selectedForExport.size;
    btn.textContent = count > 0 ? `EXPORT PACK (${count})` : 'EXPORT PACK';
    btn.disabled = count === 0;
}

function exportPack() {
    if (state.selectedForExport.size === 0) {
        alert('Jelölj ki legalább egy designt az exporthoz!');
        return;
    }
    const name = prompt('Pack neve:', 'My Clothing Pack') || 'My Clothing Pack';
    nui('exportPack', {
        name,
        designIds: Array.from(state.selectedForExport)
    });
}

// ═══════════════════════════════════════════════════════════════
// EVENT HANDLERS
// ═══════════════════════════════════════════════════════════════

// Close
document.getElementById('closeBtn').onclick = () => {
    app.classList.add('hidden');
    nui('close');
};

// Gender buttons
document.querySelectorAll('.genderBtn').forEach(b => b.onclick = () => {
    document.querySelectorAll('.genderBtn').forEach(x => x.classList.remove('active'));
    b.classList.add('active');
    state.gender = b.dataset.gender;
    renderTemplates();
});

// Use template
document.getElementById('useTemplate').onclick = () => {
    if (state.selectedTemplate) nui('previewClothing', { template: state.selectedTemplate });
};

// Image upload
document.getElementById('imageBtn').onclick = () => document.getElementById('fileInput').click();
document.getElementById('fileInput').onchange = e => {
    const f = e.target.files[0];
    if (!f) return;
    if (f.size > 4 * 1024 * 1024) { alert('Maximum 4 MB.'); return; }
    const r = new FileReader();
    r.onload = () => addImage(r.result);
    r.readAsDataURL(f);
    e.target.value = '';
};

// Text & Shape
document.querySelector('[data-mode="text"]').onclick = addText;
document.getElementById('addShapeBtn').onclick = addShape;

// Save
document.getElementById('saveBtn').onclick = () => {
    if (!state.selectedTemplate) { alert('Válassz sablont!'); return; }
    const label = prompt('Design neve:', document.getElementById('designName').textContent || 'Untitled Design') || 'Untitled Design';
    document.getElementById('designName').textContent = label;
    nui('saveDesign', {
        label,
        gender: state.gender,
        category: state.category,
        templateId: state.selectedTemplate.id,
        design: { layers: state.layers.map(l => ({ ...l, img: undefined })) },
        preview: canvas.toDataURL('image/png')
    });
};

// Print
document.getElementById('printBtn').onclick = () => {
    if (!state.currentDesignId) { alert('Először mentsd el a designt.'); return; }
    if (!confirm(`Biztosan kinyomtatod? Ár: $${2500}`)) return;
    nui('printDesign', { designId: state.currentDesignId });
};

document.getElementById('readyBtn').onclick = () => document.getElementById('printBtn').click();

// Undo / Redo
document.getElementById('undoBtn').onclick = () => {
    if (!state.history.length) return;
    state.redo.push(JSON.stringify(state.layers));
    state.layers = JSON.parse(state.history.pop());
    reloadImages();
};

document.getElementById('redoBtn').onclick = () => {
    if (!state.redo.length) return;
    state.history.push(JSON.stringify(state.layers));
    state.layers = JSON.parse(state.redo.pop());
    reloadImages();
};

// Layer properties
['propX', 'propY', 'propRot', 'propOpacity', 'propBlend'].forEach(id => {
    document.getElementById(id).oninput = () => {
        const l = selected();
        if (!l) return;
        l.x = +document.getElementById('propX').value;
        l.y = +document.getElementById('propY').value;
        l.rotation = +document.getElementById('propRot').value;
        l.opacity = +document.getElementById('propOpacity').value;
        l.blend = document.getElementById('propBlend').value;
        drawUV();
    };
});

// Tabs (Library / My Designs)
document.querySelectorAll('.tab').forEach(tab => {
    tab.onclick = () => {
        document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
        tab.classList.add('active');
        if (tab.dataset.tab === 'my') {
            renderMyDesigns();
        } else {
            renderTemplates();
        }
    };
});

// Export Pack button
const exportBtn = document.getElementById('exportPackBtn');
if (exportBtn) exportBtn.onclick = exportPack;

// ═══════════════════════════════════════════════════════════════
// IMAGE RELOAD (after undo/redo)
// ═══════════════════════════════════════════════════════════════

function reloadImages() {
    let pending = 0;
    state.layers.forEach(l => {
        if (l.type === 'image' && l.src) {
            pending++;
            l.img = new Image();
            l.img.onload = () => { if (--pending <= 0) drawUV(); };
            l.img.onerror = () => { if (--pending <= 0) drawUV(); };
            l.img.src = l.src;
        }
    });
    if (!pending) drawUV();
}

// ═══════════════════════════════════════════════════════════════
// NUI MESSAGE HANDLER
// ═══════════════════════════════════════════════════════════════

window.addEventListener('message', e => {
    const msg = e.data || {};

    if (msg.action === 'open') {
        app.classList.remove('hidden');
        state.templates = msg.data.templates || {};
        state.categories = msg.data.categories || {};
        state.myDesigns = msg.data.myDesigns || [];
        state.renderMode = msg.data.renderMode || 'runtime';
        state.packExportEnabled = msg.data.packExportEnabled || false;
        state.marketplaceEnabled = msg.data.marketplaceEnabled || false;
        state.selectedForExport = new Set();
        state.currentDesignId = null;

        renderCategories();
        renderTemplates();
        drawUV();

        // Show/hide export button
        const exportBtn = document.getElementById('exportPackBtn');
        if (exportBtn) {
            exportBtn.style.display = state.packExportEnabled ? 'inline-block' : 'none';
        }
    }

    if (msg.action === 'designSaved') {
        state.currentDesignId = msg.design.design_id;
        // Add to my designs list
        state.myDesigns.unshift(msg.design);
        alert('Design elmentve: ' + msg.design.label);
    }

    if (msg.action === 'designDeleted') {
        state.myDesigns = state.myDesigns.filter(d => d.design_id !== msg.designId);
        state.selectedForExport.delete(msg.designId);
        if (state.currentDesignId === msg.designId) state.currentDesignId = null;
    }

    if (msg.action === 'packExported') {
        state.selectedForExport = new Set();
        alert(`Pack exportálva: ${msg.data.name}\n${msg.data.designCount} design, ${msg.data.fileCount} fájl`);
        updateExportBtn();
    }

    if (msg.action === 'uploadResult') {
        if (msg.data && msg.data.ok && msg.data.url) {
            // Could update preview with CDN URL
            console.log('Upload sikeres:', msg.data.url);
        }
    }

    if (msg.action === 'forceClose') {
        app.classList.add('hidden');
    }
});

// ═══════════════════════════════════════════════════════════════
// KEYBOARD SHORTCUTS
// ═══════════════════════════════════════════════════════════════

document.addEventListener('keydown', e => {
    if (!app.classList.contains('hidden')) {
        // Ctrl+Z undo
        if (e.ctrlKey && e.key === 'z' && !e.shiftKey) {
            e.preventDefault();
            document.getElementById('undoBtn').click();
        }
        // Ctrl+Shift+Z or Ctrl+Y redo
        if ((e.ctrlKey && e.shiftKey && e.key === 'Z') || (e.ctrlKey && e.key === 'y')) {
            e.preventDefault();
            document.getElementById('redoBtn').click();
        }
        // Ctrl+S save
        if (e.ctrlKey && e.key === 's') {
            e.preventDefault();
            document.getElementById('saveBtn').click();
        }
        // Delete layer
        if (e.key === 'Delete' && state.selectedLayer) {
            pushHistory();
            state.layers = state.layers.filter(l => l.id !== state.selectedLayer);
            state.selectedLayer = null;
            drawUV();
        }
    }
});

// ═══════════════════════════════════════════════════════════════
// DRAG & DROP on canvas
// ═══════════════════════════════════════════════════════════════

let dragging = null;
let dragOffset = { x: 0, y: 0 };

canvas.addEventListener('mousedown', e => {
    const rect = canvas.getBoundingClientRect();
    const scale = 1024 / rect.width;
    const mx = (e.clientX - rect.left) * scale;
    const my = (e.clientY - rect.top) * scale;

    // Find clicked layer (top-most first)
    for (let i = state.layers.length - 1; i >= 0; i--) {
        const l = state.layers[i];
        if (!l.visible) continue;
        const hw = (l.w || 100) / 2;
        const hh = (l.h || 100) / 2;
        if (mx >= l.x - hw && mx <= l.x + hw && my >= l.y - hh && my <= l.y + hh) {
            dragging = l;
            dragOffset.x = mx - l.x;
            dragOffset.y = my - l.y;
            state.selectedLayer = l.id;
            fillProps(l);
            drawUV();
            pushHistory();
            return;
        }
    }
});

canvas.addEventListener('mousemove', e => {
    if (!dragging) return;
    const rect = canvas.getBoundingClientRect();
    const scale = 1024 / rect.width;
    dragging.x = Math.round((e.clientX - rect.left) * scale - dragOffset.x);
    dragging.y = Math.round((e.clientY - rect.top) * scale - dragOffset.y);
    fillProps(dragging);
    drawUV();
});

canvas.addEventListener('mouseup', () => { dragging = null; });
canvas.addEventListener('mouseleave', () => { dragging = null; });

// ═══════════════════════════════════════════════════════════════
// INIT
// ═══════════════════════════════════════════════════════════════

renderCategories();
drawUV();
