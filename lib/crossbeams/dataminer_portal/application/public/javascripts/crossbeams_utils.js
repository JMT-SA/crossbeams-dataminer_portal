// General utility functions for Crossbeams.

var crossbeamsUtils = {

  // Toggle the visibility of en element in the DOM:
  toggle_visibility: function(id) {
    var e = document.getElementById(id);

    if ( e.style.display == 'block' )
      e.style.display = 'none';
    else
      e.style.display = 'block';
  }

};

