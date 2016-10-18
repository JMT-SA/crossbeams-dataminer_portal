// General utility functions for Crossbeams.

var crossbeamsUtils = {

  // Toggle the visibility of en element in the DOM:
  // Optionally pass in a button to add the pure-button-active class (Pure.css)
  toggle_visibility: function(id, button) {
    var e = document.getElementById(id);

    if ( e.style.display == 'block' ) {
      e.style.display = 'none';
      if(button !== undefined) {
        button.classList.remove('pure-button-active');
      }
    }
    else {
      e.style.display = 'block';
      if(button !== undefined) {
        button.classList.add('pure-button-active');
      }
    }
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

