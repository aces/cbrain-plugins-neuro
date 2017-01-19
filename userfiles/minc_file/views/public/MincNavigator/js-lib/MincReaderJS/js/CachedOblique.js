/*
  Author: Jonathan Lurie
  Institution: McGill University, Montreal Neurological Institute - MCIN
  Date: started on Jully 2016
  email: lurie.jo@gmail.com
  License: MIT
*/

/*
  Creates an instance able to retrieve all kind of data from an oblique slice.
  Args:
    plane: Plane instance - will be deep copied
    data1D: typedArray 1D - the content of the image in 1D,
            but not necessary in uint8.
    width: number - width of the image
    heigh: number - heigh of the image
    verticeMatchList: Object that contains 2D and 3D polygons,
            arranged in a matchy way.
            See ObliqueSampler.generateCachedOblique() for more info.
            This is already deep copied - no need to redo that.
    name: string - the name of this cached oblique.
            If null, a date string will be used instead.
*/
var CachedOblique = function(plane, data1D, width, height, verticeMatchList, name){
  // copying the plane, not just its pointer
  this._plane = new Plane();
  this._plane.copy(plane);

  // 1D array
  this._1DData = data1D.slice();

  this._width = width;
  this._height = height;
  this._name = name == null? new Date() : name;

  this._canvasData = null;

  this.estimateBitDepthFactor();

  this._bitDepthFactor = 1.;

  this._verticeMatchList = verticeMatchList;

  this._quaternion = {
    x: null,
    y: null,
    z: null,
    w: null
  }

}


/*
  Return the (pointer to the) plane.
*/
CachedOblique.prototype.getPlane = function(){
  return this._plane;
}


/*
  return the width of the image
*/
CachedOblique.prototype.getWidth = function(){
  return this._width;
}


/*
  return the height of the image
*/
CachedOblique.prototype.getHeight = function(){
  return this._height;
}


/*
  return the name of the oblique slice (most likely just a date)
*/
CachedOblique.prototype.getName = function(){
  return this._name;
}


/*
  return the 1D array (a pointer to it).
  Note: this is the monocromatique array (potentially not uint8),
  this is NOT the canvas array
*/
CachedOblique.prototype.get1DData = function(){
  return this._1DData;
}


/*
  return the canvas compliant array.
  Note: generates it if not already done.
*/
CachedOblique.prototype.getCanvasData = function(){
  // if not already prepared
  if(!this._canvasData){
    this.makeCanvasData();
  }

  return this._canvasData;
}


/*
  Prepare the canva compliant data
*/
CachedOblique.prototype.makeCanvasData = function(){

  if(!this._1DData || this._width == 0 || this._height == 0){
    console.log("ERROR: the oblique image is empty.");
    return null;
  }

  var simpleImageContext = document.createElement("canvas").getContext("2d");
  this._canvasData = simpleImageContext.createImageData(this._width, this._height);
  var rgbaArray = new Uint8ClampedArray(this._1DData.length * 4);

  // from single channel array to RGBA buff, just repeat the value...
  for(var i=0; i<this._1DData.length; i++){
    rgbaArray[i*4] = this._1DData[i] / this._bitDepthFactor;
    rgbaArray[i*4 +1] = this._1DData[i] / this._bitDepthFactor;
    rgbaArray[i*4 +2] = this._1DData[i] / this._bitDepthFactor;
    rgbaArray[i*4 +3] = 255;
  }

  this._canvasData.data.set(rgbaArray, 0);
}


/*
  Manually set the factor used to put the data into [0; 255]
*/
CachedOblique.prototype.setBitDepthFactor = function(f){
  this._bitDepthFactor = f;
}


/*
  from the kind of numbers used in this._1DData (which is a typedArray),
  we can know the factor to use to project into an interval of [0, 255].
  For that, we assume the data stored in this._1DData is relevant to its kind,
  meaning it uses a significant part of its possibilities
  (unlike a unit8 that would be coded on a float32 var).

  BEWARE: the floating types (Float32Array and Float64Array) are understood as
  being in [0, 1]
*/
CachedOblique.prototype.estimateBitDepthFactor = function(){
  // here we decide that what is under 0 (for signed types), remains under 0.
  // Only the positive values will be considered

  if(this._1DData instanceof Int8Array) {
    // [-128; 127]
    this._bitDepthFactor = 0.5;

  }else if(this._1DData instanceof Uint8Array){
    // [0; 255]
    this._bitDepthFactor = 1;

  }else if(this._1DData instanceof Uint8ClampedArray){
    // [0; 255]
    this._bitDepthFactor = 1;

  }else if(this._1DData instanceof Int16Array){
    // [-32768; 32767]
    this._bitDepthFactor = 128;

  }else if(this._1DData instanceof Uint16Array){
    // [0; 65535]
    this._bitDepthFactor = 256

  }else if(this._1DData instanceof Int32Array){
    // [-2147483648; 2147483647]
    this._bitDepthFactor = 8388608;

  }else if(this._1DData instanceof Uint32Array){
    // [0; 4294967295]
    this._bitDepthFactor = 16777216;

  }else if(this._1DData instanceof Float32Array){
    // [1.2E-38; 3.4E+38]
    this._bitDepthFactor = 1/256;

  }else if(this._1DData instanceof Float64Array){
    // [2.3E-308; 1.7E+308]
    this._bitDepthFactor = 1/256;
  }

}


/*
  return the object that matches the 3D vertices to the 2D vertices.
  (not necessary in a CW or CCW order)
*/
CachedOblique.prototype.getVerticeMatchList = function(){
  return this._verticeMatchList;
}


/*
  Set the quaternion.
  An instance of CachedOblique will do nothing with a quaternion,
  but it may be set/get with VolumeNavigator, especially in the context
  of retrieving cachedObliques.
*/
CachedOblique.prototype.setQuaternion = function(x, y, z, w){
  this._quaternion.x = x;
  this._quaternion.y = y;
  this._quaternion.z = z;
  this._quaternion.w = w;
}


/*
  return the quaternion.
*/
CachedOblique.prototype.getQuaternion = function(){
  return this._quaternion;
}
