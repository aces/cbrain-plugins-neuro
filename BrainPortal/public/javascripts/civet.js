function CivetObject(brainbrowser,path) {
  var that = this;
  this.brainbrowser = brainbrowser;
  this.dataSet = new ThicknessData(path);


  that.debugLineGroup;
  that.debugLine;
  that.selectedInfo = null;
  that.treeInfo;  // information about the transform graph.
  that.pickInfoElem;
  that.flashTimer = 0;
  that.highlightMaterial;
  that.highlightShape;
  that.vertex;
  that.positionVector;
  that.primitiveIndex;
  that.dataArray;
  that.data_max; //Max of data
  that.data_min; //Min of data
  that.range_max; //Max of range bar
  that.range_min; //Min of range bar
  that.spectrum;

  this.updateInfo = function() {
    if (!that.treeInfo) {
      that.treeInfo = o3djs.picking.createTransformInfo(brainbrowser.client.root,				   null);
    }
    that.treeInfo.update();
  };


  function unSelectAll() {

    if (that.selectedInfo) {


      that.highlightShape = null;
      that.selectedInfo = null;
    }
  }

  function select(pickInfo) {

    unSelectAll();
    if (pickInfo) {

      that.selectedInfo = pickInfo;

    }
  }

  function valueAtPoint(e) {
    if(!that.vertex) {
      return;
    }
    var worldRay = o3djs.picking.clientPositionToWorldRay(
      e.x,
      e.y,
     brainbrowser.viewInfo.drawContext,
      brainbrowser.client.width,
      brainbrowser.client.height);


    // Update the entire tree in case anything moved.
    // NOTE: This function is very SLOW!
    // If you really want to use picking you should manually update only those
    // transforms and shapes that moved, were added, or deleted by writing your
    // own picking library. You should also make sure that you are only
    // considering things that are pickable. By that I mean if you have a scene of
    // a meadow with trees, grass, bushes, and animals and the only thing the user
    // can pick is the animals then put the animals on their own sub branch of the
    // transform graph and only pick against that subgraph.
    // Even better, make a separate transform graph with only cubes on it to
    // represent the animals and use that instead of the actual animals.
    that.treeInfo.update();

    var pickInfo = that.treeInfo.pick(worldRay);
    if (pickInfo) {

      select(pickInfo);

      var primitiveIndex = pickInfo.rayIntersectionInfo.primitiveIndex;
      that.primitiveIndex = primitiveIndex;
      var positionVector = pickInfo.rayIntersectionInfo.position;
      that.positionVector = positionVector;
      var element = pickInfo.element;


      var vertex = brainbrowser.model_data.get_vertex(primitiveIndex,positionVector);
      var value = that.dataArray[vertex];
      jQuery("#value").html("Value at vertex "+ vertex + ": " + value);


    } else {

      //that.debugLine.setVisible(false);
      jQuery("#value").html('--nothing--');
    }


  }


  //Picking a vertex
  function pickClick(e) {
    var worldRay = o3djs.picking.clientPositionToWorldRay(
      e.x,
      e.y,
      brainbrowser.viewInfo.drawContext,
      brainbrowser.client.width,
      brainbrowser.client.height);
    unSelectAll();

    // Update the entire tree in case anything moved.
    // NOTE: This function is very SLOW!
    // If you really want to use picking you should manually update only those
    // transforms and shapes that moved, were added, or deleted by writing your
    // own picking library. You should also make sure that you are only
    // considering things that are pickable. By that I mean if you have a scene of
    // a meadow with trees, grass, bushes, and animals and the only thing the user
    // can pick is the animals then put the animals on their own sub branch of the
    // transform graph and only pick against that subgraph.
    // Even better, make a separate transform graph with only cubes on it to
    // represent the animals and use that instead of the actual animals.
    that.treeInfo.update();

    var pickInfo = that.treeInfo.pick(worldRay);
    if (pickInfo) {

      select(pickInfo);

      var primitiveIndex = pickInfo.rayIntersectionInfo.primitiveIndex;
      that.primitiveIndex = primitiveIndex;
      var positionVector = pickInfo.rayIntersectionInfo.position;
      that.positionVector = positionVector;
      var element = pickInfo.element;





      jQuery(that.pickInfoElem).html("LOADING MAP................");
      that.vertex = brainbrowser.model_data.get_vertex(primitiveIndex,positionVector);
      update_map();

    } else {

      //that.debugLine.setVisible(false);
      jQuery(that.pickInfoElem).html('--nothing--');
    }


  }



  /**
   *  This method generates the color map using the spectrum
   *
   */
  function generate_colors(values,min,max) {

    var colorArray = new Array();

    //calculate a slice of the data per color
    var increment = ((max-min)+(max-min)/that.spectrum.length)/that.spectrum.length;
    //for each value, assign a color
    for(var i=0; i<values.length; i++) {
      if(values[i]<= min ) {
	var color_index = 0;
      }else if(values[i]> max){
	var color_index = that.spectrum.length-1;
      }else {
	var color_index = parseInt((values[i]-min)/increment);
      }
      //This inserts the RGBA values (R,G,B,A) independently
      colorArray.push.apply(colorArray,that.spectrum[color_index]);
    }
    update_range(min,max);
    return colorArray;
  }


  /**
   * This method applies the colors to the model
   */
  function update_colors(colorArray) {
    var colorBuffer = brainbrowser.pack.createObject('VertexBuffer');
    var colorField = colorBuffer.createField('FloatField', 4);
    colorBuffer.set(colorArray);
    colorArray = [];
    var brainShape = brainbrowser.brainTransform.shapes[0];
    var streamBank = brainShape.elements[0].streamBank;
    streamBank.setVertexStream(
      brainbrowser.o3d.Stream.COLOR, //  This stream stores vertex positions
      0,                     // First (and only) position stream
      colorField,        // field: the field this stream uses.
      0);                    // start_index:
    brainbrowser.client.render();

  }

  function get_data_controls() {
    var data_type = jQuery("#data-type").val(); //CT,AREA or Volume
    var data_sk = jQuery("#data-sk").val(); //Smoothing Kernel
    var data_modality = jQuery("#data-modality").val();

    return {modality: data_type, sk: data_sk, statistic: data_modality };
  }

  function update_color_map(min,max) {
    var colors = generate_colors(that.dataArray,min,max);
    if(colors != -1) {
      update_colors(colors);
    }
  }

  function update_model(dataset) {
    that.dataArray = dataset.data;
    that.data_min = dataset.min;
    that.data_max = dataset.max;
    update_color_map(that.data_min,that.data_max);
  }

  function update_map() {
    that.dataSet.get_data(that.vertex,get_data_controls(),update_model);
    jQuery(that.pickInfoElem).html("Viewing data for vertex: " + that.vertex  );
  }

  function update_range(min,max) {
    jQuery("#data-range-min").val(min);
    jQuery("#data-range-max").val(max);
    update_scale(min,max);
  }

  function update_scale(min,max) {
  }
  this.range_change = function() {
    var min=parseFloat(jQuery("#data-range-min").val());
    var max=parseFloat(jQuery("#data-range-max").val());
    update_color_map(min,max);
  }


  this.data_control_change = function() {
    if(that.vertex) {
      update_map();
    }
  }
  function parse_spectrum(data) {
    data = data.replace(/\s+$/, '');
    data = data.replace(/^\s+/, '');
    var tmp = data.split(/\n/);
    var colors = new Array();
    for(var i=0;i<tmp.length;  i++) {
      var tmp_color = tmp[i].split(/\s+/);
      for(var k=0; k<3; k++) {
	tmp_color[k]=parseFloat(tmp_color[k]);
      }
      tmp_color.push(1.0000);
      colors.push(tmp_color);
    }



    return colors;
  }

  function set_spectrum(type) {
    //get the spectrum of colors
    jQuery.ajax({
		  type: 'GET',
		  url: '/assets/spectral_spectrum.txt',
		  dataType: 'text',
		  success: function (data) {
		    var colors = parse_spectrum(data);
		    update_spectrum(colors);
		  },
		  data: {spectrum: type}
		});
  }


  function update_spectrum(colors) {
    var spectrum = jQuery("#spectrum");
    spectrum.html('');
    for(var i=0;i<colors.length;i++) {
      var color = jQuery("<div></div>");
      var rgb="rgb("+parseInt(parseFloat(colors[i][0])*255)+','+parseInt(parseFloat(colors[i][1])*255)+','+parseInt(parseFloat(colors[i][2])*255)+')';
      color.css("background",rgb);
      color.css("width" , parseInt(256/colors.length) + "px");
      color.appendTo(spectrum);
    }
    that.spectrum =  colors;

  }


  that.applyThickness = function (filename) {
    that.dataSet.get_data(filename,update_model);
  }



  jQuery(".thickness").live('change',function(event) {
				     var filename= jQuery(this).val();
				     if( filename == "Select a thickness file") {
				       return;
				     }else
				     {
				       that.applyThickness(filename);
				     }
				   });
  set_spectrum("spectral");
  brainbrowser.valueAtPoint = function() {};
  brainbrowser.pickClick = function() {}; //associating pickClick for brainbrowser which handles events.
}
