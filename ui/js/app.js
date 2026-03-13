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
    attestations: [],
    peers: [],
    moderators: [],
    stats: { nyms: 0, listings: 0, threads: 0, orders: 0, peers: 0 },
    relays: [],
    skeinStats: {},
    skeinHealth: [],
    skeinTrusted: [],
    skeinChannels: {},
    myEscrows: [],
    zenithAccounts: [],
    loading: true,
    dialog: null,
    threadsPage: 0,
    ordersPage: 0,
    apiErrors: [],
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
      const results = await Promise.allSettled([
        SilkAPI.getNyms(),        // 0
        SilkAPI.getListings(),    // 1
        SilkAPI.getThreads(),     // 2
        SilkAPI.getOrders(),      // 3
        SilkAPI.getReputation(),  // 4
        SilkAPI.getStats(),       // 5
        SilkAPI.getPeers(),       // 6
        SilkAPI.getRelays(),      // 7
        SilkAPI.getSkeinStats(),  // 8
        SilkAPI.getSkeinHealth(), // 9
        SilkAPI.getSkeinTrusted(),// 10
        SilkAPI.getSkeinChannels(),// 11
        SilkAPI.getModerators(),  // 12
        SilkAPI.getMyEscrows(),  // 13
        SilkAPI.getZenithAccounts(), // 14
      ]);
      const errors = [];
      const get = (i) => {
        if (results[i].status === 'fulfilled') return results[i].value;
        errors.push(results[i].reason?.message || `API call ${i} failed`);
        return null;
      };
      const nyms = get(0);
      const listings = get(1);
      const threads = get(2);
      const orders = get(3);
      const reputation = get(4);
      const stats = get(5);
      const peers = get(6);
      const relays = get(7);
      const skeinStats = get(8);
      const skeinHealth = get(9);
      const skeinTrusted = get(10);
      const skeinChannels = get(11);

      if (nyms)       this.state.nyms = nyms.nyms || [];
      if (listings)   this.state.listings = listings.listings || [];
      if (threads)    this.state.threads = threads.threads || [];
      if (orders)     this.state.orders = orders.orders || [];
      if (reputation) {
        this.state.reputation = reputation.scores || [];
        this.state.attestations = reputation.attestations || [];
      }
      if (stats)         this.state.stats = stats;
      if (peers)         this.state.peers = peers.peers || [];
      if (relays)        this.state.relays = relays || [];
      if (skeinStats)    this.state.skeinStats = skeinStats || {};
      if (skeinHealth)   this.state.skeinHealth = skeinHealth || [];
      if (skeinTrusted)  this.state.skeinTrusted = skeinTrusted || [];
      if (skeinChannels) this.state.skeinChannels = skeinChannels || {};
      const moderators = get(12);
      if (moderators)    this.state.moderators = moderators.moderators || [];
      const myEscrows = get(13);
      if (myEscrows)     this.state.myEscrows = myEscrows.escrows || [];
      const zenithAccounts = get(14);
      if (zenithAccounts) this.state.zenithAccounts = zenithAccounts.accounts || [];
      this.state.apiErrors = errors;
      if (errors.length) console.warn('silk: API errors:', errors);
    } catch (e) {
      console.error('refresh failed:', e);
    }
    this.state.loading = false;
    if (!this.state.dialog) this.render();
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

  fmtTime(ts) {
    if (!ts) return '';
    const d = new Date(ts * 1000);
    const now = new Date();
    const sameDay = d.toDateString() === now.toDateString();
    const time = d.toLocaleTimeString(undefined, { hour: '2-digit', minute: '2-digit' });
    return sameDay ? time : d.toLocaleDateString(undefined, { month: 'short', day: 'numeric' }) + ' ' + time;
  },

  fmtPrice(amount) {
    return `${amount} sZ`;
  },

  // ---- render ----

  render() {
    const app = document.getElementById('app');
    const main = app.querySelector('.main');
    const scrollTop = main ? main.scrollTop : 0;
    app.innerHTML = `
      ${this.renderSidebar()}
      <div class="main">
        ${this.renderPage()}
      </div>
      ${this.renderDialog()}
    `;
    const newMain = app.querySelector('.main');
    if (newMain) newMain.scrollTop = scrollTop;
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
      { id: 'moderators', icon: '\u2696', label: 'Moderators' },
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
      case 'moderators': return this.renderModerators();
      case 'network':     return this.renderNetwork();
      default:            return this.renderDashboard();
    }
  },

  // ---- dashboard ----

  renderDashboard() {
    const s = this.state.stats;
    const sk = this.state.skeinStats;
    const recentThreads = this.state.threads.slice(0, 5);
    const errors = this.state.apiErrors || [];
    return `
      <div class="page-header">
        <h2>Dashboard</h2>
        <div class="page-desc">Overview of your marketplace activity</div>
      </div>
      <div class="page-content">
        ${errors.length ? `
          <div class="alert alert-warn" style="margin-bottom: 16px;">
            API issues: ${errors.map(e => this.esc(e)).join(', ')}
          </div>
        ` : ''}
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
          <div class="stat-card">
            <div class="stat-label">Moderators</div>
            <div class="stat-value">${s.moderators || 0}</div>
          </div>
          <div class="stat-card">
            <div class="stat-label">Relays</div>
            <div class="stat-value">${sk.relays || 0}</div>
          </div>
          <div class="stat-card">
            <div class="stat-label">Trusted</div>
            <div class="stat-value">${sk.trustedRelays || 0}</div>
          </div>
        </div>

        <div class="sub-grid">
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

          <div class="table-wrap">
            <div class="table-header">
              <div class="table-title">Skein Health</div>
            </div>
            <div style="padding: 16px 20px;">
              <div class="mini-stat-row">
                <span class="mini-label">Ship</span>
                <span class="mono">${this.esc(sk.ship || '?')}</span>
              </div>
              <div class="mini-stat-row">
                <span class="mini-label">Bound Apps</span>
                <span>${sk.apps || 0}</span>
              </div>
              <div class="mini-stat-row">
                <span class="mini-label">Routes Used</span>
                <span>${sk.routes || 0}</span>
              </div>
              <div class="mini-stat-row">
                <span class="mini-label">Seen Cells</span>
                <span>${sk.seen || 0}</span>
              </div>
              <div class="mini-stat-row">
                <span class="mini-label">Pending Retries</span>
                <span>${sk.pendingRetries || 0}</span>
              </div>
              <div class="mini-stat-row">
                <span class="mini-label">Reply Tokens</span>
                <span>${sk.replyTokens || 0}</span>
              </div>
              <div class="mini-stat-row">
                <span class="mini-label">Channels</span>
                <span>${sk.channels || 0} / ${sk.ourChannels || 0} ours</span>
              </div>
              <div class="mini-stat-row">
                <span class="mini-label">Min Hops</span>
                <span>${sk.minHops || 0}${sk.adaptiveHops ? ` (effective: ${sk.effectiveMinHops || 0})` : ''}</span>
              </div>
              <div class="mini-stat-row">
                <span class="mini-label">Adaptive Hops</span>
                <span style="color: ${sk.adaptiveHops ? 'var(--green)' : 'var(--text-muted)'};">${sk.adaptiveHops ? 'on' : 'off'}</span>
              </div>
              <div class="mini-stat-row">
                <span class="mini-label">Batch Timer</span>
                <span style="color: ${sk.hasTimer ? 'var(--green)' : 'var(--text-muted)'};">${sk.hasTimer ? 'active' : 'idle'}</span>
              </div>
            </div>
          </div>
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
                <div class="nym-key">
                  key: ${this.shortId(n.pubkey)}
                  ${n.has_signing_key ? '<span class="badge badge-accepted" style="font-size:9px; margin-left:6px;">ed25519</span>' : ''}
                </div>
                <div class="nym-wallet">${n.wallet ? `wallet: ${n.wallet}` : 'no wallet set'}</div>
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
            ${this.state.listings.map(l => {
              const repStr = l.seller_reviews > 0
                ? `<span class="listing-rep" title="${l.seller_reviews} reviews">${l.seller_score}/100 (${l.seller_reviews})</span>`
                : '<span class="listing-rep" style="opacity:0.4">no reviews</span>';
              return `
              <div class="listing-card">
                <div class="listing-title">
                  ${this.esc(l.title)}
                  ${l.mine ? '<span class="badge badge-mine">yours</span>' : ''}
                </div>
                <div class="listing-desc">${this.esc(l.description)}</div>
                <div>
                  <span class="listing-price">${l.price}</span>
                  <span class="listing-currency">${l.currency}</span>
                  ${l.inventory > 0 ? `<span class="listing-inventory">&middot; ${l.inventory} left</span>` : ''}
                </div>
                <div class="listing-meta">
                  <span class="listing-seller">${l.seller_label ? this.esc(l.seller_label) : this.shortId(l.seller)} ${repStr}</span>
                  ${l.mine
                    ? `<button class="btn btn-sm btn-ghost" data-action="retract-listing" data-id="${l.id}">delete</button>`
                    : `<div style="display:flex;gap:6px;">
                        <button class="btn btn-sm btn-ghost" data-action="open-send-message" data-listing='${JSON.stringify(l)}'>Message</button>
                        <button class="btn btn-sm" data-action="open-send-offer" data-listing='${JSON.stringify(l)}'>Buy</button>
                      </div>`
                  }
                </div>
              </div>
              `;
            }).join('')}
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
    const myNymIds = new Set(this.state.nyms.map(n => n.id));
    const PAGE = 10;
    const page = this.state.threadsPage || 0;
    const all = this.state.threads;
    const paged = all.slice(page * PAGE, (page + 1) * PAGE);
    const totalPages = Math.ceil(all.length / PAGE);
    return `
      <div class="page-header">
        <h2>Threads</h2>
        <div class="page-desc">Negotiation conversations (${all.length})</div>
      </div>
      <div class="page-content">
        ${paged.length ? `
          <div class="thread-list">
            ${paged.map(t => {
              const listing = this.state.listings.find(l => l.id === t.listing_id);
              const title = listing ? this.esc(listing.title) : this.shortId(t.listing_id);
              const isBuyer = myNymIds.has(t.buyer);
              const isSeller = myNymIds.has(t.seller);
              const msgs = t.messages || [];
              return `
              <div class="card" style="margin-bottom: 12px;">
                <div style="display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 10px;">
                  <div>
                    <div style="font-size: 15px; font-weight: 600; color: var(--text-bright);">${title}</div>
                    <div class="thread-parties" style="margin-top: 4px;">
                      <span class="mono">${this.shortId(t.buyer)}</span>
                      ${isBuyer ? ' <span class="badge badge-mine" style="font-size:10px;">you</span>' : ''}
                      <span style="color: var(--text-muted); margin: 0 6px;">\u2194</span>
                      <span class="mono">${this.shortId(t.seller)}</span>
                      ${isSeller ? ' <span class="badge badge-mine" style="font-size:10px;">you</span>' : ''}
                    </div>
                  </div>
                  <span class="badge badge-${t.status}">${t.status}</span>
                </div>
                ${msgs.length ? `
                  <div class="thread-messages">
                    ${msgs.slice(-6).map(m => this.renderMessage(m, myNymIds)).join('')}
                  </div>
                ` : ''}
                <div style="display: flex; justify-content: space-between; align-items: center; padding-top: 10px; border-top: 1px solid var(--border-dim);">
                  <div style="font-size: 12px; color: var(--text-muted);">
                    ${t.amount ? this.fmtPrice(t.amount) + ' &middot; ' : ''}${t.message_count} message${t.message_count !== 1 ? 's' : ''} &middot; ${this.fmtDate(t.updated_at)}
                    ${t.chain ? ` &middot; chain: ${this.shortId(t.chain)}` : ''}
                  </div>
                  <div style="display: flex; gap: 8px;">
                    ${t.status === 'open' && isSeller ? `
                      <button class="btn btn-sm btn-primary" data-action="accept-offer" data-thread-id="${t.id}" data-offer-id="${t.id}">Accept</button>
                      <button class="btn btn-sm btn-ghost" data-action="reject-offer" data-thread-id="${t.id}" data-offer-id="${t.id}">Reject</button>
                    ` : ''}
                    ${t.status === 'open' && isBuyer ? `
                      <button class="btn btn-sm btn-ghost" data-action="reject-offer" data-thread-id="${t.id}" data-offer-id="${t.id}">Cancel</button>
                    ` : ''}
                    <button class="btn btn-sm" data-action="open-send-reply" data-thread-id="${t.id}">Reply</button>
                  </div>
                </div>
              </div>
              `;
            }).join('')}
          </div>
        ${totalPages > 1 ? `
          <div class="pagination">
            <button class="btn btn-sm" data-action="threads-prev" ${page === 0 ? 'disabled' : ''}>\u2190 Prev</button>
            <span class="page-info">${page + 1} / ${totalPages}</span>
            <button class="btn btn-sm" data-action="threads-next" ${page >= totalPages - 1 ? 'disabled' : ''}>Next \u2192</button>
          </div>
        ` : ''}
        ` : `
          <div class="empty-state">
            <div class="empty-icon">\u2261</div>
            <div class="empty-text">No negotiation threads</div>
          </div>
        `}
      </div>
    `;
  },

  renderMessage(m, myNymIds) {
    const isMine = m.sender && myNymIds.has(m.sender);
    const buyerActions = new Set(['offer', 'payment-proof', 'complete']);
    const sellerActions = new Set(['accept', 'reject', 'invoice', 'fulfill']);
    let direction = '';
    if (m.type === 'direct-message') {
      direction = isMine ? 'sent' : 'received';
    } else if (buyerActions.has(m.type) || sellerActions.has(m.type)) {
      direction = (buyerActions.has(m.type) && [...myNymIds].some(id => m.buyer === id))
        || (sellerActions.has(m.type) && [...myNymIds].some(id => m.seller === id))
        ? 'sent' : 'received';
    }
    const typeLabels = {
      'offer': 'Offer',
      'accept': 'Accepted',
      'reject': 'Rejected',
      'invoice': 'Invoice',
      'payment-proof': 'Payment',
      'fulfill': 'Fulfilled',
      'complete': 'Complete',
      'direct-message': direction === 'sent' ? 'Sent' : 'Received',
      'dispute': 'Dispute',
      'verdict': 'Verdict',
      'attest': 'Feedback',
      'ack': 'Ack',
      'escrow-propose': 'Escrow Proposed',
      'escrow-agree': 'Escrow Agreed',
      'escrow-funded': 'Escrow Funded',
      'escrow-sign-release': 'Release Sig',
      'escrow-sign-refund': 'Refund Sig',
      'moderator-profile': 'Moderator',
    };
    const label = typeLabels[m.type] || m.type;
    let detail = '';
    if (m.type === 'offer') detail = `${m.amount} sZ${m.note ? ' \u2014 ' + this.esc(m.note) : ''}`;
    else if (m.type === 'invoice') detail = `${m.amount} sZ \u2192 ${this.esc(m.pay_address || 'pending...')}`;
    else if (m.type === 'payment-proof') detail = `tx: ${this.esc(m.tx_hash)}`;
    else if (m.type === 'fulfill' && m.note) detail = this.esc(m.note);
    else if (m.type === 'direct-message') detail = this.esc(m.text);
    else if (m.type === 'reject' && m.reason) detail = this.esc(m.reason);
    else if (m.type === 'dispute' && m.reason) detail = this.esc(m.reason);
    else if (m.type === 'attest') detail = `${m.score}/100${m.note ? ' \u2014 ' + this.esc(m.note) : ''}`;
    else if (m.type === 'verdict') detail = `${m.ruling}${m.note ? ' \u2014 ' + this.esc(m.note) : ''}`;

    const dirIcon = direction === 'sent' ? '\u2191 ' : direction === 'received' ? '\u2193 ' : '';
    const rawTs = m.at || m.timestamp || m.expires_at;
    const ts = rawTs ? `<span class="msg-ts" style="font-size: 10px; color: var(--text-dim); margin-left: auto; white-space: nowrap;">${this.fmtTime(rawTs)}</span>` : '';
    return `
      <div class="msg-row ${direction === 'sent' ? 'msg-mine' : ''}" style="display: flex; align-items: center; gap: 8px;">
        <span class="msg-type badge badge-${m.type === 'direct-message' ? 'open' : m.type}">${dirIcon}${label}</span>
        <span class="msg-detail">${detail}</span>
        ${ts}
      </div>
    `;
  },

  // ---- orders ----

  orderStep(o) {
    if (o.status === 'completed') return 5;
    if (o.status === 'fulfilled') return 4;
    if (o.status === 'escrowed') return 3;
    if (o.status === 'paid') return 2;
    if (o.status === 'accepted' && o.has_invoice) return 1;
    if (o.status === 'escrow-agreed') return 1;
    if (o.status === 'escrow-proposed') return 0;
    return 0;
  },

  orderAction(o, role) {
    const tid = o.thread_id;
    const s = o.status;
    const inv = o.has_invoice;
    const cancelBtn = `<button class="btn btn-sm btn-ghost" data-action="open-cancel-thread" data-thread-id="${tid}">Cancel</button>`;

    if (s === 'offered') {
      if (role === 'seller') return { btn: `<button class="btn btn-sm btn-primary" data-action="accept-offer" data-thread-id="${tid}" data-offer-id="${tid}">Accept</button> ${cancelBtn}`, wait: '' };
      return { btn: cancelBtn, wait: 'Waiting for seller to respond' };
    }
    if (s === 'accepted' && !inv) {
      if (role === 'buyer') return {
        btn: `<button class="btn btn-sm" data-action="open-propose-escrow" data-thread-id="${tid}">Propose Escrow</button> ${cancelBtn}`,
        wait: 'You can propose escrow or wait for invoice',
      };
      if (role === 'seller') return { btn: `<button class="btn btn-sm btn-primary" data-action="open-send-invoice" data-thread-id="${tid}">Send Invoice</button> ${cancelBtn}`, wait: '' };
      return { btn: cancelBtn, wait: 'Waiting for seller to send invoice' };
    }
    if (s === 'escrow-proposed') {
      if (role === 'seller') return {
        btn: `<button class="btn btn-sm btn-primary" data-action="agree-escrow" data-thread-id="${tid}">Agree to Escrow</button> ${cancelBtn}`,
        wait: 'Buyer proposed escrow',
      };
      return { btn: cancelBtn, wait: 'Waiting for seller to agree to escrow' };
    }
    if (s === 'escrow-agreed') {
      if (role === 'seller') return { btn: cancelBtn, wait: 'Escrow agreed \u2014 invoice auto-sent to multisig address' };
      return { btn: cancelBtn, wait: 'Escrow agreed \u2014 waiting for invoice' };
    }
    if (s === 'accepted' && inv) {
      if (role === 'buyer') return {
        btn: `<button class="btn btn-sm btn-primary" data-action="open-pay-invoice" data-thread-id="${tid}">Pay via Zenith</button>
              <button class="btn btn-sm" data-action="open-submit-payment" data-thread-id="${tid}">Manual TX</button> ${cancelBtn}`,
        wait: o.pay_address ? `Pay to: <span class="mono">${this.esc(o.pay_address)}</span>` : 'Invoice sent \u2014 awaiting zenith address...',
      };
      return { btn: cancelBtn, wait: 'Invoice sent \u2014 waiting for payment' };
    }
    if (s === 'paid') {
      if (role === 'seller') return { btn: `<button class="btn btn-sm btn-primary" data-action="open-mark-fulfilled" data-thread-id="${tid}">Mark Fulfilled</button>`, wait: '' };
      return { btn: '', wait: 'Payment submitted \u2014 waiting for delivery' };
    }
    if (s === 'escrowed') {
      if (role === 'seller') return {
        btn: `<button class="btn btn-sm btn-primary" data-action="open-mark-fulfilled" data-thread-id="${tid}">Mark Fulfilled</button>
              <button class="btn btn-sm btn-danger" data-action="open-file-dispute" data-thread-id="${tid}">File Dispute</button>`,
        wait: 'Payment escrowed',
      };
      if (role === 'buyer') return {
        btn: `<button class="btn btn-sm" data-action="refund-escrow" data-thread-id="${tid}">Request Refund</button>
              <button class="btn btn-sm btn-danger" data-action="open-file-dispute" data-thread-id="${tid}">File Dispute</button>`,
        wait: 'Payment escrowed \u2014 waiting for delivery',
      };
      return { btn: '', wait: 'Payment escrowed \u2014 waiting for delivery' };
    }
    if (s === 'fulfilled') {
      if (role === 'buyer') return {
        btn: `<button class="btn btn-sm btn-primary" data-action="confirm-complete" data-thread-id="${tid}">Confirm Receipt</button>
              <button class="btn btn-sm btn-danger" data-action="open-file-dispute" data-thread-id="${tid}">File Dispute</button>`,
        wait: '',
      };
      if (role === 'seller') return {
        btn: `<button class="btn btn-sm btn-danger" data-action="open-file-dispute" data-thread-id="${tid}">File Dispute</button>`,
        wait: 'Delivered \u2014 waiting for buyer confirmation',
      };
      return { btn: '', wait: 'Delivered \u2014 waiting for buyer confirmation' };
    }
    if (s === 'completed') return {
      btn: `<button class="btn btn-sm" data-action="open-leave-feedback" data-thread-id="${tid}">Leave Feedback</button>`,
      wait: 'Order complete',
    };
    if (s === 'disputed') {
      if (role === 'buyer') return {
        btn: `<button class="btn btn-sm" data-action="refund-escrow" data-thread-id="${tid}">Sign Refund</button>`,
        wait: 'Dispute in progress \u2014 awaiting moderator ruling',
      };
      if (role === 'seller') return {
        btn: `<button class="btn btn-sm" data-action="release-escrow" data-thread-id="${tid}">Sign Release</button>
              <button class="btn btn-sm btn-ghost" data-action="refund-escrow" data-thread-id="${tid}">Agree to Refund</button>`,
        wait: 'Dispute in progress \u2014 awaiting moderator ruling',
      };
      return { btn: '', wait: 'Dispute in progress' };
    }
    if (s === 'resolved') return { btn: '', wait: 'Dispute resolved' };
    if (s === 'cancelled') return { btn: '', wait: 'Cancelled' };
    return { btn: '', wait: '' };
  },

  renderOrders() {
    const STEPS = ['accepted','invoiced','paid','escrowed','fulfilled','completed'];
    const myNymIds = new Set(this.state.nyms.map(n => n.id));
    const PAGE = 10;
    const page = this.state.ordersPage || 0;
    const all = [...this.state.orders].sort((a, b) => (b.updated_at || 0) - (a.updated_at || 0));
    const paged = all.slice(page * PAGE, (page + 1) * PAGE);
    const totalPages = Math.ceil(all.length / PAGE);
    return `
      <div class="page-header">
        <h2>Orders</h2>
        <div class="page-desc">Track order lifecycle (${all.length})</div>
      </div>
      <div class="page-content">
        ${paged.length ? `
          <div style="display: flex; flex-direction: column; gap: 16px;">
            ${paged.map(o => {
              const isBuyer = myNymIds.has(o.buyer);
              const isSeller = myNymIds.has(o.seller);
              const role = isBuyer ? 'buyer' : isSeller ? 'seller' : 'observer';
              const listing = this.state.listings.find(l => l.id === o.listing_id);
              const title = listing ? this.esc(listing.title) : this.shortId(o.listing_id);
              const stepIdx = this.orderStep(o);
              const { btn, wait } = this.orderAction(o, role);

              return `
                <div class="card">
                  <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 12px;">
                    <div>
                      <div style="font-size: 15px; font-weight: 600; color: var(--text-bright);">
                        ${title} &mdash; ${this.fmtPrice(o.amount)}
                      </div>
                      <div style="font-size: 12px; color: var(--text-dim); margin-top: 2px;">
                        ${role === 'buyer' ? 'You are the buyer' : role === 'seller' ? 'You are the seller' : this.shortId(o.thread_id)}
                      </div>
                    </div>
                    <span class="badge badge-${o.status.replace('escrow-','')}">${o.status}${o.status === 'accepted' && o.has_invoice ? ' (invoiced)' : ''}</span>
                  </div>
                  ${!['disputed','resolved','cancelled'].includes(o.status) ? `
                  <div class="order-timeline">
                    ${STEPS.map((step, i) => {
                      const reached = i <= stepIdx;
                      const current = i === stepIdx;
                      const dot = current ? 'current' : reached ? 'reached' : '';
                      const line = i < STEPS.length - 1
                        ? `<div class="timeline-line ${i < stepIdx ? 'reached' : ''}"></div>`
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
                  ` : ''}
                  ${(o.messages && o.messages.length) ? `
                    <div class="thread-messages" style="margin-top: 12px;">
                      ${o.messages.map(m => this.renderMessage(m, myNymIds)).join('')}
                    </div>
                  ` : ''}
                  ${o.escrow ? `
                    <div style="margin-top: 8px; padding: 10px; border-radius: var(--radius); background: var(--purple-dim); border: 1px solid rgba(139,92,246,0.2); font-size: 12px;">
                      <strong style="color: var(--purple);">Escrow:</strong>
                      <span style="color: var(--text);">${o.escrow.status}</span>
                      ${o.escrow.amount ? ` &middot; ${o.escrow.amount} ${o.escrow.currency || '$sZ'}` : ''}
                      ${o.escrow.sigs_collected != null ? ` &middot; sigs: ${o.escrow.sigs_collected}/2` : ''}
                      ${o.escrow.moderator_id ? ` &middot; moderator: <span class="mono">${this.shortId(o.escrow.moderator_id)}</span>` : ''}
                      ${o.escrow.multisig_address ? `
                        <div style="margin-top: 6px; padding: 6px 8px; background: var(--bg-inset); border-radius: 4px; cursor: pointer;" onclick="navigator.clipboard.writeText('${o.escrow.multisig_address}').then(() => App.toast('Multisig address copied'))" title="Click to copy">
                          <span style="color: var(--text-dim);">Multisig:</span> <span class="mono" style="color: var(--text-bright);">${this.esc(o.escrow.multisig_address)}</span>
                        </div>
                      ` : ''}
                      ${o.escrow.tx_hex && o.escrow.status !== 'confirmed' ? `
                        <div style="margin-top: 6px;">
                          <div style="color: var(--amber); font-weight: 600; margin-bottom: 4px;">TX Broadcast — awaiting confirmation</div>
                          <div class="mono" style="font-size: 11px; word-break: break-all; background: var(--bg-inset); padding: 6px; border-radius: 4px; max-height: 60px; overflow-y: auto; cursor: pointer;" onclick="navigator.clipboard.writeText('${o.escrow.tx_hex}').then(() => App.toast('TX hex copied'))" title="Click to copy">
                            ${o.escrow.tx_hex.slice(0, 100)}${o.escrow.tx_hex.length > 100 ? '...' : ''}
                          </div>
                        </div>
                      ` : ''}
                      ${o.escrow.status === 'confirmed' ? `
                        <div style="margin-top: 6px; padding: 8px; background: rgba(76,175,80,0.1); border: 1px solid rgba(76,175,80,0.3); border-radius: 4px;">
                          <span style="color: #4CAF50; font-weight: 600;">&#10003; Escrow TX confirmed on chain</span>
                        </div>
                      ` : ''}
                    </div>
                  ` : ''}
                  ${o.pay_address ? `<div style="font-size: 11px; color: var(--text-muted); margin-top: 8px;">Pay address: <span class="mono">${this.esc(o.pay_address)}</span></div>` : ''}
                  ${o.verification ? `
                    <div style="margin-top: 8px; padding: 8px; border-radius: var(--radius); font-size: 12px; background: ${o.verification.verified ? 'rgba(76,175,80,0.1)' : 'rgba(233,69,96,0.1)'}; border: 1px solid ${o.verification.verified ? 'rgba(76,175,80,0.3)' : 'rgba(233,69,96,0.3)'};">
                      ${o.verification.verified ? '\u2713 Payment verified' : '\u2717 Payment NOT verified'} &mdash; Address balance: ${o.verification.balance} sZ (checked ${this.fmtDate(o.verification.checked_at)})
                    </div>
                  ` : ''}
                  <div style="display: flex; justify-content: space-between; align-items: center; margin-top: 12px; min-height: 32px;">
                    <div style="font-size: 12px; color: var(--amber);">
                      ${wait}
                    </div>
                    <div style="display: flex; gap: 8px; align-items: center;">
                      ${['paid','escrowed','fulfilled','completed'].includes(o.status) ? `<button class="btn btn-sm btn-ghost" data-action="verify-payment" data-thread-id="${o.thread_id || o.id}">Verify on Zenith</button>` : ''}
                      ${btn}
                    </div>
                  </div>
                </div>
              `;
            }).join('')}
          </div>
        ${totalPages > 1 ? `
          <div class="pagination">
            <button class="btn btn-sm" data-action="orders-prev" ${page === 0 ? 'disabled' : ''}>\u2190 Prev</button>
            <span class="page-info">${page + 1} / ${totalPages}</span>
            <button class="btn btn-sm" data-action="orders-next" ${page >= totalPages - 1 ? 'disabled' : ''}>Next \u2192</button>
          </div>
        ` : ''}
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
    const scores = this.state.reputation || [];
    const attestations = this.state.attestations || [];
    const nymLabel = (id) => {
      const n = this.state.nyms.find(n => n.id === id);
      return n ? this.esc(n.label) : this.shortId(id);
    };
    return `
      <div class="page-header">
        <h2>Reputation</h2>
        <div class="page-desc">Trust scores for pseudonyms</div>
      </div>
      <div class="page-content">
        ${scores.length ? `
          <div class="rep-grid">
            ${scores.map(r => `
              <div class="rep-card">
                <div class="rep-nym">${nymLabel(r.nym_id)}</div>
                <div class="rep-score">${r.score}<span style="font-size: 14px; color: var(--text-muted);">/100</span></div>
                <div class="rep-label">${r.count} review${r.count !== 1 ? 's' : ''}</div>
              </div>
            `).join('')}
          </div>
        ` : `
          <div class="empty-state">
            <div class="empty-icon">\u2605</div>
            <div class="empty-text">No reputation data yet</div>
          </div>
        `}
        ${attestations.length ? `
          <div class="table-wrap" style="margin-top: 24px;">
            <div class="table-header">
              <div class="table-title">Recent Attestations</div>
            </div>
            <table>
              <thead><tr><th>Subject</th><th>Issuer</th><th>Kind</th><th>Score</th><th>Note</th><th>Sig</th><th>Date</th></tr></thead>
              <tbody>
                ${attestations.map(a => `
                  <tr>
                    <td class="mono truncate">${nymLabel(a.subject)}</td>
                    <td class="mono truncate">${nymLabel(a.issuer)}</td>
                    <td>${a.kind}</td>
                    <td>${a.score}/100</td>
                    <td>${this.esc(a.note)}</td>
                    <td>${a.sig && a.sig !== '0x0' ? '<span style="color:var(--green);" title="signed">\u2713</span>' : '<span style="color:var(--text-muted);">\u2014</span>'}</td>
                    <td class="mono">${this.fmtDate(a.issued_at)}</td>
                  </tr>
                `).join('')}
              </tbody>
            </table>
          </div>
        ` : ''}
      </div>
    `;
  },

  // ---- moderators ----

  renderModerators() {
    const mods = this.state.moderators || [];
    return `
      <div class="page-header">
        <h2>Moderators</h2>
        <div class="page-desc">Dispute resolvers for escrow transactions</div>
      </div>
      <div class="page-content">
        <div style="margin-bottom: 20px; display: flex; gap: 8px;">
          <button class="btn btn-primary" data-action="open-register-moderator">+ Register as Moderator</button>
        </div>
        ${mods.length ? `
          <div style="display: flex; flex-direction: column; gap: 12px;">
            ${mods.map(m => {
              const nymObj = this.state.nyms.find(n => n.id === m.nym_id);
              const nymLabel = nymObj ? this.esc(nymObj.label) : this.shortId(m.nym_id);
              const feePct = (m.fee_bps / 100).toFixed(1);
              return `
                <div class="card">
                  <div style="display: flex; justify-content: space-between; align-items: flex-start;">
                    <div>
                      <div style="font-size: 15px; font-weight: 600; color: var(--text-bright);">
                        ${nymLabel}
                        <span style="font-size: 12px; font-weight: 400; color: var(--text-muted); margin-left: 8px;">fee: ${feePct}%</span>
                      </div>
                      <div style="font-size: 12px; color: var(--text-muted); margin-top: 4px;">
                        ${this.esc(m.description || 'No description')}
                      </div>
                      <div style="font-size: 11px; color: var(--text-dim); margin-top: 6px;">
                        <span class="mono">addr: ${this.shortId(m.address)}</span>
                        &middot; stake: ${m.stake_amount || 0} sZ
                        &middot; pubkey: ${this.shortId(m.pubkey)}
                      </div>
                    </div>
                    <div style="display: flex; gap: 8px; align-items: center;">
                      <span class="badge badge-accepted">active</span>
                      ${nymObj ? `<button class="btn btn-sm btn-ghost" data-action="retract-moderator" data-id="${m.id}">retract</button>` : ''}
                    </div>
                  </div>
                </div>
              `;
            }).join('')}
          </div>
        ` : `
          <div class="empty-state">
            <div class="empty-icon">\u2696</div>
            <div class="empty-text">No moderators registered yet</div>
          </div>
        `}
        ${this.renderMyEscrows()}
      </div>
    `;
  },

  renderMyEscrows() {
    const escrows = this.state.myEscrows || [];
    return `
      <div style="margin-top: 24px; border-top: 1px solid var(--border); padding-top: 20px;">
        <h3 style="font-size: 16px; font-weight: 600; color: var(--text-bright); margin-bottom: 12px;">My Escrows (Moderator)
          ${escrows.filter(e => e.status === 'disputed').length ? `<span class="badge badge-disputed" style="margin-left: 8px;">${escrows.filter(e => e.status === 'disputed').length} disputed</span>` : ''}
        </h3>
        ${!escrows.length ? `
          <div class="empty-state" style="padding: 20px;">
            <div class="empty-text">No escrows assigned to you yet. When a buyer proposes escrow with you as moderator, it will appear here.</div>
          </div>
        ` : `
        <div style="display: flex; flex-direction: column; gap: 12px;">
          ${escrows.map(e => {
            const canSign = ['disputed', 'releasing', 'refunding', 'funded'].includes(e.status);
            return `
              <div class="card">
                <div style="display: flex; justify-content: space-between; align-items: flex-start;">
                  <div>
                    <div style="font-size: 13px; color: var(--text-muted);">
                      Thread: <span class="mono">${this.shortId(e.thread_id)}</span>
                    </div>
                    <div style="font-size: 13px; color: var(--text-muted); margin-top: 4px;">
                      Buyer: <span class="mono">${this.shortId(e.buyer || '')}</span>
                      &middot; Seller: <span class="mono">${this.shortId(e.seller || '')}</span>
                    </div>
                    <div style="font-size: 14px; font-weight: 600; color: var(--text-bright); margin-top: 6px;">
                      ${e.amount} ${e.currency}
                    </div>
                    <div style="font-size: 12px; color: var(--text-dim); margin-top: 4px;">
                      Multisig: <span class="mono">${e.multisig_address || 'not yet derived'}</span>
                    </div>
                    <div style="font-size: 12px; color: var(--text-dim); margin-top: 2px;">
                      Sigs: ${e.sigs_collected}/2
                      ${e.tx_hex ? ` &middot; <span style="color: var(--accent);">TX ready</span>` : ''}
                    </div>
                    ${e.tx_hex ? `
                      <div style="margin-top: 8px;">
                        <div style="font-size: 11px; color: var(--text-dim); margin-bottom: 4px;">Broadcast TX hex:</div>
                        <div class="mono" style="font-size: 11px; word-break: break-all; background: var(--bg-inset); padding: 8px; border-radius: 6px; max-height: 80px; overflow-y: auto; cursor: pointer;" onclick="navigator.clipboard.writeText('${e.tx_hex}').then(() => App.toast('TX hex copied'))">
                          ${e.tx_hex.slice(0, 120)}${e.tx_hex.length > 120 ? '...' : ''}
                        </div>
                      </div>
                    ` : ''}
                  </div>
                  <div style="display: flex; flex-direction: column; gap: 6px; align-items: flex-end;">
                    <span class="badge badge-${e.status === 'disputed' ? 'disputed' : e.status === 'released' || e.status === 'refunded' ? 'completed' : 'accepted'}">${e.status}</span>
                    ${canSign ? `
                      <button class="btn btn-sm btn-primary" data-action="mod-sign-release" data-tid="${e.thread_id}">Sign Release</button>
                      <button class="btn btn-sm btn-ghost" data-action="mod-sign-refund" data-tid="${e.thread_id}">Sign Refund</button>
                    ` : ''}
                  </div>
                </div>
              </div>
            `;
          }).join('')}
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
    const trusted = this.state.skeinTrusted || [];
    const trustedSet = new Set(Array.isArray(trusted) ? trusted : []);
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
            <div class="stat-label">Trusted</div>
            <div class="stat-value">${sk.trustedRelays || 0}</div>
          </div>
          <div class="stat-card">
            <div class="stat-label">Healthy</div>
            <div class="stat-value">${sk.healthyRelays || 0}</div>
          </div>
          <div class="stat-card">
            <div class="stat-label">Peers</div>
            <div class="stat-value">${peers.length}</div>
          </div>
          <div class="stat-card">
            <div class="stat-label">Seeds</div>
            <div class="stat-value">${sk.seeds || 0}</div>
          </div>
          <div class="stat-card">
            <div class="stat-label">Retries</div>
            <div class="stat-value">${sk.pendingRetries || 0}</div>
          </div>
        </div>

        <div class="sub-grid" style="margin-bottom: 16px;">
          <div class="setting-row">
            <div class="setting-info">
              <div class="setting-label">Minimum Relay Hops</div>
              <div class="setting-desc">
                Intermediate relays before the final hop. ${sk.adaptiveHops ? `Effective: ${sk.effectiveMinHops || 0}` : 'Adaptive mode off'}
              </div>
            </div>
            <div class="setting-control">
              <button class="btn btn-sm" data-action="dec-min-hops" ${(sk.minHops || 0) === 0 ? 'disabled' : ''}>-</button>
              <span class="setting-value">${sk.minHops || 0}</span>
              <button class="btn btn-sm" data-action="inc-min-hops">+</button>
            </div>
          </div>

          <div class="setting-row">
            <div class="setting-info">
              <div class="setting-label">Adaptive Hops</div>
              <div class="setting-desc">
                Auto-scale min hops based on relay pool size
              </div>
            </div>
            <div class="setting-control">
              <button class="btn btn-sm ${sk.adaptiveHops ? 'btn-primary' : ''}" data-action="toggle-adaptive-hops">
                ${sk.adaptiveHops ? 'On' : 'Off'}
              </button>
            </div>
          </div>
        </div>

        ${(sk.minHops || 0) > 0 && (sk.relays || 0) <= (sk.minHops || 0) ? `
          <div class="alert alert-warn">
            Not enough relays to satisfy min-hops=${sk.minHops}. Messages may fail to route. Add more relays or reduce min-hops.
          </div>
        ` : ''}

        <div class="table-wrap" style="margin-bottom: 16px;">
          <div class="table-header">
            <div class="table-title">Marketplace Peers</div>
            <div style="display: flex; gap: 8px;">
              <button class="btn btn-sm" data-action="sync-catalog">Sync</button>
              <button class="btn btn-primary btn-sm" data-action="open-add-peer">+ Add Peer</button>
            </div>
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
            <div class="empty-state" style="padding: 30px 20px;">
              <div class="empty-text">No marketplace peers. Add peers or join the silk-market channel to auto-discover.</div>
            </div>
          `}
        </div>

        <div class="table-wrap" style="margin-bottom: 16px;">
          <div class="table-header">
            <div class="table-title">Relay Descriptors</div>
            <button class="btn btn-primary btn-sm" data-action="open-discover-relay">+ Discover Relay</button>
          </div>
          ${this.renderRelayTable(relays, trustedSet)}
        </div>

        <div class="table-wrap">
          <div class="table-header">
            <div class="table-title">Seeds</div>
            <button class="btn btn-primary btn-sm" data-action="open-add-seed">+ Add Seed</button>
          </div>
          ${this.renderSeedsInfo(sk)}
        </div>
      </div>
    `;
  },

  renderRelayTable(relays, trustedSet) {
    const entries = Array.isArray(relays) ? relays : [];
    if (!entries.length) {
      return `
        <div class="empty-state" style="padding: 30px 20px;">
          <div class="empty-text">No relays configured. Discover relays from known ships.</div>
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
            <th>Trust</th>
            <th>Expiry</th>
            <th></th>
          </tr>
        </thead>
        <tbody>
          ${entries.map(r => {
            const isTrusted = trustedSet.has(r.relay);
            return `
            <tr>
              <td class="mono">${this.esc(r.relay)}</td>
              <td class="mono">${this.esc(r.ship)}</td>
              <td>${r.weight || 1}</td>
              <td>
                <button class="btn btn-sm ${isTrusted ? 'btn-primary' : 'btn-ghost'}" data-action="toggle-trust-relay" data-relay="${this.esc(r.relay)}" data-trusted="${isTrusted}">
                  ${isTrusted ? '\u2605 trusted' : 'trust'}
                </button>
              </td>
              <td class="mono" style="font-size: 11px; color: var(--text-muted);">${r.expiry || '\u2014'}</td>
              <td style="text-align: right;">
                <button class="btn btn-sm btn-ghost" data-action="drop-relay" data-relay="${this.esc(r.relay)}">remove</button>
              </td>
            </tr>
            `;
          }).join('')}
        </tbody>
      </table>
    `;
  },

  renderSeedsInfo(sk) {
    const seedCount = sk.seeds || 0;
    if (!seedCount) {
      return `
        <div class="empty-state" style="padding: 30px 20px;">
          <div class="empty-text">No seed ships. Seeds bootstrap relay discovery.</div>
        </div>
      `;
    }
    return `
      <div style="padding: 16px 20px; font-size: 13px; color: var(--text);">
        ${seedCount} seed ship${seedCount !== 1 ? 's' : ''} configured for relay discovery.
      </div>
    `;
  },

  // ---- dialogs ----

  renderDialog() {
    if (!this.state.dialog) return '';
    const { name, data } = this.state.dialog;
    let content = '';

    if (name === 'create-nym') {
      const accs = this.state.zenithAccounts || [];
      const accOpts = accs.map(a =>
        `<option value="${this.esc(a.address)}">${this.esc(a.name)} (${this.esc(a.address)})</option>`
      ).join('');
      content = `
        <h3>Create Identity</h3>
        <div style="margin-bottom: 12px; font-size: 13px; color: var(--text-muted);">
          Creates a pseudonym with an Ed25519 signing keypair for attestation signatures.
        </div>
        <div class="form-group">
          <label>Label</label>
          <input type="text" id="nym-label" placeholder="my-vendor-name" autofocus>
        </div>
        <div class="form-group">
          <label>Zenith Wallet</label>
          ${accs.length ? `
            <select id="nym-wallet-select">
              <option value="">-- Select wallet --</option>
              ${accOpts}
              <option value="__manual__">Enter address manually...</option>
            </select>
            <input type="text" id="nym-wallet-manual" placeholder="zenith1..." style="display:none; margin-top:8px;">
          ` : `
            <input type="text" id="nym-wallet-manual" placeholder="zenith1...">
          `}
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
        <div class="form-group">
          <label>Price (sZ)</label>
          <input type="number" id="listing-price" placeholder="0">
        </div>
        <div class="form-group">
          <label>Inventory (0 = unlimited)</label>
          <input type="number" id="listing-inventory" value="0" min="0">
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
          <div style="font-size: 12px; color: var(--text-muted); margin-top: 4px;">Listed at ${this.fmtPrice(l.price)}</div>
        </div>
        <div class="form-group">
          <label>Your Identity</label>
          <select id="offer-nym">${nymOpts || '<option value="">no identities</option>'}</select>
        </div>
        <div class="form-group">
          <label>Amount (sZ)</label>
          <input type="number" id="offer-amount" value="${l.price}" readonly>
        </div>
        ${l.seller_wallet ? `<div style="font-size: 12px; color: var(--text-muted); margin-bottom: 12px;">Seller wallet: ${l.seller_wallet}</div>` : ''}
        <input type="hidden" id="offer-listing-id" value="${l.id}">
        <input type="hidden" id="offer-seller" value="${l.seller}">
        <div class="form-actions">
          <button class="btn" data-action="close-dialog">Cancel</button>
          <button class="btn btn-primary" data-action="submit-send-offer">Buy</button>
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

    if (name === 'cancel-thread') {
      content = `
        <h3>Cancel Order</h3>
        <div style="margin-bottom: 16px; font-size: 13px; color: var(--text-muted);">
          Cancel this order. Both parties will be notified.
        </div>
        <div class="form-group">
          <label>Reason (optional)</label>
          <input type="text" id="cancel-reason" placeholder="Changed my mind..." autofocus>
        </div>
        <input type="hidden" id="cancel-thread-id" value="${data.threadId || ''}">
        <div class="form-actions">
          <button class="btn" data-action="close-dialog">Back</button>
          <button class="btn btn-danger" data-action="submit-cancel-thread">Cancel Order</button>
        </div>
      `;
    }

    if (name === 'send-invoice') {
      content = `
        <h3>Send Invoice</h3>
        <div style="margin-bottom: 16px; font-size: 13px; color: var(--text-muted);">
          Invoice the buyer for this order. A rotated payment address will be assigned by Zenith.
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

    if (name === 'send-message') {
      const l = data;
      const nymOpts = this.state.nyms.map(n =>
        `<option value="${n.id}">${this.esc(n.label)}</option>`
      ).join('');
      content = `
        <h3>Message Seller</h3>
        <div style="margin-bottom: 16px; padding: 12px; background: var(--bg-primary); border-radius: var(--radius); border: 1px solid var(--border-dim);">
          <div style="font-weight: 600; color: var(--text-bright);">${this.esc(l.title)}</div>
          <div style="font-size: 12px; color: var(--text-muted); margin-top: 4px;">${this.fmtPrice(l.price)}</div>
        </div>
        <div class="form-group">
          <label>Your Identity</label>
          <select id="msg-nym">${nymOpts || '<option value="">no identities</option>'}</select>
        </div>
        <div class="form-group">
          <label>Message</label>
          <textarea id="msg-text" placeholder="Ask the seller a question..." autofocus></textarea>
        </div>
        <input type="hidden" id="msg-listing-id" value="${l.id}">
        <div class="form-actions">
          <button class="btn" data-action="close-dialog">Cancel</button>
          <button class="btn btn-primary" data-action="submit-send-message">Send</button>
        </div>
      `;
    }

    if (name === 'send-reply') {
      const nymOpts = this.state.nyms.map(n =>
        `<option value="${n.id}">${this.esc(n.label)}</option>`
      ).join('');
      content = `
        <h3>Reply</h3>
        <div class="form-group">
          <label>Your Identity</label>
          <select id="reply-nym">${nymOpts || '<option value="">no identities</option>'}</select>
        </div>
        <div class="form-group">
          <label>Message</label>
          <textarea id="reply-text" placeholder="Type your reply..." autofocus></textarea>
        </div>
        <input type="hidden" id="reply-thread-id" value="${data.threadId || ''}">
        <div class="form-actions">
          <button class="btn" data-action="close-dialog">Cancel</button>
          <button class="btn btn-primary" data-action="submit-send-reply">Send</button>
        </div>
      `;
    }

    if (name === 'leave-feedback') {
      const order = this.state.orders.find(o => o.thread_id === data.threadId)
        || this.state.threads.find(t => t.id === data.threadId);
      const myNymIds = new Set(this.state.nyms.map(n => n.id));
      let myNym = '';
      let counterLabel = 'counterparty';
      if (order) {
        if (myNymIds.has(order.buyer)) {
          myNym = order.buyer;
          counterLabel = 'seller';
        } else if (myNymIds.has(order.seller)) {
          myNym = order.seller;
          counterLabel = 'buyer';
        }
      }
      const nymObj = this.state.nyms.find(n => n.id === myNym);
      content = `
        <h3>Leave Feedback</h3>
        <div style="margin-bottom: 16px; font-size: 13px; color: var(--text-muted);">
          Rate the ${counterLabel}${nymObj ? ` as <strong style="color:var(--text-bright);">${this.esc(nymObj.label)}</strong>` : ''}.
          Attestation will be signed with your nym's Ed25519 key.
        </div>
        <div class="form-group">
          <label>Score (0-100)</label>
          <input type="number" id="feedback-score" min="0" max="100" value="80" autofocus>
        </div>
        <div class="form-group">
          <label>Note</label>
          <textarea id="feedback-note" placeholder="How was the transaction?"></textarea>
        </div>
        <input type="hidden" id="feedback-thread-id" value="${data.threadId || ''}">
        <input type="hidden" id="feedback-nym" value="${myNym}">
        <div class="form-actions">
          <button class="btn" data-action="close-dialog">Cancel</button>
          <button class="btn btn-primary" data-action="submit-leave-feedback">Submit</button>
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

    if (name === 'add-seed') {
      content = `
        <h3>Add Seed Ship</h3>
        <div style="margin-bottom: 16px; font-size: 13px; color: var(--text-muted);">
          Seed ships bootstrap relay discovery. Skein will subscribe to them for relay gossip.
        </div>
        <div class="form-group">
          <label>Ship</label>
          <input type="text" id="seed-ship" placeholder="~sampel-palnet" autofocus>
        </div>
        <div class="form-actions">
          <button class="btn" data-action="close-dialog">Cancel</button>
          <button class="btn btn-primary" data-action="submit-add-seed">Add Seed</button>
        </div>
      `;
    }

    if (name === 'register-moderator') {
      const nymOpts = this.state.nyms.map(n =>
        `<option value="${n.id}">${this.esc(n.label)}</option>`
      ).join('');
      content = `
        <h3>Register as Moderator</h3>
        <div style="margin-bottom: 16px; font-size: 13px; color: var(--text-muted);">
          Register one of your identities as an escrow dispute moderator. You must have a Zenith wallet with staked funds.
        </div>
        <div class="form-group">
          <label>Identity</label>
          <select id="mod-nym">${nymOpts || '<option value="">no identities</option>'}</select>
        </div>
        <div class="form-group">
          <label>Fee (basis points, 200 = 2%)</label>
          <input type="number" id="mod-fee-bps" value="200" min="0" max="10000">
        </div>
        <div class="form-group">
          <label>Stake Amount (sZ)</label>
          <input type="number" id="mod-stake" value="0" min="0">
        </div>
        <div class="form-group">
          <label>Description</label>
          <textarea id="mod-description" placeholder="Describe your moderation services..."></textarea>
        </div>
        <div class="form-actions">
          <button class="btn" data-action="close-dialog">Cancel</button>
          <button class="btn btn-primary" data-action="submit-register-moderator">Register</button>
        </div>
      `;
    }

    if (name === 'pay-invoice') {
      const accs = this.state.zenithAccounts || [];
      const accOpts = accs.map(a =>
        `<option value="${this.esc(a.name)}">${this.esc(a.name)} (${this.esc(a.address)})</option>`
      ).join('');
      content = `
        <h3>Pay via Zenith</h3>
        <div style="margin-bottom: 16px; font-size: 13px; color: var(--text-muted);">
          Send payment from a Zenith wallet. The balance will be polled automatically to confirm.
        </div>
        <div class="form-group">
          <label>Pay From Account</label>
          ${accs.length ? `
            <select id="pay-account">
              ${accOpts}
            </select>
          ` : `
            <input type="text" id="pay-account" placeholder="account name" value="default">
            <div style="font-size: 11px; color: var(--amber); margin-top: 4px;">No Zenith accounts found. Enter account name manually.</div>
          `}
        </div>
        <input type="hidden" id="pay-thread-id" value="${data.threadId || ''}">
        <div class="form-actions">
          <button class="btn" data-action="close-dialog">Cancel</button>
          <button class="btn btn-primary" data-action="submit-pay-invoice">Send Payment</button>
        </div>
      `;
    }

    if (name === 'propose-escrow') {
      const mods = this.state.moderators || [];
      const modOpts = mods.map(m => {
        const nymObj = this.state.nyms.find(n => n.id === m.nym_id);
        const label = nymObj ? this.esc(nymObj.label) : this.shortId(m.nym_id);
        const feePct = (m.fee_bps / 100).toFixed(1);
        return `<option value="${m.id}">${label} (${feePct}% fee, ${m.stake_amount || 0} sZ staked)</option>`;
      }).join('');
      content = `
        <h3>Propose Escrow</h3>
        <div style="margin-bottom: 16px; font-size: 13px; color: var(--text-muted);">
          Propose 2-of-3 multisig escrow with a moderator. The seller must agree before proceeding.
        </div>
        <div class="form-group">
          <label>Moderator</label>
          <select id="escrow-moderator">${modOpts || '<option value="">no moderators available</option>'}</select>
        </div>
        <div class="form-group">
          <label>Timeout (hours)</label>
          <input type="number" id="escrow-timeout" value="72" min="1">
        </div>
        <input type="hidden" id="escrow-thread-id" value="${data.threadId || ''}">
        <div class="form-actions">
          <button class="btn" data-action="close-dialog">Cancel</button>
          <button class="btn btn-primary" data-action="submit-propose-escrow">Propose</button>
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
          case 'submit-create-nym': {
            const sel = document.getElementById('nym-wallet-select');
            const manual = document.getElementById('nym-wallet-manual');
            const wallet = sel ? (sel.value === '__manual__' ? manual.value : sel.value) : (manual ? manual.value : '');
            this.action(() => SilkAPI.createNym(
              document.getElementById('nym-label').value,
              wallet
            ));
            break;
          }
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
              '$sZ',
              document.getElementById('listing-nym').value,
              parseInt(document.getElementById('listing-inventory').value) || 0,
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
              '$sZ',
              document.getElementById('offer-nym').value,
            ));
            break;
          case 'accept-offer':
            this.action(() => SilkAPI.acceptOffer(el.dataset.threadId, el.dataset.offerId));
            break;
          case 'reject-offer':
            this.action(() => SilkAPI.rejectOffer(el.dataset.threadId, el.dataset.offerId, 'declined'));
            break;
          case 'open-cancel-thread':
            this.openDialog('cancel-thread', { threadId: el.dataset.threadId });
            break;
          case 'submit-cancel-thread':
            this.action(() => SilkAPI.cancelThread(
              document.getElementById('cancel-thread-id').value,
              document.getElementById('cancel-reason').value || 'cancelled',
            ));
            break;
          case 'open-send-invoice':
            this.openDialog('send-invoice', { threadId: el.dataset.threadId });
            break;
          case 'submit-send-invoice':
            this.action(() => SilkAPI.sendInvoice(
              document.getElementById('invoice-thread-id').value,
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
          case 'verify-payment':
            this.action(async () => {
              const res = await SilkAPI.verifyPayment(el.dataset.threadId);
              if (res.verified === true) this.toast('Payment verified on Zenith', 'success');
              else if (res.verified === false) this.toast('Payment NOT verified \u2014 balance too low', 'error');
              else this.toast('Verification queued \u2014 refresh in a moment', '');
            });
            break;
          case 'open-pay-invoice':
            this.openDialog('pay-invoice', { threadId: el.dataset.threadId });
            break;
          case 'submit-pay-invoice': {
            const acc = document.getElementById('pay-account').value;
            const tid = document.getElementById('pay-thread-id').value;
            this.action(async () => {
              await SilkAPI.payInvoice(tid, acc);
              this.toast('Payment sent \u2014 polling for confirmation...', 'success');
            });
            break;
          }
          case 'open-send-message':
            this.openDialog('send-message', JSON.parse(el.dataset.listing));
            break;
          case 'submit-send-message':
            this.action(() => SilkAPI.sendMessage(
              document.getElementById('msg-listing-id').value,
              document.getElementById('msg-nym').value,
              document.getElementById('msg-text').value,
            ));
            break;
          case 'open-send-reply':
            this.openDialog('send-reply', { threadId: el.dataset.threadId });
            break;
          case 'submit-send-reply':
            this.action(() => SilkAPI.sendReply(
              document.getElementById('reply-thread-id').value,
              document.getElementById('reply-nym').value,
              document.getElementById('reply-text').value,
            ));
            break;
          case 'open-leave-feedback':
            this.openDialog('leave-feedback', { threadId: el.dataset.threadId });
            break;
          case 'submit-leave-feedback':
            this.action(() => SilkAPI.leaveFeedback(
              document.getElementById('feedback-thread-id').value,
              parseInt(document.getElementById('feedback-score').value) || 0,
              document.getElementById('feedback-note').value,
              document.getElementById('feedback-nym').value,
            ));
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
          case 'toggle-trust-relay':
            {
              const relay = el.dataset.relay;
              const isTrusted = el.dataset.trusted === 'true';
              this.action(() => isTrusted ? SilkAPI.untrustRelay(relay) : SilkAPI.trustRelay(relay));
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
          case 'toggle-adaptive-hops':
            this.action(() => SilkAPI.setAdaptiveHops(!this.state.skeinStats.adaptiveHops));
            break;
          case 'open-add-seed':
            this.openDialog('add-seed');
            break;
          case 'submit-add-seed':
            this.action(() => SilkAPI.addSeed(document.getElementById('seed-ship').value));
            break;
          case 'open-register-moderator':
            this.openDialog('register-moderator');
            break;
          case 'submit-register-moderator':
            this.action(() => SilkAPI.registerModerator(
              document.getElementById('mod-nym').value,
              parseInt(document.getElementById('mod-fee-bps').value) || 200,
              parseInt(document.getElementById('mod-stake').value) || 0,
              document.getElementById('mod-description').value,
            ));
            break;
          case 'retract-moderator':
            if (confirm('Retract this moderator registration?')) {
              this.action(() => SilkAPI.retractModerator(el.dataset.id));
            }
            break;
          case 'open-propose-escrow':
            this.openDialog('propose-escrow', { threadId: el.dataset.threadId });
            break;
          case 'submit-propose-escrow':
            {
              const hours = parseInt(document.getElementById('escrow-timeout').value) || 72;
              const timeoutSecs = hours * 3600;
              this.action(() => SilkAPI.proposeEscrow(
                document.getElementById('escrow-thread-id').value,
                document.getElementById('escrow-moderator').value,
                timeoutSecs,
              ));
            }
            break;
          case 'agree-escrow':
            this.action(() => SilkAPI.agreeEscrow(el.dataset.threadId));
            break;
          case 'release-escrow':
            if (confirm('Release escrow funds to seller?')) {
              this.action(() => SilkAPI.releaseEscrow(el.dataset.threadId));
            }
            break;
          case 'refund-escrow':
            if (confirm('Request escrow refund?')) {
              this.action(() => SilkAPI.refundEscrow(el.dataset.threadId));
            }
            break;
          case 'mod-sign-release':
            if (confirm('Sign release as moderator? Funds will go to seller.')) {
              this.action(() => SilkAPI.signEscrow(el.dataset.tid, 'release'));
            }
            break;
          case 'mod-sign-refund':
            if (confirm('Sign refund as moderator? Funds will go to buyer.')) {
              this.action(() => SilkAPI.signEscrow(el.dataset.tid, 'refund'));
            }
            break;
          case 'rebroadcast-escrow':
            this.action(() => SilkAPI.rebroadcastEscrow(el.dataset.threadId));
            break;
          case 'open-file-dispute': {
            const tid = el.dataset.threadId;
            const reason = prompt('Describe why you are disputing this order:');
            if (!reason) break;
            const order = this.state.orders.find(o => o.thread_id === tid);
            const nym = order ? order.buyer : '';
            this.action(() => SilkAPI.fileDispute(tid, reason, nym));
            break;
          }
          case 'threads-prev':
            this.state.threadsPage = Math.max(0, (this.state.threadsPage || 0) - 1);
            this.render();
            break;
          case 'threads-next':
            this.state.threadsPage = (this.state.threadsPage || 0) + 1;
            this.render();
            break;
          case 'orders-prev':
            this.state.ordersPage = Math.max(0, (this.state.ordersPage || 0) - 1);
            this.render();
            break;
          case 'orders-next':
            this.state.ordersPage = (this.state.ordersPage || 0) + 1;
            this.render();
            break;
          case 'close-dialog':
          case 'close-dialog-bg':
            this.closeDialog();
            break;
        }
      });
    });
    // wallet select toggle for manual entry
    const walletSel = document.getElementById('nym-wallet-select');
    if (walletSel) {
      walletSel.addEventListener('change', () => {
        const manual = document.getElementById('nym-wallet-manual');
        if (manual) manual.style.display = walletSel.value === '__manual__' ? '' : 'none';
      });
    }
  },

  esc(str) {
    if (!str) return '';
    const div = document.createElement('div');
    div.textContent = str;
    return div.innerHTML;
  },
};

document.addEventListener('DOMContentLoaded', () => App.init());
