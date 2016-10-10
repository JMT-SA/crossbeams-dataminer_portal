// General utility functions for Crossbeams.

var crossbeamsUtils = {

  // Toggle the visibility of en element in the DOM:
  toggle_visibility: function(id) {
    var e = document.getElementById(id);

    if ( e.style.display == 'block' )
      e.style.display = 'none';
    else
      e.style.display = 'block';
  },

  getCharCodeFromEvent: function(event) {
    event = event || window.event;
    return (typeof event.which == "undefined") ? event.keyCode : event.which;
  },

  isCharNumeric: function(charStr) {
    return !!/\d/.test(charStr);
  },

  isKeyPressedNumeric: function(event) {
    var charCode = this.getCharCodeFromEvent(event);
    var charStr = String.fromCharCode(charCode);
    return this.isCharNumeric(charStr);

  }

};

