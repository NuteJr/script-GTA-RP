/* ═══════════════════════════════════════════════════════════
   Catalogue de props — logique NUI

   Rendu par paquets (Config.UI.PageSize) + IntersectionObserver :
   même avec 3000 props dans le catalogue, seules quelques dizaines
   de cartes existent dans le DOM au démarrage. Les images sont en
   lazy load natif, donc le navigateur ne télécharge que le visible.
   ═══════════════════════════════════════════════════════════ */

const RES = (typeof GetParentResourceName === 'function')
    ? GetParentResourceName()
    : 'props-placer';

const el = {
    app:      document.getElementById('app'),
    families: document.getElementById('families'),
    grid:     document.getElementById('grid'),
    search:   document.getElementById('search'),
    clear:    document.getElementById('clear'),
    close:    document.getElementById('close'),
    empty:    document.getElementById('empty'),
    force:    document.getElementById('force'),
    count:    document.getElementById('count'),
    sentinel: document.getElementById('sentinel'),
    content:  document.querySelector('.content'),
};

const state = {
    all:       [],     // { model, label, famId, famLabel, famIcon, search }
    families:  [],
    favorites: new Set(),
    recents:   [],
    filter:    'all',
    query:     '',
    view:      [],
    rendered:  0,
    cfg:       { localImages: 'images/%s.png', remoteImages: '', pageSize: 60 },
};

/* ── Utilitaires ─────────────────────────────────────────── */

function post(name, data) {
    return fetch(`https://${RES}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data || {}),
    }).catch(() => {});
}

// prop_bench_01a → « Bench 01a »
function prettify(model) {
    return model
        .replace(/^(prop|v|ba|xm|sf|hei|apa|ex|bkr|stt|imp|gr|ch|tr)_/, '')
        .replace(/_/g, ' ')
        .replace(/\b\w/g, (c) => c.toUpperCase())
        .trim();
}

function localSrc(model) { return state.cfg.localImages.replace('%s', model); }
function remoteSrc(model) {
    return state.cfg.remoteImages ? state.cfg.remoteImages.replace('%s', model) : null;
}

/* ── Construction des cartes ─────────────────────────────── */

function makeCard(item) {
    const card = document.createElement('div');
    card.className = 'card';
    card.title = item.model;

    // Vignette
    const thumb = document.createElement('div');
    thumb.className = 'thumb';

    const img = document.createElement('img');
    img.loading = 'lazy';
    img.decoding = 'async';
    img.alt = '';
    img.src = localSrc(item.model);
    img.onerror = () => {
        const remote = remoteSrc(item.model);
        if (remote && !img.dataset.retried) {
            img.dataset.retried = '1';
            img.src = remote;
            return;
        }
        img.remove();
        const ph = document.createElement('div');
        ph.className = 'ph';
        ph.textContent = item.famIcon || '📦';
        thumb.appendChild(ph);
    };
    thumb.appendChild(img);

    // Favori
    const star = document.createElement('button');
    star.className = 'star' + (state.favorites.has(item.model) ? ' on' : '');
    star.textContent = '★';
    star.title = 'Favori';
    star.addEventListener('click', (e) => {
        e.stopPropagation();
        toggleFavorite(item.model, star);
    });
    thumb.appendChild(star);

    // Libellés
    const meta = document.createElement('div');
    meta.className = 'meta';

    const name = document.createElement('div');
    name.className = 'name';
    name.textContent = item.label;

    const model = document.createElement('div');
    model.className = 'model';
    model.textContent = item.model;

    meta.append(name, model);
    card.append(thumb, meta);

    card.addEventListener('click', () => select(item.model));

    return card;
}

/* ── Rendu par paquets ───────────────────────────────────── */

function renderChunk() {
    const end = Math.min(state.rendered + state.cfg.pageSize, state.view.length);
    if (end <= state.rendered) return;

    const frag = document.createDocumentFragment();
    for (let i = state.rendered; i < end; i++) frag.appendChild(makeCard(state.view[i]));

    el.grid.appendChild(frag);
    state.rendered = end;
}

function refresh() {
    const q = state.query.trim().toLowerCase();

    let list = state.all;

    if (state.filter === 'fav') {
        list = list.filter((i) => state.favorites.has(i.model));
    } else if (state.filter === 'recent') {
        const order = new Map(state.recents.map((m, idx) => [m, idx]));
        list = list.filter((i) => order.has(i.model))
                   .sort((a, b) => order.get(a.model) - order.get(b.model));
    } else if (state.filter !== 'all') {
        list = list.filter((i) => i.famId === state.filter);
    }

    if (q) list = list.filter((i) => i.search.includes(q));

    state.view = list;
    state.rendered = 0;
    el.grid.innerHTML = '';
    renderChunk();

    const none = list.length === 0;
    el.empty.classList.toggle('hidden', !none);

    // Permet de placer un modèle absent du catalogue
    const typed = state.query.trim().toLowerCase();
    const isModelName = /^[a-z0-9_\-.]{3,}$/.test(typed);
    el.force.classList.toggle('hidden', !(none && isModelName));
    if (none && isModelName) el.force.textContent = `Placer « ${typed} » quand même`;

    el.count.textContent = `${list.length} prop${list.length > 1 ? 's' : ''}`;
}

/* ── Familles ────────────────────────────────────────────── */

function makeFamButton(id, icon, label, n) {
    const b = document.createElement('button');
    b.className = 'fam' + (state.filter === id ? ' active' : '');
    b.dataset.id = id;
    b.innerHTML =
        `<span class="ico">${icon}</span>` +
        `<span class="lbl"></span>` +
        `<span class="n">${n}</span>`;
    b.querySelector('.lbl').textContent = label;   // pas d'injection HTML
    b.addEventListener('click', () => {
        state.filter = id;
        document.querySelectorAll('.fam').forEach((x) => x.classList.toggle('active', x === b));
        el.content.scrollTop = 0;
        refresh();
    });
    return b;
}

function buildFamilies() {
    el.families.innerHTML = '';

    const g1 = document.createElement('div');
    g1.className = 'fam-group';
    g1.textContent = 'Parcourir';
    el.families.appendChild(g1);

    el.families.appendChild(makeFamButton('all', '▦', 'Tous les props', state.all.length));
    el.families.appendChild(makeFamButton('fav', '★', 'Favoris', state.favorites.size));
    el.families.appendChild(makeFamButton('recent', '🕘', 'Récents', state.recents.length));

    const g2 = document.createElement('div');
    g2.className = 'fam-group';
    g2.textContent = 'Familles';
    el.families.appendChild(g2);

    state.families.forEach((f) => {
        el.families.appendChild(makeFamButton(f.id, f.icon, f.label, f.count));
    });
}

/* ── Actions ─────────────────────────────────────────────── */

function toggleFavorite(model, btn) {
    const on = !state.favorites.has(model);
    if (on) state.favorites.add(model); else state.favorites.delete(model);
    btn.classList.toggle('on', on);

    post('favorite', { model, state: on });

    // Met à jour le compteur, et la vue si on est dans l'onglet Favoris
    const favBtn = el.families.querySelector('.fam[data-id="fav"] .n');
    if (favBtn) favBtn.textContent = state.favorites.size;
    if (state.filter === 'fav') refresh();
}

function select(model) {
    post('select', { model });
    hide();
}

function hide() {
    el.app.classList.add('hidden');
    post('close');
}

/* ── Événements ──────────────────────────────────────────── */

let searchTimer = null;
el.search.addEventListener('input', () => {
    el.clear.classList.toggle('hidden', el.search.value === '');
    clearTimeout(searchTimer);
    searchTimer = setTimeout(() => {
        state.query = el.search.value;
        el.content.scrollTop = 0;
        refresh();
    }, 110);
});

el.clear.addEventListener('click', () => {
    el.search.value = '';
    state.query = '';
    el.clear.classList.add('hidden');
    refresh();
    el.search.focus();
});

el.close.addEventListener('click', hide);
el.force.addEventListener('click', () => select(state.query.trim().toLowerCase()));

document.addEventListener('keydown', (e) => {
    if (el.app.classList.contains('hidden')) return;

    if (e.key === 'Escape') {
        e.preventDefault();
        hide();
    } else if (e.key === 'Enter' && document.activeElement === el.search) {
        if (state.view.length > 0) select(state.view[0].model);
        else if (!el.force.classList.contains('hidden')) el.force.click();
    }
});

// Défilement infini
new IntersectionObserver((entries) => {
    if (entries[0].isIntersecting) renderChunk();
}, { root: el.content, rootMargin: '300px' }).observe(el.sentinel);

/* ── Messages venus du client Lua ────────────────────────── */

window.addEventListener('message', (event) => {
    const msg = event.data || {};

    if (msg.action === 'open') {
        state.cfg       = Object.assign(state.cfg, msg.config || {});
        state.favorites = new Set(msg.favorites || []);
        state.recents   = msg.recents || [];
        state.families  = [];
        state.all       = [];

        (msg.families || []).forEach((fam) => {
            state.families.push({
                id: fam.id, label: fam.label, icon: fam.icon, count: fam.props.length,
            });

            fam.props.forEach((p) => {
                const label = p.label || prettify(p.model);
                state.all.push({
                    model:    p.model,
                    label:    label,
                    famId:    fam.id,
                    famLabel: fam.label,
                    famIcon:  fam.icon,
                    search:   (p.model + ' ' + label + ' ' + fam.label).toLowerCase(),
                });
            });
        });

        state.filter = 'all';
        state.query  = '';
        el.search.value = '';
        el.clear.classList.add('hidden');

        buildFamilies();
        refresh();

        el.app.classList.remove('hidden');
        el.content.scrollTop = 0;
        setTimeout(() => el.search.focus(), 40);

    } else if (msg.action === 'close') {
        el.app.classList.add('hidden');
    }
});
