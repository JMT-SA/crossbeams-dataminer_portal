
// Object to keep track of the grids in a page - so they can be looked up by div id.
var crossbeamsGridStore = {

  gridStore: {},

  addGrid: function(gridId, gridOptions) {
    this.gridStore[gridId] = gridOptions;
  },

  getGrid: function(gridId) {
    return this.gridStore[gridId];
  },

  removeGrid: function(gridId) {
    this.gridStore[gridId].api.destroy();
    delete this.gridStore[gridId];
  },

  listGridIds: function() {
    var grid_id, lst = [];
    for(grid_id in this.gridStore) {
      lst.push(grid_id);
    }
    return lst.join(', ');
  }

};

var crossbeamsGridEvents = {

  csvExport: function(grid_id, file_name) {
    var visibleCols, colKeys = [], gridOptions;

    // Get visible columns that do not explicitly have "suppressCsvExport" set.
    gridOptions = crossbeamsGridStore.getGrid(grid_id);
    visibleCols = gridOptions.columnApi.getAllDisplayedColumns();

    for (_i = 0, _len = visibleCols.length; _i < _len; _i++) {
      if(visibleCols[_i].colDef.suppressCsvExport && visibleCols[_i].colDef.suppressCsvExport === true) {
      }
      else {
        colKeys.push(visibleCols[_i].colId);
      }
    }

    var params = {
      fileName: file_name,
      columnKeys: colKeys // Visible, non-suppressed columns.
      // skipHeader: true,
      // skipFooters: true,
      // skipGroups: true,
      // allColumns: true,
      // suppressQuotes: true,
      // onlySelected: true,
      // columnSeparator: ';'
    };

    // Ensure long numbers are exported as strings.
    params.processCellCallback = function(params) {
      var testStr;
      // If HTML entities are a problem...
      // params.value.replace(/&amp;/g, "&").replace(/\\&quot;/g, "\"").replace(/&quot;/g, "\"").replace(/&gt;/g, ">").replace(/&#x2F;/g, "/").replace(/&lt;/g, "<");

      if (params.value) {
        testStr = ''+params.value;
        if (testStr.length > 12 && !isNaN(testStr) && !testStr.includes('.')) {
          return "'"+testStr;
        }
        else {
          return params.value;
        }
      }
      else {
        return params.value;
      }
    };

    gridOptions.api.exportDataAsCsv(params);
  },

  toggleToolPanel: function(grid_id) {
    var gridOptions, isShowing;
    gridOptions = crossbeamsGridStore.getGrid(grid_id);
    isShowing = gridOptions.api.isToolPanelShowing();
    gridOptions.api.showToolPanel( !isShowing );
  },

  printAGrid: function(grid_id, grid_url) {
     var disp_setting =  "toolbar=yes,location=no,directories=yes,menubar=yes,";
         //disp_setting += "scrollbars=yes,width=650, height=600, left=100, top=25";
    window.open("/print_grid?grid_url="+encodeURIComponent(grid_url), "printGrid", disp_setting);
  },

  quickSearch: function(event) {
    var gridOptions;
    // clear on Esc
    if (event.which == 27) {
      event.target.value = "";
    }
    gridOptions = crossbeamsGridStore.getGrid(event.target.dataset.gridId);
    gridOptions.api.setQuickFilter(event.target.value);
  },

  // setFilterChangeEvent: function(grid_id) {
  //   var gridOptions;
  //
  //   gridOptions = crossbeamsGridStore.getGrid(grid_id);
  //   gridOptions.api.afterFilterChanged();
  //   //.api.rowModel.rootNode.childrenAfterFilter.length
  //
  // }
  showFilterChange: function(grid_id) {
    var gridOptions, filterLength;
    gridOptions = crossbeamsGridStore.getGrid(grid_id);
    if(gridOptions.api.rowModel.rootNode.childrenAfterFilter) {
      filterLength = gridOptions.api.rowModel.rootNode.childrenAfterFilter.length;
    }
    else {
      filterLength = 0;
    }
    console.log('onAfterFilterChanged', filterLength, grid_id);
  },

  promptClick: function(target) {
    var target = event.target;
    var prompt = target.dataset.prompt,
        url    = target.dataset.url,
        method = target.dataset.method;

    if (confirm(prompt)) {
      document.body.innerHTML += '<form id="dynForm" action="' + url +
        '" method="post"><input name="_method" type="hidden" value="'+method+'" /></form>';
      document.getElementById("dynForm").submit();
    }
    //TODO: make call via AJAX & reload grid? Or http to server to figure it out?.....
    //ALSO: disable link automatically while call is being processed...
    event.stopPropagation();
    event.preventDefault();
  }

};

var crossbeamsGridFormatters = {
  testRender: function(params) {
    return '<b>' + params.value.toUpperCase() + '</b>';
  },

  // Return a number with thousand separator and at least 2 digits after the decimal.
  numberWithCommas2: function (params) {
    var x = params.value;
    if (typeof x === 'string') { x = parseFloat(x); }
    if (isNaN(x)) { return ''; }
    x = Math.round((x + 0.00001) * 100) / 100 // Round to 2 digits if longer.
    var parts = x.toString().split(".");
    parts[0] = parts[0].replace(/\B(?=(\d{3})+(?!\d))/g, ",");
    if(parts[1] === undefined || parts[1].length === 0) {parts[1] = '00'; }
    if(parts[1].length === 1) {parts[1] += '0'; }
    return parts.join(".");
  },

  // Return a number with thousand separator and at least 4 digits after the decimal.
  numberWithCommas4: function (params) {
    var x = params.value;
    if (typeof x === 'string') { x = parseFloat(x); }
    if (isNaN(x)) { return ''; }
    x = Math.round((x + 0.0000001) * 10000) / 10000 // Round to 4 digits if longer.
    var parts = x.toString().split(".");
    parts[0] = parts[0].replace(/\B(?=(\d{3})+(?!\d))/g, ",");
    if(parts[1] === undefined || parts[1].length === 0) {parts[1] = '0000'; }
    while(parts[1].length < 4) {parts[1] += '0'; }
    return parts.join(".");
  },

  booleanFormatter: function(params) {
    if(params.value === ''){ return ''; }
    if(params.value == 't' || params.value == 'true' || params.value == 'y' || params.value == 1) {
      return "<span class='ac_icon_check'>&nbsp;</span>";
    }
    else {
      return "<span class='ac_icon_uncheck'>&nbsp;</span>";
    }
  },

  hrefInlineFormatter: function(params) {
    //var rainPerTenMm = params.value / 10;
    return "<a href='/books/"+params.value+"/edit'>edit</a>";
  },

  hrefSimpleFormatter: function(params) {
    var val = params.value;
    return "<a href='"+val.split('|')[0]+"'>"+val.split('|')[1]+"</a>";
  },

  // Creates a link that when clicked prompts for a yes/no answer.
  // Column value is in the format "url|link_text|prompt|method".
  // Only url and link_text are required.
  hrefPromptFormatter: function(params) {
    var url, link_text, prompt, method;
    [url, link_text, prompt, method] = params.value.split('|');
    prompt = prompt || 'Are you sure?';
    method = (method || 'post').toLowerCase();
    return "<a href='#' data-prompt='"+prompt+"' data-method='"+method+"' data-url='"+url+
           "' onclick='crossbeamsGridEvents.promptClick();'>"+link_text+"</a>";
  }


};

// function to act as a class
function NumericCellEditor() {
}

// gets called once before the renderer is used
NumericCellEditor.prototype.init = function (params) {
    // create the cell
    this.eInput = document.createElement('input');
    this.eInput.value = crossbeamsUtils.isCharNumeric(params.charPress) ? params.charPress : params.value;

    var that = this;
    this.eInput.addEventListener('keypress', function (event) {
        if (!crossbeamsUtils.isKeyPressedNumeric(event)) {
            that.eInput.focus();
            if (event.preventDefault) event.preventDefault();
        }
    });

    // only start edit if key pressed is a number, not a letter
    var charPressIsNotANumber = params.charPress && ('1234567890'.indexOf(params.charPress) < 0);
    this.cancelBeforeStart = charPressIsNotANumber;
};

// gets called once when grid ready to insert the element
NumericCellEditor.prototype.getGui = function () {
    return this.eInput;
};

// focus and select can be done after the gui is attached
NumericCellEditor.prototype.afterGuiAttached = function () {
    this.eInput.focus();
};

// returns the new value after editing
NumericCellEditor.prototype.isCancelBeforeStart = function () {
    return this.cancelBeforeStart;
};

// example - will reject the number if it contains the value 007
// - not very practical, but demonstrates the method.
NumericCellEditor.prototype.isCancelAfterEnd = function () {
    // var value = this.getValue();
    // return value.indexOf('007') >= 0;
};

// returns the new value after editing
NumericCellEditor.prototype.getValue = function () {
    if(this.eInput.value === '') {
      return '';
    }
  else {
    return parseInt(this.eInput.value);
  }
};

// any cleanup we need to be done here
NumericCellEditor.prototype.destroy = function () {
    // but this example is simple, no cleanup, we could  even leave this method out as it's optional
};

// if true, then this editor will appear in a popup
NumericCellEditor.prototype.isPopup = function () {
    // and we could leave this method out also, false is the default
    return false;
};


(function() {
  var loadGrid;
  var onBtExport;

  translateColDefs = function(columnDefs) {
    //console.log(columnDefs);
    var newColDefs = [], col, newCol, fn;
    for (_i = 0, _len = columnDefs.length; _i < _len; _i++) {
      col = columnDefs[_i];
      newCol = {};
      for(attr in col) {
        if(attr==='cellRenderer') {
          //fn = window[col[attr]];
          //newCol[attr] = fn;
          //newCol[attr] = eval(col[attr]);
          if(col[attr] ==='crossbeamsGridFormatters.testRender') {
            newCol[attr] = crossbeamsGridFormatters.testRender;
          }
          if(col[attr] ==='crossbeamsGridFormatters.numberWithCommas2') {
            newCol[attr] = crossbeamsGridFormatters.numberWithCommas2;
          }
          if(col[attr] ==='crossbeamsGridFormatters.numberWithCommas4') {
            newCol[attr] = crossbeamsGridFormatters.numberWithCommas4;
          }
          if(col[attr] ==='crossbeamsGridFormatters.booleanFormatter') {
            newCol[attr] = crossbeamsGridFormatters.booleanFormatter;
          }
          if(col[attr] ==='crossbeamsGridFormatters.hrefInlineFormatter') {
            newCol[attr] = crossbeamsGridFormatters.hrefInlineFormatter;
          }
          if(col[attr] ==='crossbeamsGridFormatters.hrefSimpleFormatter') {
            newCol[attr] = crossbeamsGridFormatters.hrefSimpleFormatter;
          }
          if(col[attr] ==='crossbeamsGridFormatters.hrefPromptFormatter') {
            newCol[attr] = crossbeamsGridFormatters.hrefPromptFormatter;
          }

        }
        else {
          if(attr==='cellEditor') {
            console.log('edit');
            if(col[attr] ==='NumericCellEditor') {
            console.log('edit - NUM');
              newCol[attr] = NumericCellEditor;
            }
          }
          else {
            newCol[attr] = col[attr];
          }
        }
      }
      newColDefs.push(newCol);
    }
    return newColDefs;
  };

  loadGrid = function(grid, gridOptions) {
    var httpRequest, url;
    url = grid.getAttribute('data-gridurl');
    httpRequest = new XMLHttpRequest();
    httpRequest.open('GET', url);
    httpRequest.send();
    return httpRequest.onreadystatechange = function() {
      var httpResult, newColDefs;
      if (httpRequest.readyState === 4 && httpRequest.status === 200) {
        httpResult = JSON.parse(httpRequest.responseText);
        newColDefs = translateColDefs(httpResult.columnDefs);
        gridOptions.api.setColumnDefs(newColDefs);
        gridOptions.api.setRowData(httpResult.rowDefs);
      }
    };
  };

  //document.addEventListener(eventName, eventHandler);
  document.addEventListener("DOMContentLoaded", function() {
    var grid, gridOptions, grids, _i, _len, _results, grid_id;
    grids = document.querySelectorAll('[data-grid]');
    //_results = [];
    for (_i = 0, _len = grids.length; _i < _len; _i++) {
      grid = grids[_i];
      grid_id = grid.getAttribute('id');
      for_print = grid.dataset.gridPrint;
      // lookup of grid ids? populate here and clear when grid unloaded...
      gridOptions = {
        columnDefs: null,
        rowDefs: null,
        enableColResize: true,
        enableSorting: true,
        enableFilter: true,
        suppressScrollLag: true,
        enableRangeSelection: true,
        enableStatusBar: true,
        suppressAggFuncInHeader: true,
        // onAfterFilterChanged: function() {console.log('onAfterFilterChanged', this.api.rowModel.rootNode.childrenAfterFilter.length, grid_id);}
        // onAfterFilterChanged: crossbeamsGridEvents.showFilterChange(grid_id)
        //suppressCopyRowsToClipboard: true
        //quickFilterText: 'fred'
      };
      if(for_print) {
        gridOptions.forPrint        = true;
        gridOptions.enableStatusBar = false;
      }

      new agGrid.Grid(grid, gridOptions);
      crossbeamsGridStore.addGrid(grid_id, gridOptions);
      gridOptions.onAfterFilterChanged = crossbeamsGridEvents.showFilterChange(grid_id);
      //_results.push(loadGrid(grid, gridOptions));
      loadGrid(grid, gridOptions);
    }
    //return _results;
  });

}).call(this);
