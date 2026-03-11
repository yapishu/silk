/* ============================================
   silk — main application
   ============================================ */

const App = {
  state: {
    view: 'dashboard',
    nyms: [],
    listings: [],
    threads: [],
    orders: [],
    reputation: [],
    peers: [],
    stats: { nyms: 0, listings: 0, threads: 0, orders: 0, peers: 0 },
    relays: [],
    skeinStats: {},
    loading: true,
    dialog: null,
  },

  init() {
    window.addEventListener('hashchange', () => this.route());
    this.route();
    this.refresh();
    setInterval(() => this.refresh(), 15000);
  },

  route() {
    const hash = location.hash.slice(1) || 'dashboard';
    this.state.view = hash;
    this.render();
  },

  async refresh() {
    try {
      const [nyms, listings, threads, orders, reputation, stats, peers, relays, skeinStats] = await Promise.allSettled([
        SilkAPI.getNyms(),
        SilkAPI.getListings(),
        SilkAPI.getThreads(),
        SilkAPI.getOrders(),
        SilkAPI.getReputation(),
        SilkAPI.getStats(),
        SilkAPI.getPeers(),
        SilkAPI.getRelays(),
        SilkAPI.getSkeinStats(),
      ]);
      if (nyms.status === 'fulfilled')       this.state.nyms = nyms.value.nyms || [];
      if (listings.status === 'fulfilled')    this.state.listings = listings.value.listings || [];
      if (threads.status === 'fulfilled')     this.state.threads = threads.value.threads || [];
      if (orders.status === 'fulfilled')      this.state.orders = orders.value.orders || [];
      if (reputation.status === 'fulfilled')  this.state.reputation = reputation.value.scores || [];
      if (stats.status === 'fulfilled')       this.state.stats = stats.value;
      if (peers.status === 'fulfilled')       this.state.peers = peers.value.peers || [];
      if (relays.status === 'fulfilled')      this.state.relays = relays.value || [];
      if (skeinStats.status === 'fulfilled')  this.state.skeinStats = skeinStats.value || {};
    } catch (e) {
      console.error('refresh failed:', e);
    }
    this.state.loading = false;
    this.render();
  },

  toast(msg, type = '') {
    const container = document.querySelector('.toast-container') || (() => {
      const c = document.createElement('div');
      c.className = 'toast-container';
      document.body.appendChild(c);
      return c;
    })();
    const el = document.createElement('div');
    el.className = `toast ${type}`;
    el.textContent = msg;
    container.appendChild(el);
    setTimeout(() => el.remove(), 3500);
  },

  async action(fn) {
    try {
      await fn();
      this.closeDialog();
      this.toast('done', 'success');
      await this.refresh();
    } catch (e) {
      this.toast(e.message, 'error');
    }
  },

  openDialog(name, data = {}) {
    this.state.dialog = { name, data };
    this.render();
  },

  closeDialog() {
    this.state.dialog = null;
    this.render();
  },

  shortId(id) {
    if (!id) return '---';
    const s = String(id);
    return s.length > 16 ? s.slice(0, 8) + '..' + s.slice(-6) : s;
  },

  fmtDate(ts) {
    if (!ts) return '---';
    const d = new Date(ts * 1000);
    return d.toLocaleDateString(undefined, { month: 'short', day: 'numeric', year: 'numeric' });
  },

  fmtPrice(amount, currency) {
    const cur = (currency || 'usd').toUpperCase();
    return `${amount} ${cur}`;
  },

  // ---- render ----

  render() {
    const app = document.getElementById('app');
    app.innerHTML = `
      ${this.renderSidebar()}
      <div class="main">
        ${this.renderPage()}
      </div>
      ${this.renderDialog()}
    `;
    this.bindEvents();
  },

  renderSidebar() {
    const items = [
      { id: 'dashboard',   icon: '\u25A3', label: 'Dashboard' },
      { id: 'identities',  icon: '\u2662', label: 'Identities' },
      { id: 'marketplace', icon: '\u25C8', label: 'Marketplace' },
      { id: 'threads',     icon: '\u2261', label: 'Threads' },
      { id: 'orders',      icon: '\u25CE', label: 'Orders' },
      { id: 'reputation',  icon: '\u2605', label: 'Reputation' },
      { id: 'network',     icon: '\u2B21', label: 'Network' },
    ];
    return `
      <div class="sidebar">
        <div class="sidebar-brand">
          <h1>silk</h1>
          <div class="brand-sub">private marketplace</div>
        </div>
        <div class="sidebar-nav">
          <div class="nav-section">navigate</div>
          ${items.map(i => `
            <a href="#${i.id}" class="nav-item ${this.state.view === i.id ? 'active' : ''}">
              <span class="nav-icon">${i.icon}</span>
              <span>${i.label}</span>
            </a>
          `).join('')}
        </div>
        <div class="sidebar-footer">
          skein + silk
        </div>
      </div>
    `;
  },

  renderPage() {
    if (this.state.loading) {
      return '<div class="loading"><div class="spinner"></div> loading...</div>';
    }
    switch (this.state.view) {
      case 'dashboard':   return this.renderDashboard();
      case 'identities':  return this.renderIdentities();
      case 'marketplace': return this.renderMarketplace();
      case 'threads':     return this.renderThreads();
      case 'orders':      return this.renderOrders();
      case 'reputation':  return this.renderReputation();
      case 'network':     return this.renderNetwork();
      default:            return this.renderDashboard();
    }
  },

  // ---- dashboard ----

  renderDashboard() {
    const s = this.state.stats;
    const recentThreads = this.state.threads.slice(0, 5);
    return `
      <div class="page-header">
        <h2>Dashboard</h2>
        <div class="page-desc">Overview of your marketplace activity</div>
      </div>
      <div class="page-content">
        <div class="stat-grid">
          <div class="stat-card">
            <div class="stat-label">Identities</div>
            <div class="stat-value">${s.nyms || 0}</div>
          </div>
          <div class="stat-card">
            <div class="stat-label">Listings</div>
            <div class="stat-value">${s.listings || 0}</div>
          </div>
          <div class="stat-card">
            <div class="stat-label">Threads</div>
            <div class="stat-value">${s.threads || 0}</div>
          </div>
          <div class="stat-card">
            <div class="stat-label">Peers</div>
            <div class="stat-value">${s.peers || 0}</div>
          </div>
        </div>
        <div class="table-wrap">
          <div class="table-header">
            <div class="table-title">Recent Threads</div>
          </div>
          ${recentThreads.length ? `
            <table>
              <thead>
                <tr>
                  <th>Thread</th>
                  <th>Status</th>
                  <th>Buyer</th>
                  <th>Seller</th>
                  <th>Updated</th>
                </tr>
              </thead>
              <tbody>
                ${recentThreads.map(t => `
                  <tr>
                    <td class="mono truncate">${this.shortId(t.id)}</td>
                    <td><span class="badge badge-${t.status}">${t.status}</span></td>
                    <td class="mono truncate">${this.shortId(t.buyer)}</td>
                    <td class="mono truncate">${this.shortId(t.seller)}</td>
                    <td class="mono">${this.fmtDate(t.updated_at)}</td>
                  </tr>
                `).join('')}
              </tbody>
            </table>
          ` : '<div class="empty-state"><div class="empty-text">No threads yet</div></div>'}
        </div>
      </div>
    `;
  },

  // ---- identities ----

  renderIdentities() {
    return `
      <div class="page-header">
        <h2>Identities</h2>
        <div class="page-desc">Manage your market pseudonyms</div>
      </div>
      <div class="page-content">
        <div style="margin-bottom: 20px;">
          <button class="btn btn-primary" data-action="open-create-nym">+ Create Identity</button>
        </div>
        ${this.state.nyms.length ? `
          <div class="nym-grid">
            ${this.state.nyms.map(n => `
              <div class="nym-card">
                <div class="nym-label">${this.esc(n.label)}</div>
                <div class="nym-id">id: ${n.id}</div>
                <div class="nym-key">key: ${this.shortId(n.pubkey)}</div>
                <div class="nym-date">created ${this.fmtDate(n.created_at)}</div>
                <div class="nym-actions">
                  <button class="btn btn-sm btn-ghost" data-action="drop-nym" data-id="${n.id}">delete</button>
                </div>
              </div>
            `).join('')}
          </div>
        ` : `
          <div class="empty-state">
            <div class="empty-icon">\u2662</div>
            <div class="empty-text">No identities created yet</div>
          </div>
        `}
      </div>
    `;
  },

  // ---- marketplace ----

  renderMarketplace() {
    return `
      <div class="page-header">
        <h2>Marketplace</h2>
        <div class="page-desc">Browse and post listings</div>
      </div>
      <div class="page-content">
        <div style="margin-bottom: 20px; display: flex; gap: 8px;">
          <button class="btn btn-primary" data-action="open-post-listing">+ Post Listing</button>
          <button class="btn" data-action="sync-catalog">Sync Catalog</button>
        </div>
        ${this.state.listings.length ? `
          <div class="listing-grid">
            ${this.state.listings.map(l => `
              <div class="listing-card">
                <div class="listing-title">
                  ${this.esc(l.title)}
                  ${l.mine ? '<span class="badge badge-mine">yours</span>' : ''}
                </div>
                <div class="listing-desc">${this.esc(l.description)}</div>
                <div>
                  <span class="listing-price">${l.price}</span>
                  <span class="listing-currency">${l.currency}</span>
                </div>
                <div class="listing-meta">
                  <span class="listing-seller">${l.seller_label ? this.esc(l.seller_label) : this.shortId(l.seller)}</span>
                  ${l.mine
                    ? `<button class="btn btn-sm btn-ghost" data-action="retract-listing" data-id="${l.id}">delete</button>`
                    : `<button class="btn btn-sm" data-action="open-send-offer" data-listing='${JSON.stringify(l)}'>Make Offer</button>`
                  }
                </div>
              </div>
            `).join('')}
          </div>
        ` : `
          <div class="empty-state">
            <div class="empty-icon">\u25C8</div>
            <div class="empty-text">No listings yet</div>
          </div>
        `}
      </div>
    `;
  },

  // ---- threads ----

  renderThreads() {
    return `
      <div class="page-header">
        <h2>Threads</h2>
        <div class="page-desc">Negotiation conversations</div>
      </div>
      <div class="page-content">
        ${this.state.threads.length ? `
          <div class="thread-list">
            ${this.state.threads.map(t => {
              // find the listing title if we have it
              const listing = this.state.listings.find(l => l.id === t.listing_id);
              const title = listing ? this.esc(listing.title) : this.shortId(t.listing_id);
              return `
              <div class="card" style="margin-bottom: 12px;">
                <div style="display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 10px;">
                  <div>
                    <div style="font-size: 15px; font-weight: 600; color: var(--text-bright);">${title}</div>
                    <div class="thread-parties" style="margin-top: 4px;">
                      <span class="mono">${this.shortId(t.buyer)}</span>
                      <span style="color: var(--text-muted); margin: 0 6px;">\u2194</span>
                      <span class="mono">${this.shortId(t.seller)}</span>
                    </div>
                  </div>
                  <span class="badge badge-${t.status}">${t.status}</span>
                </div>
                <div style="display: flex; justify-content: space-between; align-items: center; padding-top: 10px; border-top: 1px solid var(--border-dim);">
                  <div style="font-size: 12px; color: var(--text-muted);">
                    ${t.amount ? this.fmtPrice(t.amount, t.currency) + ' &middot; ' : ''}${t.message_count} message${t.message_count !== 1 ? 's' : ''} &middot; ${this.fmtDate(t.updated_at)}
                  </div>
                  <div style="display: flex; gap: 8px;">
                    ${t.status === 'open' ? `
                      <button class="btn btn-sm btn-primary" data-action="accept-offer" data-thread-id="${t.id}" data-offer-id="${t.id}">Accept</button>
                      <button class="btn btn-sm btn-ghost" data-action="reject-offer" data-thread-id="${t.id}" data-offer-id="${t.id}">Reject</button>
                    ` : ''}
                  </div>
                </div>
              </div>
              `;
            }).join('')}
          </div>
        ` : `
          <div class="empty-state">
            <div class="empty-icon">\u2261</div>
            <div class="empty-text">No negotiation threads</div>
          </div>
        `}
      </div>
    `;
  },

  // ---- orders ----

  renderOrders() {
    const ORDER_STEPS = ['accepted','paid','fulfilled','completed'];
    const myNymIds = new Set(this.state.nyms.map(n => n.id));
    return `
      <div class="page-header">
        <h2>Orders</h2>
        <div class="page-desc">Track order status through the lifecycle</div>
      </div>
      <div class="page-content">
        ${this.state.orders.length ? `
          <div style="display: flex; flex-direction: column; gap: 16px;">
            ${this.state.orders.map(o => {
              const idx = ORDER_STEPS.indexOf(o.status);
              const isBuyer = myNymIds.has(o.buyer);
              const isSeller = myNymIds.has(o.seller);
              const listing = this.state.listings.find(l => l.id === o.listing_id);
              const title = listing ? this.esc(listing.title) : this.shortId(o.listing_id);

              let actions = '';
              if (o.status === 'accepted') {
                actions += `<button class="btn btn-sm btn-primary" data-action="open-send-invoice" data-thread-id="${o.thread_id}">Send Invoice</button>`;
                actions += `<button class="btn btn-sm" data-action="open-submit-payment" data-thread-id="${o.thread_id}">Submit Payment</button>`;
              }
              if (o.status === 'paid') {
                actions += `<button class="btn btn-sm btn-primary" data-action="open-mark-fulfilled" data-thread-id="${o.thread_id}">Mark Fulfilled</button>`;
              }
              if (o.status === 'fulfilled') {
                actions += `<button class="btn btn-sm btn-primary" data-action="confirm-complete" data-thread-id="${o.thread_id}">Confirm Complete</button>`;
              }

              return `
                <div class="card">
                  <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 12px;">
                    <div>
                      <div style="font-size: 15px; font-weight: 600; color: var(--text-bright);">
                        ${title} &mdash; ${this.fmtPrice(o.amount, o.currency)}
                      </div>
                      <div class="mono" style="font-size: 11px; color: var(--text-muted); margin-top: 2px;">
                        ${isBuyer ? 'you are buyer' : isSeller ? 'you are seller' : this.shortId(o.thread_id)}
                      </div>
                    </div>
                    <span class="badge badge-${o.status}">${o.status}</span>
                  </div>
                  <div class="order-timeline">
                    ${ORDER_STEPS.map((step, i) => {
                      const reached = i <= idx;
                      const current = i === idx;
                      const dot = current ? 'current' : reached ? 'reached' : '';
                      const line = i < ORDER_STEPS.length - 1
                        ? `<div class="timeline-line ${i < idx ? 'reached' : ''}"></div>`
                        : '';
                      return `
                        <div class="timeline-step">
                          <div class="timeline-dot ${dot}">
                            ${reached ? '\u2713' : (i + 1)}
                            <div class="timeline-label">${step}</div>
                          </div>
                          ${line}
                        </div>
                      `;
                    }).join('')}
                  </div>
                  <div style="display: flex; justify-content: space-between; align-items: center; margin-top: 28px;">
                    <div style="display: flex; gap: 16px; font-size: 12px; color: var(--text-muted);">
                      <span>buyer: <span class="mono">${this.shortId(o.buyer)}</span></span>
                      <span>seller: <span class="mono">${this.shortId(o.seller)}</span></span>
                    </div>
                    <div style="display: flex; gap: 8px; align-items: center;">
                      ${actions}
                    </div>
                  </div>
                </div>
              `;
            }).join('')}
          </div>
        ` : `
          <div class="empty-state">
            <div class="empty-icon">\u25CE</div>
            <div class="empty-text">No orders yet</div>
          </div>
        `}
      </div>
    `;
  },

  // ---- reputation ----

  renderReputation() {
    return `
      <div class="page-header">
        <h2>Reputation</h2>
        <div class="page-desc">Trust scores for pseudonyms</div>
      </div>
      <div class="page-content">
        ${this.state.reputation.length ? `
          <div class="rep-grid">
            ${this.state.reputation.map(r => `
              <div class="rep-card">
                <div class="rep-nym">${this.shortId(r.nym_id)}</div>
                <div class="rep-score">${r.score}</div>
                <div class="rep-label">reputation score</div>
              </div>
            `).join('')}
          </div>
        ` : `
          <div class="empty-state">
            <div class="empty-icon">\u2605</div>
            <div class="empty-text">No reputation data yet</div>
          </div>
        `}
      </div>
    `;
  },

  // ---- network ----

  renderNetwork() {
    const relays = this.state.relays;
    const sk = this.state.skeinStats;
    const peers = this.state.peers;
    return `
      <div class="page-header">
        <h2>Network</h2>
        <div class="page-desc">Manage skein relays and marketplace peers</div>
      </div>
      <div class="page-content">
        <div class="stat-grid">
          <div class="stat-card">
            <div class="stat-label">Relays</div>
            <div class="stat-value">${sk.relays || 0}</div>
          </div>
          <div class="stat-card">
            <div class="stat-label">Peers</div>
            <div class="stat-value">${peers.length}</div>
          </div>
          <div class="stat-card">
            <div class="stat-label">Routes</div>
            <div class="stat-value">${sk.routes || 0}</div>
          </div>
          <div class="stat-card">
            <div class="stat-label">Seen</div>
            <div class="stat-value">${sk.seen || 0}</div>
          </div>
        </div>

        <div class="setting-row">
          <div class="setting-info">
            <div class="setting-label">Minimum Relay Hops</div>
            <div class="setting-desc">
              Number of intermediate relays before the final hop. Higher values increase privacy but require more online relays.
            </div>
          </div>
          <div class="setting-control">
            <button class="btn btn-sm" data-action="dec-min-hops" ${(sk.minHops || 0) === 0 ? 'disabled' : ''}>-</button>
            <span class="setting-value">${sk.minHops || 0}</span>
            <button class="btn btn-sm" data-action="inc-min-hops">+</button>
          </div>
        </div>
        ${(sk.minHops || 0) > 0 && (sk.relays || 0) <= (sk.minHops || 0) ? `
          <div class="alert alert-warn">
            Not enough relays to satisfy min-hops=${sk.minHops}. Messages may fail to route. Add more relays or reduce min-hops.
          </div>
        ` : ''}

        <div class="table-wrap">
          <div class="table-header">
            <div class="table-title">Marketplace Peers</div>
            <button class="btn btn-primary btn-sm" data-action="open-add-peer">+ Add Peer</button>
          </div>
          ${peers.length ? `
            <table>
              <thead>
                <tr>
                  <th>Ship</th>
                  <th></th>
                </tr>
              </thead>
              <tbody>
                ${peers.map(p => `
                  <tr>
                    <td class="mono">${this.esc(p)}</td>
                    <td style="text-align: right;">
                      <button class="btn btn-sm btn-ghost" data-action="drop-peer" data-ship="${this.esc(p)}">remove</button>
                    </td>
                  </tr>
                `).join('')}
              </tbody>
            </table>
          ` : `
            <div class="empty-state">
              <div class="empty-icon">\u2B21</div>
              <div class="empty-text">No marketplace peers. Add peers to share listings.</div>
            </div>
          `}
        </div>

        <div class="table-wrap">
          <div class="table-header">
            <div class="table-title">Relay Descriptors</div>
            <button class="btn btn-primary btn-sm" data-action="open-discover-relay">+ Discover Relay</button>
          </div>
          ${this.renderRelayTable(relays)}
        </div>
      </div>
    `;
  },

  renderRelayTable(relays) {
    const entries = Array.isArray(relays) ? relays : [];
    if (!entries.length) {
      return `
        <div class="empty-state">
          <div class="empty-icon">\u2B21</div>
          <div class="empty-text">No relays configured</div>
        </div>
      `;
    }
    return `
      <table>
        <thead>
          <tr>
            <th>Name</th>
            <th>Ship</th>
            <th>Weight</th>
            <th></th>
          </tr>
        </thead>
        <tbody>
          ${entries.map(r => `
            <tr>
              <td class="mono">${this.esc(r.relay)}</td>
              <td class="mono">${this.esc(r.ship)}</td>
              <td>${r.weight || 1}</td>
              <td style="text-align: right;">
                <button class="btn btn-sm btn-ghost" data-action="drop-relay" data-relay="${this.esc(r.relay)}">remove</button>
              </td>
            </tr>
          `).join('')}
        </tbody>
      </table>
    `;
  },

  // ---- dialogs ----

  renderDialog() {
    if (!this.state.dialog) return '';
    const { name, data } = this.state.dialog;
    let content = '';

    if (name === 'create-nym') {
      content = `
        <h3>Create Identity</h3>
        <div class="form-group">
          <label>Label</label>
          <input type="text" id="nym-label" placeholder="my-vendor-name" autofocus>
        </div>
        <div class="form-actions">
          <button class="btn" data-action="close-dialog">Cancel</button>
          <button class="btn btn-primary" data-action="submit-create-nym">Create</button>
        </div>
      `;
    }

    if (name === 'post-listing') {
      const nymOpts = this.state.nyms.map(n =>
        `<option value="${n.id}">${this.esc(n.label)}</option>`
      ).join('');
      content = `
        <h3>Post Listing</h3>
        <div class="form-group">
          <label>Identity</label>
          <select id="listing-nym">${nymOpts || '<option value="">no identities</option>'}</select>
        </div>
        <div class="form-group">
          <label>Title</label>
          <input type="text" id="listing-title" placeholder="What are you selling?">
        </div>
        <div class="form-group">
          <label>Description</label>
          <textarea id="listing-desc" placeholder="Describe your item or service..."></textarea>
        </div>
        <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 12px;">
          <div class="form-group">
            <label>Price</label>
            <input type="number" id="listing-price" placeholder="0">
          </div>
          <div class="form-group">
            <label>Currency</label>
            <select id="listing-currency">
              <option value="usd">USD</option>
              <option value="eth">ETH</option>
              <option value="btc">BTC</option>
              <option value="zen">ZEN</option>
            </select>
          </div>
        </div>
        <div class="form-actions">
          <button class="btn" data-action="close-dialog">Cancel</button>
          <button class="btn btn-primary" data-action="submit-post-listing">Post</button>
        </div>
      `;
    }

    if (name === 'send-offer') {
      const l = data;
      const nymOpts = this.state.nyms.map(n =>
        `<option value="${n.id}">${this.esc(n.label)}</option>`
      ).join('');
      content = `
        <h3>Make Offer</h3>
        <div style="margin-bottom: 16px; padding: 12px; background: var(--bg-primary); border-radius: var(--radius); border: 1px solid var(--border-dim);">
          <div style="font-weight: 600; color: var(--text-bright);">${this.esc(l.title)}</div>
          <div style="font-size: 12px; color: var(--text-muted); margin-top: 4px;">Listed at ${this.fmtPrice(l.price, l.currency)}</div>
        </div>
        <div class="form-group">
          <label>Your Identity</label>
          <select id="offer-nym">${nymOpts || '<option value="">no identities</option>'}</select>
        </div>
        <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 12px;">
          <div class="form-group">
            <label>Amount</label>
            <input type="number" id="offer-amount" value="${l.price}" placeholder="0">
          </div>
          <div class="form-group">
            <label>Currency</label>
            <input type="text" id="offer-currency" value="${l.currency}" readonly>
          </div>
        </div>
        <input type="hidden" id="offer-listing-id" value="${l.id}">
        <input type="hidden" id="offer-seller" value="${l.seller}">
        <div class="form-actions">
          <button class="btn" data-action="close-dialog">Cancel</button>
          <button class="btn btn-primary" data-action="submit-send-offer">Send Offer</button>
        </div>
      `;
    }

    if (name === 'add-peer') {
      content = `
        <h3>Add Marketplace Peer</h3>
        <div style="margin-bottom: 16px; font-size: 13px; color: var(--text-muted);">
          Add a ship to exchange listings with. Both sides must add each other for ongoing sync.
        </div>
        <div class="form-group">
          <label>Ship</label>
          <input type="text" id="peer-ship" placeholder="~sampel-palnet" autofocus>
        </div>
        <div class="form-actions">
          <button class="btn" data-action="close-dialog">Cancel</button>
          <button class="btn btn-primary" data-action="submit-add-peer">Add Peer</button>
        </div>
      `;
    }

    if (name === 'send-invoice') {
      content = `
        <h3>Send Invoice</h3>
        <div style="margin-bottom: 16px; font-size: 13px; color: var(--text-muted);">
          Provide a payment address for the buyer to send funds to.
        </div>
        <div class="form-group">
          <label>Pay Address</label>
          <input type="text" id="invoice-pay-address" placeholder="0x... or payment address" autofocus>
        </div>
        <input type="hidden" id="invoice-thread-id" value="${data.threadId || ''}">
        <div class="form-actions">
          <button class="btn" data-action="close-dialog">Cancel</button>
          <button class="btn btn-primary" data-action="submit-send-invoice">Send Invoice</button>
        </div>
      `;
    }

    if (name === 'submit-payment') {
      content = `
        <h3>Submit Payment Proof</h3>
        <div style="margin-bottom: 16px; font-size: 13px; color: var(--text-muted);">
          Provide the transaction hash or reference for your payment.
        </div>
        <div class="form-group">
          <label>Transaction Hash</label>
          <input type="text" id="payment-tx-hash" placeholder="0x... or tx reference" autofocus>
        </div>
        <input type="hidden" id="payment-thread-id" value="${data.threadId || ''}">
        <div class="form-actions">
          <button class="btn" data-action="close-dialog">Cancel</button>
          <button class="btn btn-primary" data-action="submit-submit-payment">Submit Payment</button>
        </div>
      `;
    }

    if (name === 'mark-fulfilled') {
      content = `
        <h3>Mark as Fulfilled</h3>
        <div style="margin-bottom: 16px; font-size: 13px; color: var(--text-muted);">
          Confirm delivery and add any notes about fulfillment.
        </div>
        <div class="form-group">
          <label>Delivery Note</label>
          <textarea id="fulfill-note" placeholder="Details about delivery..."></textarea>
        </div>
        <input type="hidden" id="fulfill-thread-id" value="${data.threadId || ''}">
        <div class="form-actions">
          <button class="btn" data-action="close-dialog">Cancel</button>
          <button class="btn btn-primary" data-action="submit-mark-fulfilled">Confirm Fulfillment</button>
        </div>
      `;
    }

    if (name === 'discover-relay') {
      content = `
        <h3>Discover Relay</h3>
        <div style="margin-bottom: 16px; font-size: 13px; color: var(--text-muted);">
          Subscribe to a ship to learn its relay descriptor and key.
        </div>
        <div class="form-group">
          <label>Ship</label>
          <input type="text" id="discover-ship" placeholder="~sampel-palnet" autofocus>
        </div>
        <div class="form-actions">
          <button class="btn" data-action="close-dialog">Cancel</button>
          <button class="btn btn-primary" data-action="submit-discover-relay">Discover</button>
        </div>
      `;
    }

    return `
      <div class="dialog-overlay" data-action="close-dialog-bg">
        <div class="dialog" onclick="event.stopPropagation()">
          ${content}
        </div>
      </div>
    `;
  },

  // ---- events ----

  bindEvents() {
    document.querySelectorAll('[data-action]').forEach(el => {
      el.addEventListener('click', (e) => {
        const action = el.dataset.action;
        switch (action) {
          case 'open-create-nym':
            this.openDialog('create-nym');
            break;
          case 'submit-create-nym':
            this.action(() => SilkAPI.createNym(document.getElementById('nym-label').value));
            break;
          case 'drop-nym':
            if (confirm('Delete this identity?')) {
              this.action(() => SilkAPI.dropNym(el.dataset.id));
            }
            break;
          case 'open-post-listing':
            this.openDialog('post-listing');
            break;
          case 'submit-post-listing':
            this.action(() => SilkAPI.postListing(
              document.getElementById('listing-title').value,
              document.getElementById('listing-desc').value,
              parseInt(document.getElementById('listing-price').value) || 0,
              document.getElementById('listing-currency').value,
              document.getElementById('listing-nym').value,
            ));
            break;
          case 'sync-catalog':
            this.action(() => SilkAPI.syncCatalog());
            break;
          case 'retract-listing':
            if (confirm('Delete this listing?')) {
              this.action(() => SilkAPI.retractListing(el.dataset.id));
            }
            break;
          case 'open-send-offer':
            this.openDialog('send-offer', JSON.parse(el.dataset.listing));
            break;
          case 'submit-send-offer':
            this.action(() => SilkAPI.sendOffer(
              document.getElementById('offer-listing-id').value,
              document.getElementById('offer-seller').value,
              parseInt(document.getElementById('offer-amount').value) || 0,
              document.getElementById('offer-currency').value,
              document.getElementById('offer-nym').value,
            ));
            break;
          case 'accept-offer':
            this.action(() => SilkAPI.acceptOffer(el.dataset.threadId, el.dataset.offerId));
            break;
          case 'reject-offer':
            this.action(() => SilkAPI.rejectOffer(el.dataset.threadId, el.dataset.offerId, 'declined'));
            break;
          case 'open-send-invoice':
            this.openDialog('send-invoice', { threadId: el.dataset.threadId });
            break;
          case 'submit-send-invoice':
            this.action(() => SilkAPI.sendInvoice(
              document.getElementById('invoice-thread-id').value,
              document.getElementById('invoice-pay-address').value,
            ));
            break;
          case 'open-submit-payment':
            this.openDialog('submit-payment', { threadId: el.dataset.threadId });
            break;
          case 'submit-submit-payment':
            this.action(() => SilkAPI.submitPayment(
              document.getElementById('payment-thread-id').value,
              document.getElementById('payment-tx-hash').value,
            ));
            break;
          case 'open-mark-fulfilled':
            this.openDialog('mark-fulfilled', { threadId: el.dataset.threadId });
            break;
          case 'submit-mark-fulfilled':
            this.action(() => SilkAPI.markFulfilled(
              document.getElementById('fulfill-thread-id').value,
              document.getElementById('fulfill-note').value,
            ));
            break;
          case 'confirm-complete':
            if (confirm('Confirm this order is complete?')) {
              this.action(() => SilkAPI.confirmComplete(el.dataset.threadId));
            }
            break;
          case 'open-add-peer':
            this.openDialog('add-peer');
            break;
          case 'submit-add-peer':
            this.action(() => SilkAPI.addPeer(document.getElementById('peer-ship').value));
            break;
          case 'drop-peer':
            if (confirm('Remove this peer?')) {
              this.action(() => SilkAPI.dropPeer(el.dataset.ship));
            }
            break;
          case 'open-discover-relay':
            this.openDialog('discover-relay');
            break;
          case 'submit-discover-relay':
            this.action(() => SilkAPI.discoverRelay(document.getElementById('discover-ship').value));
            break;
          case 'drop-relay':
            if (confirm('Remove this relay?')) {
              this.action(() => SilkAPI.dropRelay(el.dataset.relay));
            }
            break;
          case 'inc-min-hops':
            this.action(() => SilkAPI.setMinHops((this.state.skeinStats.minHops || 0) + 1));
            break;
          case 'dec-min-hops':
            {
              const cur = this.state.skeinStats.minHops || 0;
              if (cur > 0) this.action(() => SilkAPI.setMinHops(cur - 1));
            }
            break;
          case 'close-dialog':
          case 'close-dialog-bg':
            this.closeDialog();
            break;
        }
      });
    });
  },

  esc(str) {
    if (!str) return '';
    const div = document.createElement('div');
    div.textContent = str;
    return div.innerHTML;
  },
};

document.addEventListener('DOMContentLoaded', () => App.init());
