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
  createNym(label, wallet)  { return this.post({ action: 'create-nym', label, wallet }); },
  dropNym(id)       { return this.post({ action: 'drop-nym', id }); },

  postListing(title, description, price, currency, nym, inventory) {
    return this.post({ action: 'post-listing', title, description, price, currency, nym, inventory: inventory || 0 });
  },
  retractListing(id) { return this.post({ action: 'retract-listing', id }); },
  updateInventory(id, inventory) {
    return this.post({ action: 'update-inventory', id, inventory });
  },

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
  cancelThread(thread_id, reason) {
    return this.post({ action: 'cancel-thread', thread_id, reason });
  },

  sendInvoice(thread_id) {
    return this.post({ action: 'send-invoice', thread_id });
  },
  submitPayment(thread_id, tx_hash) {
    return this.post({ action: 'submit-payment', thread_id, tx_hash });
  },
  payInvoice(thread_id, account) {
    return this.post({ action: 'pay-invoice', thread_id, account: account || 'default' });
  },
  markFulfilled(thread_id, note) {
    return this.post({ action: 'mark-fulfilled', thread_id, note });
  },
  confirmComplete(thread_id) {
    return this.post({ action: 'confirm-complete', thread_id });
  },
  verifyPayment(thread_id) {
    return this.post({ action: 'verify-payment', thread_id });
  },

  leaveFeedback(thread_id, score, note, nym) {
    return this.post({ action: 'leave-feedback', thread_id, score, note, nym });
  },
  fileDispute(thread_id, reason, nym) {
    return this.post({ action: 'file-dispute', thread_id, reason, nym });
  },
  sendMessage(listing_id, nym, text) {
    return this.post({ action: 'send-message', listing_id, nym, text });
  },
  sendReply(thread_id, nym, text) {
    return this.post({ action: 'send-reply', thread_id, nym, text });
  },

  // zenith
  getZenithAccounts() { return this.get('zenith-accounts'); },

  // moderators
  getModerators()   { return this.get('moderators'); },
  getEscrow(thread_id) { return this.get(`escrow/${thread_id}`); },

  registerModerator(nym_id, fee_bps, stake_amount, description) {
    return this.post({ action: 'register-moderator', nym_id, fee_bps, stake_amount, description });
  },
  retractModerator(id) {
    return this.post({ action: 'retract-moderator', id });
  },

  // escrow
  getMyEscrows()    { return this.get('my-escrows'); },

  signEscrow(thread_id, escrow_action) {
    return this.post({ action: 'sign-escrow', thread_id, escrow_action });
  },
  rebroadcastEscrow(thread_id) {
    return this.post({ action: 'rebroadcast-escrow', thread_id });
  },

  proposeEscrow(thread_id, moderator, timeout) {
    return this.post({ action: 'propose-escrow', thread_id, moderator, timeout });
  },
  agreeEscrow(thread_id) {
    return this.post({ action: 'agree-escrow', thread_id });
  },
  fundEscrow(thread_id, tx_hash) {
    return this.post({ action: 'fund-escrow', thread_id, tx_hash });
  },
  releaseEscrow(thread_id) {
    return this.post({ action: 'release-escrow', thread_id });
  },
  refundEscrow(thread_id) {
    return this.post({ action: 'refund-escrow', thread_id });
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

  getRelays()      { return this.skeinGet('relays'); },
  getSkeinStats()  { return this.skeinGet('stats'); },
  getSkeinHealth() { return this.skeinGet('health'); },
  getSkeinTrusted(){ return this.skeinGet('trusted'); },
  getSkeinChannels(){ return this.skeinGet('channels'); },

  discoverRelay(ship) {
    return this.skeinPost({ action: 'put-relay', ship });
  },
  dropRelay(relay) {
    return this.skeinPost({ action: 'drop-relay', relay });
  },
  setMinHops(n) {
    return this.skeinPost({ action: 'set-min-hops', n });
  },
  addSeed(ship) {
    return this.skeinPost({ action: 'add-seed', ship });
  },
  dropSeed(ship) {
    return this.skeinPost({ action: 'drop-seed', ship });
  },
  setAdaptiveHops(on) {
    return this.skeinPost({ action: 'set-adaptive-hops', on });
  },
  trustRelay(relay) {
    return this.skeinPost({ action: 'trust-relay', relay });
  },
  untrustRelay(relay) {
    return this.skeinPost({ action: 'untrust-relay', relay });
  },
};
