// Behaviour for parameter entry page of Crossbeams DataMiner reports.

var crossbeamsDataMinerParams = {

  formId: '',
  reportNo: '',
  query_params: [],
  current_values: [],

  removeQueryParamItem: function(node) {
      var index = crossbeamsUtils.getListIndex(node);
      this.current_values.splice(index, 1);
      node.parentNode.removeChild(node);
    },

  queryItemAsText: function(item) {
      var val, val_to;
      if(item.op === 'is_null' || item.op === 'not_null') {
        val = '';
        val_to = '';
      }
      else {
        val = item.text;
        if(item.op === 'between') {
          val_to = ' AND ' + item.text_to;
        }
        else {
          val_to = '';
        }
      }
      //return '<li style="list-style-type:none;"><i class="fa fa-minus" style="cursor:pointer;color:red;" onclick="removeQueryParamItem(this.parentNode)"></i> ' + item.caption + ' ' + item.opText + ' ' + item.text;
      return '<li style="list-style-type:none;"><i class="fa fa-minus" style="cursor:pointer;color:red;" onclick="removeQueryParamItem(this.parentNode)"></i> ' + item.caption + ' ' + item.opText + ' ' + val + val_to;
    },

  querySelectionAsText: function(param_values) {
      if(param_values.length === 0) {
        return '<li style="list-style-type:none;">None selected</li>';
      }
      else {
        // var items = param_values.map(function(entry) {
        //   return queryItemAsText(entry);
        // });
        var items = [];
        for(var i=0;i<param_values.length;i++) {
          items.push(crossbeamsDataMinerParams.queryItemAsText(param_values[i]));
        }
        return items.join('');
      }
    },

  containsObject: function(obj, list) {
    var i,hld;
    for (i = 0; i < list.length; i++) {
      hld = list[i];
      //if (list[i] == obj) {
      if (hld.col === obj.col && hld.op === obj.op && hld.val === obj.val && hld.val_to === obj.val_to) { // TODO: range of vals etc...
        return true;
      }
    }

    return false;
  },

  displayParamsAsText: function() {
    var disp = '<ul>';
    disp += this.querySelectionAsText(this.current_values);
    disp += '</ul>';
    document.getElementById('param_display').innerHTML = disp;
  },

  operatorParmChange: function(event) {
    var val1 = document.getElementById('qp_value');
    var val2 = document.getElementById('qp_value_to');
    switch(event.target.value) {
      case 'between':
        val1.style.display = '';
        val2.style.display = '';
        break;
      case 'is_null':
        val1.style.display = 'none';
        val2.style.display = 'none';
        break;
      case 'not_null':
        val1.style.display = 'none';
        val2.style.display = 'none';
        break;
      default:
        val1.style.display = '';
        val2.style.display = 'none';
    }
  },

  // choice object: {
  // col      : query column name
  // op       : operator (=,>...)
  // opText   : operater (is, greater than...)
  // val      : selected/input value
  // val_to   : second value for date ranges
  // text     : selected value as text (e.g. for dropdown this could differ from the value)
  // text_to  : second value for date ranges as text
  // }
  addQpFormParam: function() {
    var choice    = {};
    var valElem   = document.getElementById('qp_value');
    var valElem2  = document.getElementById('qp_value_to');
    choice.col    = document.getElementById('qp_column').value;
    choice.op     = document.getElementById('qp_operator').value;
    choice.opText = document.getElementById('qp_operator').options[document.getElementById('qp_operator').selectedIndex].text;
    choice.val    = valElem.value;
    choice.val_to = valElem2.value;
    var qp        = this.query_params[choice.col];
    if(qp.control_type === 'list') {
      choice.text    = valElem.options[valElem.selectedIndex].text;
      choice.text_to = '';
    }
    else {
      choice.text    = choice.val;
      choice.text_to = choice.val_to
    }
    choice.caption  = qp.caption;
    // if something other than is null or not null, 1st val must be present. If between, both must be present...
    if(choice.op !== 'is_null' && choice.op !== 'not_null') {
      if(choice.val === '') { return false; }
    }
    if(choice.op === 'between') {
      if(choice.val_to === '') { return false; }
    }
    if(!crossbeamsDataMinerParams.containsObject(choice, this.current_values)) {
      this.current_values.push(choice);
      crossbeamsDataMinerParams.displayParamsAsText();
    }
  },
  // Listeners for change of parameters and of operators.
  checkNode: function(addedNode) {
    if (addedNode.nodeType === 1){
      if (addedNode.matches('#qp_operator')){
        addedNode.addEventListener('change', crossbeamsDataMinerParams.operatorParmChange);
        var event = document.createEvent('HTMLEvents');
        event.initEvent('change', true, false);
        addedNode.dispatchEvent(event);
      }
    }
  },

  // Store current params
  // store limit, offset & current_values
  // key:...url, including report
  // val: {limit: ; offset: ; current_values: }
  // .. on submit form, store
  // .. on load, pass "back" to init to reload params.
  // Maybe store previous n dm params?
  storeCurrentParams: function() {
    var limit  = document.querySelector('#' + this.formId + " input[name=limit]").value;
    var offset = document.querySelector('#' + this.formId + " input[name=offset]").value;
    var stored = {limit: limit, offset: offset, paramValues: this.current_values};

    var key = crossbeamsLocalStorage.genStandardKey(this.reportNo);
    crossbeamsLocalStorage.setItem(key, stored);
  },

  loadCurrentParams: function() {
    var key = crossbeamsLocalStorage.genStandardKey(this.reportNo);
    if(crossbeamsLocalStorage.hasItem(key)) {
      //console.log('LOADING', reportNo, key);
      var stored = crossbeamsLocalStorage.getItem(key);
      document.querySelector('#' + this.formId + " input[name=limit]").value = stored.limit;
      document.querySelector('#' + this.formId + " input[name=offset]").value = stored.offset;
      this.current_values = stored.paramValues;
      crossbeamsDataMinerParams.displayParamsAsText();
    }
  },

  buildReloadButton: function() {
    var key = crossbeamsLocalStorage.genStandardKey(this.reportNo);
    if(crossbeamsLocalStorage.hasItem(key)) {
      document.querySelector('#reloadParams').style.display = '';
    }
  },

  init: function(form_id, rpt_id, qprm) {
    var observer;
    this.formId       = form_id;
    this.reportNo     = rpt_id;
    this.query_params = qprm;

    document.getElementById("select_param").addEventListener('change', function (event) {
      var val = event.target.value, qp, val_input, input_type;
      var qpForm = document.getElementById("qp_form");
      if(val ==='') {
        qpForm.innerHTML = '';
      }
      else {
        qp = crossbeamsDataMinerParams.query_params[val];
        input_type = '';
        switch(qp.data_type) {
          case 'number':
            input_type = 'type="number"';
            break;
          case 'integer':
            input_type = 'type="number" pattern="\d*"'; // Allow for minus sign?...
            break;
          case 'date':
            input_type = 'type="date"';
            break;
          case 'datetime':
            input_type = 'type="datetime-local"';
        }

        if(qp.control_type === 'list') {
          val_input = crossbeamsUtils.makeSelect('qp_value', qp.list_values) +
                        '<input name="qp_value_to" id="qp_value_to" style="display:none" />';
        }
        else {
          if (qp.control_type === 'daterange') {
            val_input = '<input name="qp_value" id="qp_value" value="'+ (qp.default_value === null ? '' : qp.default_value) +'" ' + input_type + ' />' +
                        '<input name="qp_value_to" id="qp_value_to" ' + input_type + ' />';
          }
          else {
            val_input = '<input name="qp_value" id="qp_value" value="'+ (qp.default_value === null ? '' : qp.default_value) +'"' + input_type + ' />' +
                        '<input name="qp_value_to" id="qp_value_to" style="display:none"' + input_type + ' />';
          }
        }
        qpForm.innerHTML = '<form id="dForm" action="#">' + '<input type="hidden" id="qp_column" value="' + qp.column + '" />' +
          crossbeamsUtils.makeSelect('qp_operator', qp.operator) +
          val_input +'<button type="button" class="pure-button pure-button" onclick="crossbeamsDataMinerParams.addQpFormParam()"><i class="fa fa-plus"></i></button></form>';
      }
            // event.stopPropagation();
            // event.preventDefault();
    });

    crossbeamsDataMinerParams.displayParamsAsText();

    observer = new MutationObserver(function(mutations){
      for (var i=0; i < mutations.length; i++){
        for (var j=0; j < mutations[i].addedNodes.length; j++){
          crossbeamsDataMinerParams.checkNode(mutations[i].addedNodes[j]);
        }
      }
    });

    observer.observe(document.documentElement, {
      childList: true,
      subtree: true
    });
  }

};
