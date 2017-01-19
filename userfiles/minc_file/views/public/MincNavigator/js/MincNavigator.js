/*
  Author: Jonathan Lurie
  Institution: McGill University, Montreal Neurological Institute - MCIN
  Date: Jully 2016
  email: lurie.jo@gmail.com
  License: MIT

  Requirements:
    Having a div named "navigatorDiv" for placing the VolumeNavigator


*/

var MincNavigator = function(mincBuffer){

  // loaded file, filled with voxels
  this._mincVolume = readMincBuffer(mincBuffer);

  // A sliceEngine is a combo of the necessary objects to create an oblique slice
  // and display it somewhere.
  this._sliceEngines = {};

  // the 3D cube widget for navigating in the dataset
  this._volumeNavigator = null;

  // this will be reajusted
  this._optimalSamplingFactor = 1;

  // the bit depth factor is used to restrict the final image to [0, 255]
  // if data are [0, 65535], then this._bitDepthFactor should be 1/256
  this._bitDepthFactor = 1;

  // list of DOM element names to place elements
  this.navigatorDomName = "navigatorDiv";

  // a callback to set that will be called with 2 args:
  //    gimbalCenter: Array - [x, y, z] coordinate of the center of the gimbal.
  //    gimbalNormal: Array - [x, y, z] unit vector of the gimbal's reference normal vector (in Z)
  // Info: both args are sliced hard copy of the orinal arrays - thus, just for reading.
  this.callbackReadGimbalInfo = null;

  this.twoPointsSection = [null, null];

  this.init();
}


/*
  Returns the volumeNavigator instance.
  BEWARE, do not overload stuff!
*/
MincNavigator.prototype.getVolumeNavigator = function(){
  return this._volumeNavigator;
}

/*
  initialize few object and all the sliceEngines
*/
MincNavigator.prototype.init = function(){
  this.initVolumeNavigator();

  // add the regular sliceEngines
  this.addSliceEngine("ObliqueMain", true);
  this.addSliceEngine("ObliqueOrthoU", false);
  this.addSliceEngine("ObliqueOrthoV", false);
  this.findOptimalPreviewSamplingFactor();
  this.updateFullResImages();

  // map the image at init
  this._volumeNavigator.update();
  this.mapObliqueMain();
}


/*
  Set the bit depth factor manually if the original data does not match
  a [0, 255] interval.
  ie. if data are [0, 65535], then the factor should be (1/256)
*/
MincNavigator.prototype.setBitDepthFactor = function(f){
  this._bitDepthFactor = f;
}


/*
  Initialize the volume navigator and its callbacks
*/
MincNavigator.prototype.initVolumeNavigator = function(){
  var dimensionInfo = this._mincVolume.getDimensionInfo();

  // the outer box size
  var outerBoxOptions = {
      xSize: dimensionInfo[0].space_length,
      ySize: dimensionInfo[1].space_length,
      zSize: dimensionInfo[2].space_length
  }

  // creating a VolumeNavigator instance
  this._volumeNavigator = new VolumeNavigator(
    outerBoxOptions,
    null,
    this.navigatorDomName,
    false // display a gui?
  );

  // optional: this callback is called when a slider is moving (mouse down)
  //this._volumeNavigator.setOnChangeCallback(this.onChangeCallback.bind(this));

  // optional: this callback is called when a slider is released (mouse up)
  //this._volumeNavigator.setOnFinishChangeCallback(this.onChangeDoneCallback.bind(this));

  // optional: add a button at the bottom of dat.gui with its associated callback.
  // originally for caching the current slice.
  //this._volumeNavigator.buildGuiButton("Cache current slice", cacheSlice);

  /*
    On the following part, we have a lot of events. Each of them matches
    a specific usage of the gimbal, rotating, translating, moving, done moving,
    all that conbined by "which axis?".
  */

  var that = this;

  /**** CALLBACKS WHILE MOVING ****/

  // when spining the x axis
  this._volumeNavigator.setCallback("onOrbitingX", function(){
    // the main oblique
    that.updateSliceEngine(
      "ObliqueMain",
      that._volumeNavigator.getPlaneNormal(),
      that._volumeNavigator.getPlanePoint(),
      false
    );

    // the ortho in U oblique
    that.updateSliceEngine(
      "ObliqueOrthoU",
      that._volumeNavigator.getGimbalNormalVectorArr(1),
      that._volumeNavigator.getPlanePoint(),
      false
    );

    that.mapObliqueMain();

  });

  // when spining the y axis
  this._volumeNavigator.setCallback("onOrbitingY", function(){
    // the main oblique
    that.updateSliceEngine(
      "ObliqueMain",
      that._volumeNavigator.getPlaneNormal(),
      that._volumeNavigator.getPlanePoint(),
      false
    );

    // the ortho in V oblique
    that.updateSliceEngine(
      "ObliqueOrthoV",
      that._volumeNavigator.getGimbalNormalVectorArr(0),
      that._volumeNavigator.getPlanePoint(),
      false
    );

    that.mapObliqueMain();
  });

  // when spining the z axis
  this._volumeNavigator.setCallback("onOrbitingZ", function(){
    // the ortho in U oblique
    that.updateSliceEngine(
      "ObliqueOrthoU",
      that._volumeNavigator.getGimbalNormalVectorArr(1),
      that._volumeNavigator.getPlanePoint(),
      false
    );

    // the ortho in V oblique
    that.updateSliceEngine(
      "ObliqueOrthoV",
      that._volumeNavigator.getGimbalNormalVectorArr(0),
      that._volumeNavigator.getPlanePoint(),
      false
    );

    that.mapObliqueMain();
  });

  // when moving along normal
  this._volumeNavigator.setCallback("onMovingAlongNormal", function(){
    // the main oblique
    that.updateSliceEngine(
      "ObliqueMain",
      that._volumeNavigator.getPlaneNormal(),
      that._volumeNavigator.getPlanePoint(),
      false
    );

    that.mapObliqueMain();
  });

  // when moving along the ortho plane U
  this._volumeNavigator.setCallback("onMovingAlongOrthoU", function(){
    // the ortho in U oblique
    that.updateSliceEngine(
      "ObliqueOrthoU",
      that._volumeNavigator.getGimbalNormalVectorArr(1),
      that._volumeNavigator.getPlanePoint(),
      false
    );

    that.mapObliqueMain();
  });

  // when moving along the ortho plane V
  this._volumeNavigator.setCallback("onMovingAlongOrthoV", function(){
    // the ortho in V oblique
    that.updateSliceEngine(
      "ObliqueOrthoV",
      that._volumeNavigator.getGimbalNormalVectorArr(0),
      that._volumeNavigator.getPlanePoint(),
      false
    );

    that.mapObliqueMain();
  });


  /**** CALLBACKS WHEN DONE MOVING ****/

  // when spining the x axis
  this._volumeNavigator.setCallback("onOrbitedX", function(){
    // the main oblique
    that.updateSliceEngine(
      "ObliqueMain",
      that._volumeNavigator.getPlaneNormal(),
      that._volumeNavigator.getPlanePoint(),
      true
    );

    // the ortho in U oblique
    that.updateSliceEngine(
      "ObliqueOrthoU",
      that._volumeNavigator.getGimbalNormalVectorArr(1),
      that._volumeNavigator.getPlanePoint(),
      true
    );

    that.mapObliqueMain();
  });

  // when spining the y axis
  this._volumeNavigator.setCallback("onOrbitedY", function(){
    // the main oblique
    that.updateSliceEngine(
      "ObliqueMain",
      that._volumeNavigator.getPlaneNormal(),
      that._volumeNavigator.getPlanePoint(),
      true
    );

    // the ortho in V oblique
    that.updateSliceEngine(
      "ObliqueOrthoV",
      that._volumeNavigator.getGimbalNormalVectorArr(0),
      that._volumeNavigator.getPlanePoint(),
      true
    );

    that.mapObliqueMain();
  });

  // when spining the z axis
  this._volumeNavigator.setCallback("onOrbitedZ", function(){
    that.updateSliceEngine(
      "ObliqueOrthoU",
      that._volumeNavigator.getGimbalNormalVectorArr(1),
      that._volumeNavigator.getPlanePoint(),
      true
    );

    // the ortho in V oblique
    that.updateSliceEngine(
      "ObliqueOrthoV",
      that._volumeNavigator.getGimbalNormalVectorArr(0),
      that._volumeNavigator.getPlanePoint(),
      true
    );

    that.mapObliqueMain();
  });

  // when moving along normal
  this._volumeNavigator.setCallback("onMovedAlongNormal", function(){
    // the main oblique
    that.updateSliceEngine(
      "ObliqueMain",
      that._volumeNavigator.getPlaneNormal(),
      that._volumeNavigator.getPlanePoint(),
      true
    );

    that.mapObliqueMain();
  });

  // when moving along the ortho axis U
  this._volumeNavigator.setCallback("onMovedAlongOrthoU", function(){
    // the ortho in U oblique
    that.updateSliceEngine(
      "ObliqueOrthoU",
      that._volumeNavigator.getGimbalNormalVectorArr(1),
      that._volumeNavigator.getPlanePoint(),
      true
    );

    that.mapObliqueMain();
  });

  // when moving along the ortho axis V
  this._volumeNavigator.setCallback("onMovedAlongOrthoV", function(){
    // the ortho in V oblique
    that.updateSliceEngine(
      "ObliqueOrthoV",
      that._volumeNavigator.getGimbalNormalVectorArr(0),
      that._volumeNavigator.getPlanePoint(),
      true
    );

    that.mapObliqueMain();
  });
}


/*
  Add a sliceEngine to the list.
  Args:
    name: String - identifier of the slice Engine, must be unique
    mapping3D: boolean - If true, texture maps the image on the VolumeNavigator
*/
MincNavigator.prototype.addSliceEngine = function(name, mapping3D){

  var sliceEngine = {
    plane: new Plane(),
    sampler: null, // init just afterwards
    canvasID: name + "_canvas",
    mapping3D: mapping3D,
    //boostedCanvas: null
  };

  /*
  // using the size of the parent div to fix the size of the canvas
  var parentDiv = document.getElementById(sliceEngine.canvasID).parentNode;
  var width = parentDiv.offsetWidth;
  var height = parentDiv.offsetHeight;
  sliceEngine.boostedCanvas = new BoostedCanvas(sliceEngine.canvasID, width, height);
  */
  sliceEngine.sampler = new ObliqueSampler(this._mincVolume, sliceEngine.plane);
  sliceEngine.sampler.update();
  this._sliceEngines[name] = sliceEngine;

}


/*
  Find the best downsampling factor.
  This factor could have been guest for every sliceEngine(s).sampler
  but since they are all using the same minc data, we would have the same factor,
  so, saving time here.
*/
MincNavigator.prototype.findOptimalPreviewSamplingFactor = function(){
  var sliceEngine = this._sliceEngines["ObliqueMain"];

  sliceEngine.plane.makeFromOnePointAndNormalVector(
    this._volumeNavigator.getPlanePoint(),
    this._volumeNavigator.getPlaneNormal()
  );

  sliceEngine.sampler.update();
  sliceEngine.sampler.findOptimalPreviewFactor();
  this._optimalSamplingFactor = sliceEngine.sampler.getOptimalPreviewSamplingFactor();
}



/*
  call the previously defined callback to send the gimbal info
*/
MincNavigator.prototype.sendGimbalInfo = function(){
  // if the callback is defined, we tell it what are the new setting of the gimbal
  // (no matter which slice is concerned)
  if(this.callbackReadGimbalInfo){
    this.callbackReadGimbalInfo(
      this._volumeNavigator.getPlanePoint().slice(),
      this._volumeNavigator.getPlaneNormal().slice() // we are not using normal from args because it is all the time called with the reference normal.
    );
  }
}


/*
  Does the necessary to perform an oblique image using a normal vector
  and a point to create a plane. Then displays this image in the canvas.
  Args:
    name: String - ID of the slice within this._sliceEngines
    normalVector: Array [x, y, z] - normal vector for building a plane (normalized)
    point: Array [x, y, z] - point to build the VectorTools
    fullRes: bool - If true, creates a full res image, if false creates a low res

*/
MincNavigator.prototype.updateSliceEngine = function(name, normalVector, point, fullRes){

  // the gimbal has just moved here, so we refresh whatever need to be refreshed
  this.sendGimbalInfo();


  var sliceEngine = this._sliceEngines[name];

  // update the plane
  sliceEngine.plane.makeFromOnePointAndNormalVector(
    point,
    normalVector
  );

  if(fullRes){
    // set the sampling factor at full res (=1)
    sliceEngine.sampler.setSamplingFactor(1);
  }else{
    sliceEngine.sampler.setSamplingFactor(this._optimalSamplingFactor);
  }

  // ask the sampler to update its info from the plane
  sliceEngine.sampler.update();

  // Start the sampling process (no interpolation)
  sliceEngine.sampler.startSampling(false);

  var imageData = sliceEngine.sampler.exportForCanvas(this._bitDepthFactor);

  this.loadImageDataIntoCanvas(imageData, sliceEngine.canvasID);

  /*
  // TODO: make it more generic so that any slice could be mapped on its polygon,
  // this means we have to update VolumeNavigator so that it can do so.
  // map the image on the volume
  if(sliceEngine.mapping3D){
    this.prepareVerticeForMapping(
      sliceEngine.sampler.getVerticeMatchList() // TODO replace by just the ID
    );
  }
  */

}


/*
  Loads image content into a canvas
*/
MincNavigator.prototype.loadImageDataIntoCanvas = function(imgData, canvasID){
  // the imgData could be null, ie. when the plane does not
  // intersect the volume
  if(!imgData)
    return;

  //var canvas = document.createElement("canvas");
  var canvas = document.getElementById(canvasID);
  var context = canvas.getContext("2d");

  canvas.width = imgData.width;
  canvas.height = imgData.height;

  context.fillStyle = "#00ff00";
  context.fillRect(0, 0, canvas.width, canvas.height);
  context.putImageData(imgData, 0, 0);
}


/*

*/
MincNavigator.prototype.prepareVerticeForMapping = function(name){
  var sliceEngine = this._sliceEngines[name]

  var verticeMatchList = sliceEngine.sampler.getVerticeMatchList();


  if(!verticeMatchList)
    return;

  var volNavList = this._volumeNavigator.getPlanePolygon();
  var numOfVertice = volNavList.length;
  // Note: verticeMatchList._3D is supposed to contain the same as volNavList
  // but not in the same order. Though we cannot expect to compare (==) them
  // to one another with a floating point precision. We'll have to use a
  // root mean square as an indicator of "closeness".
  // The goal being to reorder verticeMatchList so that its values are in the
  // same order as in volNavList.

  // the index of matchTable is the index of volNavList
  // while the value is the index in verticeMatchList
  var matchTable = [];

  // This runs in O(n²), sorry about that... (hopefully this polygon has 6 vertice max)

  // finding who is who
  for(var ref=0; ref<numOfVertice; ref++){

    var matchFound = 0;
    var bestScore = 1000; //  the lowest wins

    for(var challenger=0; challenger<numOfVertice; challenger++){

      var currentScore =
        Math.abs(volNavList[ref][0] - verticeMatchList[challenger]._3D[0]) +
        Math.abs(volNavList[ref][1] - verticeMatchList[challenger]._3D[1]) +
        Math.abs(volNavList[ref][2] - verticeMatchList[challenger]._3D[2]);

      if(currentScore < bestScore){
        bestScore = currentScore;
        matchFound = challenger;
      }
    }
    matchTable.push(matchFound);
  }

  // reordering the verticeMatchList
  var new_verticeMatchList = [];
  for(var v=0; v<numOfVertice; v++){
    new_verticeMatchList.push( verticeMatchList[matchTable[v]] );
  }

  // the image is a square
  var squareSide = sliceEngine.sampler.getLargestSide();

  // conversion from 2D image coordinate convention to ThreeJS texture coordinate conventions
  // (1: origin is top-left in pixel dimensions. 2: origin is bottom left in percentage)
  var textureCoords = []
  for(var v=0; v<numOfVertice; v++){
    var imageCoords = new_verticeMatchList[v]._2D;
    var percentCoord = [
      imageCoords[0] / squareSide,
      1 - (imageCoords[1] / squareSide)
    ];

    textureCoords.push(percentCoord);
  }

  // sending the mapping coordinates
  this._volumeNavigator.mapTextureFromCanvas(this._sliceEngines[name].canvasID, textureCoords);
}


/*
  Updates all the image that are supposed to be updated at full res
*/
MincNavigator.prototype.updateFullResImages = function(){

  // the main oblique
  this.updateSliceEngine(
    "ObliqueMain",
    this._volumeNavigator.getPlaneNormal(),
    this._volumeNavigator.getPlanePoint(),
    true
  );

  // the ortho in U oblique
  this.updateSliceEngine(
    "ObliqueOrthoU",
    this._volumeNavigator.getGimbalNormalVectorArr(1),
    this._volumeNavigator.getPlanePoint(),
    true
  );

  // the ortho in V oblique
  this.updateSliceEngine(
    "ObliqueOrthoV",
    this._volumeNavigator.getGimbalNormalVectorArr(0),
    this._volumeNavigator.getPlanePoint(),
    true
  );

  this.prepareVerticeForMapping("ObliqueMain");
}


MincNavigator.prototype.mapObliqueMain = function(){
  this.prepareVerticeForMapping("ObliqueMain");
}


/*
  updates only the images that are supposed to be updated at low res
*/
MincNavigator.prototype.updateLowResImages = function(){

  // the main oblique
  this.updateSliceEngine(
    "ObliqueMain",
    this._volumeNavigator.getPlaneNormal(),
    this._volumeNavigator.getPlanePoint(),
    false
  );

  this.prepareVerticeForMapping("ObliqueMain");

}


/*
  Set the callback that will be called every time the gimbal will tilt
  or translate.
*/
MincNavigator.prototype.setCallbackReadGimbalInfo = function(cb){
  this.callbackReadGimbalInfo = cb;
}


/*
  Changes both point of the plane and plane normal.
*/
MincNavigator.prototype.setPlaneNormalAndPoint = function(nomal, point){
  this._volumeNavigator.setPlaneNormalAndPoint(nomal, point);
}


/*
  Ask volumeNav to save the current configuration.
  Args:
    name: String - has to be unique (or wont be saved)
*/
MincNavigator.prototype.saveGimbalSettings = function(name){
  this._volumeNavigator.saveGimbalSettings(name, false, null);
}


/*
  Returns the list of names used as ID for saved gimbal settings (quat+center)
*/
MincNavigator.prototype.getGimbalOrientationNames = function(){
  return this._volumeNavigator.getsavedGimbalSettingsNameList();
}


/*
  Restore one of the saved gimbal configuration given its name.
  Args:
    name: String - unique identifier
*/
MincNavigator.prototype.restoreGimbalSettings = function(name){
  this._volumeNavigator.restoreGimbalSettings(name, true); // execute the callbacks
}


/*
  asks volumeNav to rotate around a specifi axis
*/
MincNavigator.prototype.rotateDegree = function(angle, axis){
  this._volumeNavigator.rotateDegreeAndUpdate(angle, axis); // execute the callbacks
}


/*
  Ask volumeNav to tilt so that the U ortho plane becomes the reference plane
*/
MincNavigator.prototype.tiltGimbalU = function(){
  this._volumeNavigator.tiltGimbalU();
}


/*
  Ask volumeNav to tilt so that the V ortho plane becomes the reference plane
*/
MincNavigator.prototype.tiltGimbalV = function(){
  this._volumeNavigator.tiltGimbalV();
}


/*
  Save in attribute the first point to perform a 2 points cross section
*/
MincNavigator.prototype.twoPointsSectionSetP1 = function(){
  this.twoPointsSection[0] = this._volumeNavigator.getGimbalCenter();
}


/*
  Save in attribute the second point to perform a 2 points cross section
*/
MincNavigator.prototype.twoPointsSectionSetP2 = function(){
  this.twoPointsSection[1] = this._volumeNavigator.getGimbalCenter();
}


/*
  Ask volumeNav to perform a 2 points cross section with the
  2 points previously saved (this.twoPointsSection[])
*/
MincNavigator.prototype.updateTwoPointsSection = function(){
  this._volumeNavigator.planeFromTwoPoints(
    this.twoPointsSection[0],
    this.twoPointsSection[1]
  );
}


/*
  Erase the 2 points so that a cross section is not possible anymore
*/
MincNavigator.prototype.resetPointsSection = function(){
  this.twoPointsSection = [null, null];
}


/*
  called as a generic method to move along the normal, U ortho or V ortho.
  Args:
    axisName: String - must be of "n", "u" or "v"
    factor: Number - factor of the unit vector the gimbal will move of (in the targeted direction)
*/
MincNavigator.prototype.moveAlongAxis = function(axisName, factor){

  // select the axis
  if(axisName == "n"){
    this._volumeNavigator.moveAlongNormal(factor);
  }else if(axisName == "u"){
    this._volumeNavigator.moveAlongOrthoU(factor);
  }else if(axisName == "v"){
    this._volumeNavigator.moveAlongOrthoV(factor);
  }
}


/*
  Undo the last step. Can be perform as long as the stack of step is not empty.
*/
MincNavigator.prototype.undo = function(){
  this._volumeNavigator.undo(true);
}


/*
  Undo the last step. Can be perform as long as the stack of step is not empty
*/
MincNavigator.prototype.redo = function(){
  this._volumeNavigator.redo(true);
}
