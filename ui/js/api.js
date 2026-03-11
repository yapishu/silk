window.SilkAPI = {
  base: '/apps/silk/api',

  async get(path) {
    const res = await fetch(`${this.base}/${path}`, {
      credentials: 'include',
    });
    if (!res.ok) throw new Error(`GET ${path}: ${res.status}`);
    return res.json();
  },

  async post(action) {
    const res = await fetch(this.base, {
      method: 'POST',
      credentials: 'include',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(action),
    });
    if (!res.ok) throw new Error(`POST: ${res.status}`);
    return res.json();
  },

  // reads
  getNyms()       { return this.get('nyms'); },
  getListings()   { return this.get('listings'); },
  getThreads()    { return this.get('threads'); },
  getOrders()     { return this.get('orders'); },
  getReputation() { return this.get('reputation'); },
  getStats()      { return this.get('stats'); },
  getPeers()      { return this.get('peers'); },

  // writes
  createNym(label)  { return this.post({ action: 'create-nym', label }); },
  dropNym(id)       { return this.post({ action: 'drop-nym', id }); },

  postListing(title, description, price, currency, nym) {
    return this.post({ action: 'post-listing', title, description, price, currency, nym });
  },
  retractListing(id) { return this.post({ action: 'retract-listing', id }); },

  addPeer(ship)     { return this.post({ action: 'add-peer', ship }); },
  dropPeer(ship)    { return this.post({ action: 'drop-peer', ship }); },
  syncCatalog()     { return this.post({ action: 'sync-catalog' }); },

  sendOffer(listing_id, seller, amount, currency, nym) {
    return this.post({ action: 'send-offer', listing_id, seller, amount, currency, nym });
  },
  acceptOffer(thread_id, offer_id) {
    return this.post({ action: 'accept-offer', thread_id, offer_id });
  },
  rejectOffer(thread_id, offer_id, reason) {
    return this.post({ action: 'reject-offer', thread_id, offer_id, reason });
  },

  sendInvoice(thread_id, pay_address) {
    return this.post({ action: 'send-invoice', thread_id, pay_address });
  },
  submitPayment(thread_id, tx_hash) {
    return this.post({ action: 'submit-payment', thread_id, tx_hash });
  },
  markFulfilled(thread_id, note) {
    return this.post({ action: 'mark-fulfilled', thread_id, note });
  },
  confirmComplete(thread_id) {
    return this.post({ action: 'confirm-complete', thread_id });
  },

  // skein relay management (talks to skein API on same ship)
  skeinBase: '/apps/skein/api',

  async skeinGet(path) {
    const res = await fetch(`${this.skeinBase}/${path}`, { credentials: 'include' });
    if (!res.ok) throw new Error(`GET skein/${path}: ${res.status}`);
    return res.json();
  },

  async skeinPost(action) {
    const res = await fetch(this.skeinBase, {
      method: 'POST',
      credentials: 'include',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(action),
    });
    if (!res.ok) throw new Error(`POST skein: ${res.status}`);
    return res.json();
  },

  getRelays()     { return this.skeinGet('relays'); },
  getSkeinStats() { return this.skeinGet('stats'); },

  discoverRelay(ship) {
    return this.skeinPost({ action: 'put-relay', ship });
  },
  dropRelay(relay) {
    return this.skeinPost({ action: 'drop-relay', relay });
  },
  setMinHops(n) {
    return this.skeinPost({ action: 'set-min-hops', n });
  },
};
