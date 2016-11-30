// Wrapper around browser storage (auto JSON stringify & parse).
var crossbeamsLocalStorage = {
  //storageAdaptor: sessionStorage,
  storageAdaptor: localStorage,

  // Thanks Angus! - http://goo.gl/GtvsU
  toType: function(obj) {
    return ({}).toString.call(obj).match(/\s([a-z|A-Z]+)/)[1].toLowerCase();
  },

  hasItem: function(key) {
    return this.storageAdaptor.getItem(key) !== null;
  },

  getItem: function(key) {
    var item = this.storageAdaptor.getItem(key);

    try {
      item = JSON.parse(item);
    } catch (e) {}

    return item;
  },

  setItem: function(key, value) {
    var type = this.toType(value);

    if (/object|array/.test(type)) {
      value = JSON.stringify(value);
    }

    this.storageAdaptor.setItem(key, value);
  },

  removeItem: function(key) {
    this.storageAdaptor.removeItem(key);
  },

  genStandardKey: function(suffix) {
    var rx  = new RegExp('/\\d+$');
    if (suffix === undefined) {
      return window.location.pathname.replace(rx,'');
    }
    else {
      return window.location.pathname.replace(rx,'') +'|'+ suffix;
    }
  }
};

