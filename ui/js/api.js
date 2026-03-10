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

  // writes
  createNym(label)  { return this.post({ action: 'create-nym', label }); },
  dropNym(id)       { return this.post({ action: 'drop-nym', id }); },

  postListing(title, description, price, currency, nym) {
    return this.post({ action: 'post-listing', title, description, price, currency, nym });
  },
  retractListing(id) { return this.post({ action: 'retract-listing', id }); },

  sendOffer(listing_id, seller, amount, currency, nym) {
    return this.post({ action: 'send-offer', listing_id, seller, amount, currency, nym });
  },
  acceptOffer(thread_id, offer_id) {
    return this.post({ action: 'accept-offer', thread_id, offer_id });
  },
  rejectOffer(thread_id, offer_id, reason) {
    return this.post({ action: 'reject-offer', thread_id, offer_id, reason });
  },
};
