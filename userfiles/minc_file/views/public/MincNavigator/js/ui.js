//console.log = function() {};
console.warn = function() {};

var mincNavigator = null;

/*
  the buffer is supposed to be an hdf5
*/
function openMinc2(buffer){
  mincNavigator = new MincNavigator(buffer);
  onFileLoaded();
}


/*
  Callback at file opening
*/
function handleFileSelect(evt) {
  // dealing with splashcreen
  $(".splashcreen .splashContent .openfile").hide();
  $(".splashcreen .splashContent .splashHint").hide();
  $(".splashcreen .splashContent .isLoading").show();


    var files = evt.target.files; // FileList object

    // if a file is in the list, open it (only the first)
    if(files.length){
      var reader = new FileReader();

      reader.onloadend = function(event) {
          var result = event.target.result;
          openMinc2(result);
      }

      reader.onerror = function() {
          var error_message = "error reading file: " + filename;
          throw new Error(error_message);
      };

      reader.readAsArrayBuffer(files[0]);
    }
}


function addScrollTraveling(){

  $(".gridCell").bind('mousewheel DOMMouseScroll', function(event){

    var travelDirection = $(this).attr("travel");
    var factor = parseFloat( $(this).find("input").val());

    if (event.originalEvent.wheelDelta > 0 || event.originalEvent.detail < 0) {
      factor *= -1;
    }


    mincNavigator.moveAlongAxis(travelDirection, factor);

  });

}



/*
  element is a jquery obj, in this case a canvas.
  It makes this element dragable and zoomable, still it does not
  show out of its parent borders (most likely a div).
  This is done playing with css.
*/
function addZoomingAndPanning(element){
  element.draggable();

  var scale = 1.;
  var zoomFactor = 1.05;

  element.css("transform", "scale(" + scale + ")");



  element.bind('mousewheel DOMMouseScroll', function(event){
    var parentWidth = element.parent().width();
    var parentHeight = element.parent().height();

    // getting the (css) left offset
    var left = element.css("left");
    if(typeof left == "undefined"){
      left = 0;
    }else{
      // removing the ending "px"
      left = parseFloat(left.slice(0, -2));
    }

    // getting the (css) top offset
    var top = element.css("top");
    if(typeof top == "undefined"){
      top = 0;
    }else{
      // removing the ending "px"
      top = parseFloat(top.slice(0, -2));
    }

    var adjustLeft = 0;
    var adjustTop = 0;

    // scrolling up
    if (event.originalEvent.wheelDelta > 0 || event.originalEvent.detail < 0) {
      scale *= zoomFactor;
      element.css("transform", "scale(" + scale + ")");
      adjustLeft = left * zoomFactor;
      adjustTop = top*zoomFactor +  ((zoomFactor - 1) * parentHeight) / 2;
    }
    // scrolling down
    else {
      scale /= zoomFactor;
      element.css("transform", "scale(" + scale + ")");
      adjustLeft = left / zoomFactor;
      adjustTop = top/zoomFactor -  ((zoomFactor - 1) * parentHeight) / 2;
    }

    element.attr("scale", scale);

    // adjust the top and left offset
    element.css("left" , adjustLeft + "px");
    element.css("top" , adjustTop + "px");
  });



}


/*
  Increase the zoom of a .brainSlice by a factor.
  cardinalParent is : nw, sw or se
*/
function zoomBrainSlice(cardinalParent, zoomFactor){

  // the element to zoom is the canvas with the class brainSlice
  var element = $("#" + cardinalParent).find(".brainSlice");
  var scale = parseFloat( $(element).attr("scale") );

  var parentHeight = element.parent().height();

  // getting the (css) left offset
  var left = element.css("left");
  if(typeof left == "undefined"){
    left = 0;
  }else{
    // removing the ending "px"
    left = parseFloat(left.slice(0, -2));
  }

  // getting the (css) top offset
  var top = element.css("top");
  if(typeof top == "undefined"){
    top = 0;
  }else{
    // removing the ending "px"
    top = parseFloat(top.slice(0, -2));
  }

  scale *= zoomFactor;
  element.css("transform", "scale(" + scale + ")");
  adjustLeft = left * zoomFactor;
  adjustTop = top*zoomFactor +  ((zoomFactor - 1) * parentHeight) / 2;


  element.attr("scale", scale);

  // adjust the top and left offset
  element.css("left" , adjustLeft + "px");
  element.css("top" , adjustTop + "px");

}

/*
  Place the element (jquery obj, most likely a canvas) at the center
  of the parent (most likely a div).
  This is done playing with css.
*/
function centerCanvas(element){
  var parentWidth = element.parent().width();
  var parentHeight = element.parent().height();
  var elemWidth = element.width();
  var elemHeight = element.height();
  var offsetLeft = (elemWidth) / 2;
  var offssetTop = (elemHeight - parentHeight) / 2;

  //element.css("left" , offsetLeft + "px");
  element.css("top" , -offssetTop + "px");
}


/*
  DOM is ready, lets do some stuff!
*/
window.onload = function(){
  // Check for the various File API support.
  if (window.File && window.FileReader && window.FileList && window.Blob) {
      // Great success! All the File APIs are supported.
      document.getElementById('fileOpener').addEventListener('change', handleFileSelect, false);
  } else {
      console.log('The File APIs are not fully supported in this browser.');
  }

  /*
  // adding the zooming and panning to the canvas.
  // No need to have the files loaded for that...
  addZoomingAndPanning($("#ObliqueMain_canvas"));
  addZoomingAndPanning($("#ObliqueOrthoU_canvas"));
  addZoomingAndPanning($("#ObliqueOrthoV_canvas"));
  */

  // adds the panning to canvas
  $("#ObliqueMain_canvas").draggable();
  $("#ObliqueOrthoU_canvas").draggable();
  $("#ObliqueOrthoV_canvas").draggable();

  addScrollTraveling();

  loadDynamicMinc();

  $("#debugButton").click(function(){
    console.log("hello");

    loadArrayBuffer(
      "data/full8_400um_optbal.mnc",

      function(data){
        openMinc2(data);
      },

      function(status){
        console.log("Couldnt open the file");
      }
    )

  });
}


/*
  Get the localStorage value for the
*/
function getDynamicMincUrl(){
  var mincUrl = null;

  // local storage is available
  if (typeof(Storage) !== "undefined") {
    var localStorageKey = "mincUrl";
    var mincUrl = localStorage.getItem( localStorageKey );

    if( mincUrl ){
      // remove the key so that the user could use another instance of MincNavigator
      localStorage.removeItem(localStorageKey);
    }else{
      console.log("the key '" + localStorageKey + "' does not exist in LocalStorage.");
    }

  // local storage NOT available
  } else {
    console.log("LocalStorage is not available on your Browser.");
  }

  return mincUrl;
}


/*
  Ask what is the minc dynamic url and loads it.
  If none was found in the localStorage, just dont load anything but
  leaves the open button visible.
*/
function loadDynamicMinc(){
  var mincUrl = getDynamicMincUrl();

  if( !mincUrl )
    return;

  $("#openFileBt").hide();
  $(".splashcreen .splashContent .openfile").hide();
  $(".splashcreen .splashContent .splashHint").hide();
  $(".splashcreen .splashContent .isLoading").show();

  loadArrayBuffer(
    mincUrl,

    function(data){
      openMinc2(data);
    },

    function(status){
      console.log("Couldnt open the file");
    }
  )
}





/*
* AJAX load a binary file, and somthing with it.
*
*/
function loadArrayBuffer(url, successCallback, errorCallback) {

    var xhr = new XMLHttpRequest();
    xhr.open("GET", url, true);
    xhr.responseType = "arraybuffer";

    xhr.onload = function (oEvent) {
      var status = xhr.status;
      var arrayBuffer = xhr.response;

      if (arrayBuffer) {
        var blob = new Blob([arrayBuffer]);
        var fileReader = new FileReader();

        fileReader.onload = function(event) {
          console.log(event.target.result);
          successCallback && successCallback(event.target.result);
        };

        fileReader.onerror = function(event){
          errorCallback && errorCallback(event);
        }

        fileReader.readAsArrayBuffer(blob);
      }
    };

    xhr.onerror = function(e){
      console.error("Can't find the file " + url);
      errorCallback && errorCallback(status);
    }

    xhr.send(null);
  }





function initObliqueControls(){
  $("#nw .obliqueControls .arrowUp").click(function(){
    var factor = parseFloat($("#nw .obliqueControls input").val());
    mincNavigator.moveAlongAxis("n", factor);
  });

  $("#nw .obliqueControls .arrowDown").click(function(){
    var factor = parseFloat($("#nw .obliqueControls input").val()) * -1;
    mincNavigator.moveAlongAxis("n", factor);
  });



  $(".zoomPlus").click(function(){
    var cardinalParent = $(this).closest(".gridCell").attr("id");
    zoomBrainSlice(cardinalParent, 1.2);
  });

  $(".zoomMinus").click(function(){
    var cardinalParent = $(this).closest(".gridCell").attr("id");
    zoomBrainSlice(cardinalParent, 1/1.2);
  });

  $("#sw .obliqueControls .arrowUp").click(function(){
    var factor = parseFloat($("#sw .obliqueControls input").val());
    mincNavigator.moveAlongAxis("u", factor);
  });

  $("#sw .obliqueControls .arrowDown").click(function(){
    var factor = parseFloat($("#sw .obliqueControls input").val()) * -1;
    mincNavigator.moveAlongAxis("u", factor);
  });

  $("#se .obliqueControls .arrowUp").click(function(){
    var factor = parseFloat($("#se .obliqueControls input").val());
    mincNavigator.moveAlongAxis("v", factor);
  });

  $("#se .obliqueControls .arrowDown").click(function(){
    var factor = parseFloat($("#se .obliqueControls input").val()) * -1;
    mincNavigator.moveAlongAxis("v", factor);
  });

  // bubble button over canvas
  $("#switchOrthoU").click(function(){
    mincNavigator.tiltGimbalU();
  });

  $("#switchOrthoV").click(function(){
    mincNavigator.tiltGimbalV();
  });
}


/*
  used as a callback when the gimbal changes position or orientation.
  See MincNavigator.callbackReadGimbalInfo for more.
*/
function displayGimbalInfo(center, normal){
  $("#centerX").val(Math.round(center[0]*100) / 100);
  $("#centerY").val(Math.round(center[1]*100) / 100);
  $("#centerZ").val(Math.round(center[2]*100) / 100);

  $("#normalX").val(Math.round(normal[0]*10000) / 10000);
  $("#normalY").val(Math.round(normal[1]*10000) / 10000);
  $("#normalZ").val(Math.round(normal[2]*10000) / 10000);
}



/*
  Ask the gimbal to take this center+normal vector.
*/
function setGimbalInfo(){
  console.log($("#normalX").val());

  mincNavigator.setPlaneNormalAndPoint(
    [
      parseFloat($("#normalX").val()),
      parseFloat($("#normalY").val()),
      parseFloat($("#normalZ").val())
    ],
    [
      parseFloat($("#centerX").val()),
      parseFloat($("#centerY").val()),
      parseFloat($("#centerZ").val())
    ]
  );
}


/*
  Build the list of available rotation within the dropdown menu
*/
function updateRestoreRotationMenu(){
  $('#restoreGimbalMenu').empty();
  var nameList = mincNavigator.getGimbalOrientationNames();

  $('#restoreGimbalMenu')
    .append(
      $("<option></option>")
        .attr("value", "none")
        .text("none")
    );

  nameList.forEach(function(element){
    console.log(element);
    $('#restoreGimbalMenu')
      .append(
        $("<option></option>")
          .attr("value",element)
          .text(element)
      );
  });
}


/*
  callback for a selecte rotation to restore
*/
function restoreRotation(){
  var rotationID = $("#restoreGimbalMenu option:selected").text();

  if(rotationID == "none")
    return;

  mincNavigator.restoreGimbalSettings(rotationID);

  // get back to defaut so that _original_ is selectable again
  $("#restoreGimbalMenu").val("none");
}


/*
  Callback for the Save rotation button.
  Adds this rotation to the drop down menu.
*/
function saveRotation(){
  var name = $("#saveRotationLabel").val();

  if(!name){
    $("#saveRotationLabel").attr("placeholder", "Name is mandatory!")
  }else{

    mincNavigator.saveGimbalSettings(name);
    updateRestoreRotationMenu();
    $("#saveRotationLabel").val('');
    $("#saveRotationLabel").attr("placeholder", name + " saved!");

    setTimeout(function(){
      $("#saveRotationLabel").attr("placeholder", "name");
    }, 1500);
  }
}


/*
  Callback of the rotate button
*/
function rotateWithAngle(){
  var angle = parseFloat($("#angleToRotate").val());
  var axis = $("#axisToRotate option:selected").attr("value");

  if(Number.isNaN(angle)){
    $("#angleToRotate").val("");
    return;
  }
  mincNavigator.rotateDegree(angle, axis);
}


/*
  Defines the callback of the 2 points cross section buttons
*/
function setCallbackACPCSection(){

  $("#acpcAcBt").click(function(){
    mincNavigator.twoPointsSectionSetP1();
  });

  $("#acpcPcBt").click(function(){
    mincNavigator.twoPointsSectionSetP2();
  });

  $("#resetAcpcBt").click(function(){
    mincNavigator.resetPointsSection();
  });

  $("#updateAcpcBt").click(function(){
    mincNavigator.updateTwoPointsSection();
  });
}


/*
  init the sidebar's button callbacks
*/
function initSidebarCallbacks(){

  // undo button
  $("#undoBt").click(function(){
    mincNavigator.undo();
  });

  // redo button
  $("#redoBt").click(function(){
    mincNavigator.redo();
  });

  // Toggle gimbal button
  $("#toggleGimbalBt").click(function(){
    mincNavigator.getVolumeNavigator().AxisArrowHelperToggle();
  });

  // update gimbal button
  $("#updateGimbalBt").click(function(){
    setGimbalInfo();
  });

  $("#updateAngleBt").click(function(){
    rotateWithAngle();
  });

  $("#saveRotationBt").click(function(){
    saveRotation();
  });


  setCallbackACPCSection();
  updateRestoreRotationMenu();
}


/*
  Called when the file is loaded.
  Init the callbacks (or calls functions to do so ) and in the end,
  fadeOut the splash screen to show the main view.
*/
function onFileLoaded(){
    // so that the data is centered
    centerCanvas($("#ObliqueMain_canvas"));
    centerCanvas($("#ObliqueOrthoU_canvas"));
    centerCanvas($("#ObliqueOrthoV_canvas"));

    // the bubble buttons to change slices
    initObliqueControls();

    // wiring the red gimbal info callback
    mincNavigator.setCallbackReadGimbalInfo(displayGimbalInfo);

    // refresh some text fields
    // (this is just about calling displayGimbalInfo here)
    mincNavigator.sendGimbalInfo();

    initSidebarCallbacks();

    // when everything is ready, we fade out the splashscreen to show the actuall app
    $(".splashcreen").fadeOut();





  /*
  // KEEP FOR LATER
  // Getting canvas coord from scrolling
  $('#ObliqueOrthoU_canvas').on('mousemove', function( evt ) {
    var scale = $(this).attr("scale");

    // in case we never zoom/unzoom
    if(typeof scale == "undefined")
      scale = 1;

    var originalH = parseFloat($(this).attr("height"));
    var originalW = parseFloat($(this).attr("width"));

    var rect = $(this).get(0).getBoundingClientRect();
    //console.log($(this).parent().get(0).getBoundingClientRect());
    console.log(rect);
    var x = ((evt.clientX - rect.left) / rect.width) * originalW;
    var y = ((evt.clientY - rect.top) / rect.height) * originalH;
    console.log(x + ' ' + y);
  });
  */

}
