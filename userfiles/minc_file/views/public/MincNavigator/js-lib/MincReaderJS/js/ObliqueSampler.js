/*
  Author: Jonathan Lurie
  Institution: McGill University, Montreal Neurological Institute - MCIN
  Date: started on Jully 2016
  email: lurie.jo@gmail.com
  License: MIT

  Performs oblique sclicing on a minc2 dataset
*/

var ObliqueSampler = function(volume, plane){
  this._3Ddata = volume;
  this._plane = plane;

  // we want to compute it only once
  this._bigDiagonal = null;

  this._planePolygon = null; // the polygon formed by the intersection of the plane and the cube of data (from 3 to 6 vertice)

  // the equivalent of _planePolygon but within the 2D plane, in image coordinate
  this._planePolygon2D = null;
  this._samplingFactor = 1.; // impact the size of the finale image

  this._vecTools = new VectorTools();

  // contains the oblique image (as a 1D typed array), the equivalent mask and few other info.
  // created by initObliqueImage
  this._obliqueImage = null;

  // deep copies of this._obliqueImage at certain points
  this._cachedObliques = [];

  // equation of each edge (no need to compute at every refresh)
  this._cubeEdges = this._3Ddata.getEdgesEquations();

  //console.log(this._3Ddata.getDimensionInfo());
  //console.log(this._3Ddata.voxelToWorld(0, 0, 0));
  console.log(this._3Ddata.worldToVoxel(0, 0, 0));
  //console.log(this._3Ddata.voxelToWorld(147, 177, 183));
  //console.log(this._3Ddata.voxelToWorld(177, 183, 147));
  console.log(this._3Ddata.voxelToWorld(183, 147, 177));

  console.log(this._3Ddata.header);

  // will be adapted by findOptimalPreviewFactor()
  this._optimalPreviewSamplingFactor = 0.35;

}

/*
  important in case the plane changes (rotation or translation).
  for now, it's only about the intersection polygon, but other methods
  may be add up later
*/
ObliqueSampler.prototype.update = function(){

  this.computeCubePlaneHitPoints();
  this.findVertice2DCoord();

}


/*
  takes all the edges or the cube (12 in total)
  and make the intersection with the plane.
  For one single edge, there can be:
  - no hit (the edge doesnt cross the plane)
  - one hit (the edge crosses the plane)
  - an infinity of hits (the edge belongs to the plane)
*/
ObliqueSampler.prototype.computeCubePlaneHitPoints = function(){
  var hitPoints = [];

  for(var i=0; i<this._cubeEdges.length; i++){
    var edge = this._cubeEdges[i];
    var tempHitPoint = this._getHitPoint(edge[0], edge[1], this._plane);

    // 1- We dont want to add infinite because it mean an orthogonal edge
    // from this one (still of the cube) will cross the plane in a single
    // point -- and this later case is easier to deal with.
    // 2- Check if hitpoint is within the cube.
    // 3- Avoid multiple occurence for the same hit point
    if( tempHitPoint && // may be null if contains Infinity as x, y or z
        this._3Ddata.isWithin(tempHitPoint, true))
    {
        var isAlreadyIn = false;

        // check if the point is already in the array
        for(var hp=0; hp<hitPoints.length; hp++ ){
          if( hitPoints[hp][0] == tempHitPoint[0] &&
              hitPoints[hp][1] == tempHitPoint[1] &&
              hitPoints[hp][2] == tempHitPoint[2]){
                isAlreadyIn = true;
                break;
              }
        }

        if(!isAlreadyIn){
          hitPoints.push(tempHitPoint);
        }
    }

  }

  // array are still easier to deal with
  this._planePolygon = hitPoints.length ? hitPoints : null;
}



/*
  return a point in 3D space (tuple (x, y, z) ).
  vector and point define a "fixed vector" (droite affine)
  both are tuple (x, y, z)
  plane is the plane equation as a tuple (a, b, c, d)
*/
ObliqueSampler.prototype._getHitPoint = function(vector, point, plane){

  // 3D affine system tuple:
  // ( (l, alpha), (m, beta), (n, gamma) )
  var affineSystem = this._vecTools.affine3DFromVectorAndPoint(vector, point);

  // equation plane as ax + by + cz + d = 0
  // this tuple is (a, b, c, d)
  var planeEquation = plane.getPlaneEquation();

  // system resolution for t:
  // t = (a*l + b*m + c*n + d) / ( -1 * (a*alpha + b*beta + c*gamma) )

  var tNumerator = ( planeEquation[0]* affineSystem[0][0] +
        planeEquation[1]* affineSystem[1][0] +
        planeEquation[2]* affineSystem[2][0] +
        planeEquation[3] );

  var tDenominator = (-1) *
      ( planeEquation[0]* affineSystem[0][1] +
        planeEquation[1]* affineSystem[1][1] +
        planeEquation[2]* affineSystem[2][1] );

  // TODO: be sure the cast to float is done
  // float conversion is mandatory to avoid euclidean div...
  //var t = float(tNumerator) / float(tDenominator);
  var t = tNumerator / tDenominator;

  // injection of t to the 3D affine system:
  var x =  affineSystem[0][0] + affineSystem[0][1] * t;
  var y =  affineSystem[1][0] + affineSystem[1][1] * t;
  var z =  affineSystem[2][0] + affineSystem[2][1] * t;


  // dont bother returning a vector containing Infinity, just return null.
  // (it will be spotted)
  if( x == Infinity ||
      y == Infinity ||
      z == Infinity)
  {
    return null;
  }

  // otherwise, return the 3D point
  return [x, y, z]
}


/*
  return the center of the polygon
  as a tuple (x, y, z)
*/
ObliqueSampler.prototype._getStartingSeed = function(){
  if(this._planePolygon){

    var xSum = 0;
    var ySum = 0;
    var zSum = 0;
    var numOfVertex = this._planePolygon.length

    for(var v=0; v<numOfVertex; v++){
      xSum += this._planePolygon[v][0];
      ySum += this._planePolygon[v][1];
      zSum += this._planePolygon[v][2];
    }

    var xCenter = xSum / numOfVertex;
    var yCenter = ySum / numOfVertex;
    var zCenter = zSum / numOfVertex;

    return [xCenter, yCenter, zCenter];

  }else{
    console.log("ERROR: the polygon is not defined yet, you should call the update() method");
    return null;
  }

}


/*
  return the diagonal (length) of the volume.
  affected by the _samplingFactor (ie. doubled if 2)
*/
ObliqueSampler.prototype.getLargestSide = function(){

    if(this._planePolygon){

      if(!this._bigDiagonal){

        var volumeDimensionInfo = this._3Ddata.getDimensionInfo();
        this._bigDiagonal = Math.sqrt(
          volumeDimensionInfo[0].space_length * volumeDimensionInfo[0].space_length +
          volumeDimensionInfo[1].space_length * volumeDimensionInfo[1].space_length +
          volumeDimensionInfo[2].space_length * volumeDimensionInfo[2].space_length);
      }

      return this._bigDiagonal * this._samplingFactor * 1.1;

        /*
        // doing it based on the polygon does not give the best result
        // and sometimes, the image is not large enough...
        var xMin = this._planePolygon[0][0];
        var yMin = this._planePolygon[0][1];
        var zMin = this._planePolygon[0][2];

        var xMax = this._planePolygon[0][0];
        var yMax = this._planePolygon[0][1];
        var zMax = this._planePolygon[0][2];

        for(var v=0; v<this._planePolygon.length; v++){
          var vertex = this._planePolygon[v];

          xMin = Math.min(xMin, vertex[0]);
          xMax = Math.max(xMax, vertex[0]);

          yMin = Math.min(yMin, vertex[1]);
          yMax = Math.max(yMax, vertex[1]);

          zMin = Math.min(zMin, vertex[2]);
          zMax = Math.max(zMax, vertex[2]);
        }



        var boxSide = Math.sqrt((xMax-xMin)*(xMax-xMin) + (yMax-yMin)*(yMax-yMin) + (zMax-zMin)*(zMax-zMin));

        return boxSide * this._samplingFactor;
        */

    }else{
      console.log("ERROR: the polygon is not defined yet. The plane does not intersect the volume or you should call update()");
      return null;
    }
}


/*
  we always start to fill the oblique image from its 2D center (in arg)
  the center of the 2D oblique image matches the 3D starting seed
  (center of the inner polygon, made by the intersection of the
  plane with the cube)
*/
ObliqueSampler.prototype.obliqueImageCoordToCubeCoord = function(centerImage, startingSeed, dx, dy){

  var u = this._plane.getUvector(); // u goes to x direction (arbitrary)
  var v = this._plane.getVvector(); // v goes to y direction (arbitrary)

  var target3Dpoint = [
    startingSeed[0] + dx * u[0] / this._samplingFactor + dy * v[0] / this._samplingFactor,
    startingSeed[1] + dx * u[1] / this._samplingFactor + dy * v[1] / this._samplingFactor,
    startingSeed[2] + dx * u[2] / this._samplingFactor + dy * v[2] / this._samplingFactor
  ];

  return target3Dpoint;
}



ObliqueSampler.prototype.findVertice2DCoord = function(factor){
  if(!this._planePolygon)
    return;

  var u = this._plane.getUvector(); // u goes to x direction (arbitrary) : 3D
  var v = this._plane.getVvector(); // v goes to y direction (arbitrary) : 3D
  var n = this._plane.getNormalVector();
  var largestSide = Math.round(this.getLargestSide());
  var obliqueImageCenter = [ Math.round(largestSide / 2), Math.round(largestSide / 2) ]; // 2D
  var startingSeed = this._getStartingSeed(); // 3D


  // reinit the array
  this._planePolygon2D = [];
  //this._planePolygon2D.push(obliqueImageCenter);

  for(var i=0; i<this._planePolygon.length; i++){

    var vertice3D = this._planePolygon[i]; // v

    var dx = vertice3D[0] - startingSeed[0];
    var dy = vertice3D[1] - startingSeed[1];
    var dz = vertice3D[2] - startingSeed[2];

    // the following system assumes that (startingSeed + a*u + b*v c*n = vertice3D)

    var commonDenom =
      u[0]*(n[1]*v[2] - v[1]*n[2]) +
      v[0]*(u[1]*n[2] - n[1]*u[2]) +
      n[0]*(v[1]*u[2] - u[1]*v[2]);

    var aNom =
      dx*(n[1]*v[2] - v[1]*n[2]) +
      v[0]*(dy*n[2] - n[1]*dz) +
      n[0]*(v[1]*dz - dy*v[2]);

    var a = aNom / commonDenom;

    var bNom =
      dx*(n[1]*u[2] - u[1]*n[2]) +
      u[0]*(dy*n[2] - n[1]*dz) +
      n[0]*(u[1]*dz - dy*u[2])

    var b = (-1) * bNom / commonDenom;

    var cNom =
      dx*(v[1]*u[2] - u[1]*v[2]) +
      u[0]*(dy*v[2] - v[1]*dz) +
      v[0]*(u[1]*dz - dy*u[2]);

    var c = cNom / commonDenom;

    var point = [
      obliqueImageCenter[0] + b*this._samplingFactor,
      obliqueImageCenter[1] + a*this._samplingFactor,
    ];

    this._planePolygon2D.push(point);

  }
}


/*
  Return an object containing the array of vertice in the 2D image
  and an array of the the equivalent vertice in the 3D volume.
  Note: vertice are sorted so that _2D[n] coresponds to _3D[n]
  Note2: the returned array are copies (slice)
*/
ObliqueSampler.prototype.getVerticeMatchList = function(){
  if(!this._planePolygon)
    return null;

  var verticeMatchList = [];

  for(var v=0; v<this._planePolygon.length; v++){
    verticeMatchList.push({
      _2D: this._planePolygon2D[v],
      _3D: this._planePolygon[v]
    });
  }

  return verticeMatchList;
}



/*
  returns True if the 3D coord matching to this oblique image point
  is within the cube.
  Returns False if outside the cube.
*/
ObliqueSampler.prototype.isImageCoordInCube = function(centerImage, startingSeed, dx, dy){
  var cubeCoord = this.obliqueImageCoordToCubeCoord(centerImage, startingSeed, dx, dy);
  return this._3Ddata.isWithin(cubeCoord, false);
}


/*
  Define the sampling factor (default = 1).
  Has to be called before startSampling()
*/
ObliqueSampler.prototype.setSamplingFactor = function(f){
  this._samplingFactor = f;
}


/*
  uses the precalculated optimal subsampling factor
*/
ObliqueSampler.prototype.setSamplingFactorAutoFast = function(){
  this._samplingFactor = this._optimalPreviewSamplingFactor;
}


/*
  initialize the oblique image array  as a 1D array.
  Width and height are also packaged in the structure.
*/
ObliqueSampler.prototype.initObliqueImage = function(datatype, width, height){

  var imageTypedArray = null;

  // we could simply use image.type, but written types are easier to read...
  switch (datatype) {
    case 'int8':
      imageTypedArray = new Int8Array(width * height);
      imageTypedArray.fill(127);
      break;
    case 'int16':
      imageTypedArray = new Int16Array(width * height);
      imageTypedArray.fill(32767);
      break;
    case 'int32':
      imageTypedArray = new Int32Array(width * height);
        imageTypedArray.fill(65535);
      break;
    case 'float32':
      imageTypedArray = new Float32Array(width * height);
      imageTypedArray.fill(1);
      break;
    case 'float64':
      imageTypedArray = new Float64Array(width * height);
      imageTypedArray.fill(1);
      break;
    case 'uint8':
      imageTypedArray = new Uint8Array(width * height);
      imageTypedArray.fill(255);
      break;
    case 'uint16':
      imageTypedArray = new Uint16Array(width * height);
      imageTypedArray.fill(65535);
      break;
    case 'uint32':
      imageTypedArray = new Uint32Array(width * height);
      imageTypedArray.fill(4294967295);
      break;
    default:
      var error_message = "Unsupported data type: " + header.datatype;
      console.log({ message: error_message } );
  }

  this._obliqueImage = {
    data: imageTypedArray,
    maskData: new Int8Array(width * height),
    width: width,
    height: height
  };

}


/*
  get the pixel value of the oblique image at (x, y)
*/
ObliqueSampler.prototype.getImageValue = function(x, y){
  if(x >= 0 && y>=0 && x<this._obliqueImage.width && y<this._obliqueImage.height){
    return this._obliqueImage.data[x*this._obliqueImage.width + y];
  }else{
    console.warn("Point (" + x + " , " + y + ") is out of the image");
    return undefined;
  }
}


/*
  set the pixel value of the oblique image at (x, y)
*/
ObliqueSampler.prototype.setImageValue = function(x, y, value){
  if(x >= 0 && y>=0 && x<this._obliqueImage.width && y<this._obliqueImage.height){
    this._obliqueImage.data[x*this._obliqueImage.width + y] = value;
  }else{
    console.warn("Point (" + x + " , " + y + ") is out of the image");
  }
}


/*
  get the pixel value of the oblique mask at (x, y).
  returns -1 if out of image (easier to catch)
*/
ObliqueSampler.prototype.getMaskValue = function(x, y){
  if(x >= 0 && y>=0 && x<this._obliqueImage.width && y<this._obliqueImage.height){
    return this._obliqueImage.maskData[x*this._obliqueImage.width + y];
  }else{
    console.warn("Point (" + x + " , " + y + ") is out of the image/mask");
    return -1;
  }
}


/*
  set the pixel value of the oblique mask at (x, y)
*/
ObliqueSampler.prototype.setMaskValue = function(x, y, value){
  if(x >= 0 && y>=0 && x<this._obliqueImage.width && y<this._obliqueImage.height){
    this._obliqueImage.maskData[x*this._obliqueImage.width + y] = value;
  }else{
    console.warn("Point (" + x + " , " + y + ") is out of the image/mask");
  }
}


/*
  export canvas compatible data - nice for display
*/
ObliqueSampler.prototype.exportForCanvas = function( factor){

  if(!this._obliqueImage)
    return null;

  var image = this._exportObliqueForCanvas(
    this._obliqueImage.data,
    this._obliqueImage.width,
    this._obliqueImage.height,
    factor
  );

  return image;

}


/*
  Generic function to export a typed array to a html5 canvas compliant dataset.
  Used for exporting the current oblique as well as cached ones.
*/
ObliqueSampler.prototype._exportObliqueForCanvas = function(typedArray, width, height, factor){
  if(!typedArray || width == 0 || height == 0){
    console.log("ERROR: the oblique image is empty.");
    return null;
  }

  var simpleImageContext = document.createElement("canvas").getContext("2d");

  var image = simpleImageContext.createImageData(width, height);
  var rgbaArray = new Uint8ClampedArray(typedArray.length * 4);

  // from single channel array to RGBA buff, just repeat the value...
  for(var i=0; i<typedArray.length; i++){
    rgbaArray[i*4] = typedArray[i] * factor;
    rgbaArray[i*4 +1] = typedArray[i] * factor;
    rgbaArray[i*4 +2] = typedArray[i] * factor;
    rgbaArray[i*4 +3] = 255;

    // make the white part transparent
    //if(rgbaArray[i*4] > 250 && rgbaArray[i*4+1] > 250 && rgbaArray[i*4+2] > 250)
    //  rgbaArray[i*4 +3] = 0;
  }

  /*
  // a green reference point at (10,10)
  var xGreen = 10;
  var yGreen = 20;
  var vertex1Dindex = width * yGreen * 4 + xGreen * 4;
  rgbaArray[vertex1Dindex] = 0;
  rgbaArray[vertex1Dindex + 1] = 255;
  rgbaArray[vertex1Dindex + 2] = 0;
  rgbaArray[vertex1Dindex + 3] = 255;
  */


  if(this._planePolygon2D){
    // painting the corners of the polygon
    for(var i=0; i<this._planePolygon2D.length; i++){
      var vertex = this._planePolygon2D[i];

      var vertex1Dindex = width * Math.round(vertex[1]) * 4 + Math.round(vertex[0]) * 4;
      // red
      rgbaArray[vertex1Dindex] = 0;
      // green
      rgbaArray[vertex1Dindex + 1] = 170;
      // blue
      rgbaArray[vertex1Dindex + 2] = 0;
      // alpha
      rgbaArray[vertex1Dindex + 3] = 255;
    }
  }

  image.data.set(rgbaArray, 0);
  return image;
}



/*
  Return the correct factor to make the data fit in a 0,255 color range.
  This is because some minc may be in uint16 or other.
*/
ObliqueSampler.prototype.getDepthFactor = function(){
  console.log( this._3Ddata.header );
  return (255/this._3Ddata.header.voxel_max);
}




/*
  start the sampling/filling process.
  interpolate:
    False (default) = nearest neighbor, crispier
    True = trilinear (3D) interpolation, slower, smoother
*/
ObliqueSampler.prototype.startSampling = function(filepath, interpolate){

  var dataType = this._3Ddata.getDataType();
  var largestSide = Math.round(this.getLargestSide());

  // no need to go further if the largest side is 0...
  if(largestSide == 0){
    this._obliqueImage = null;
    return;
  }

  // so that uint16 display well
  var depthFactor = this.getDepthFactor();

  //console.log("largestSide: " + largestSide);
  var startingSeed = this._getStartingSeed();

  var obliqueImageCenter = [ Math.round(largestSide / 2), Math.round(largestSide / 2) ];

  // will contain the (interpolated) data from the cube
  //var obliqueImage = np.zeros((int(largestSide), int(largestSide)), dtype=dataType )
  // initialize this._obliqueImage and the mask
  this.initObliqueImage(this._3Ddata.getDataType(), largestSide, largestSide);

  // mask of boolean to track where the filling algorithm has already been
  //var obliqueImageMask = np.zeros((int(largestSide), int(largestSide)), dtype=dataType  )

  // stack used for the fillin algorithm
  var pixelStack = [];
  pixelStack.push(obliqueImageCenter);

  var counter = 0;
  //console.log("start sampling...");



  while(pixelStack.length > 0){
    var currentPixel = pixelStack.pop();
    var x = currentPixel[0];
    var y = currentPixel[1];

    // if the image was not filled here...
    if(this.getMaskValue(x, y) == 0){
      // marking the mask (been here!)
      this.setMaskValue(x, y, 255);

      var cubeCoord = this.obliqueImageCoordToCubeCoord(obliqueImageCenter, startingSeed, x - obliqueImageCenter[0], y - obliqueImageCenter[1]);

      // get the interpolated color of the currentPixel from 3D cube
      //var color = this._3Ddata.getValueTuple(cubeCoord, interpolate);
      var color = this._3Ddata.getIntensityValue(Math.round(cubeCoord[0]), Math.round(cubeCoord[1]), Math.round(cubeCoord[2])) * depthFactor;

      // painting the image
      if(color){
          this.setImageValue(x, y, color);
      }

      // going north
      var yNorth = y + 1;
      var xNorth = x;
      if(this.getMaskValue(xNorth, yNorth) == 0){
        if(this.isImageCoordInCube(obliqueImageCenter, startingSeed, xNorth - obliqueImageCenter[0], yNorth - obliqueImageCenter[1]) ){
            pixelStack.push([xNorth, yNorth]);
        }
      }

      // going south
      var ySouth = y - 1;
      var xSouth = x;
      if(this.getMaskValue(xSouth, ySouth) == 0){
        if(this.isImageCoordInCube(obliqueImageCenter, startingSeed, xSouth - obliqueImageCenter[0], ySouth - obliqueImageCenter[1])){
            pixelStack.push([xSouth, ySouth]);
        }
      }

      // going east
      var yEast = y;
      var xEast = x + 1;
      if(this.getMaskValue(xEast, yEast) == 0){
        if(this.isImageCoordInCube(obliqueImageCenter, startingSeed, xEast - obliqueImageCenter[0], yEast - obliqueImageCenter[1])){
            pixelStack.push( [xEast, yEast] );
        }
      }

      // going west
      var yWest = y
      var xWest = x - 1
      if(this.getMaskValue(xWest, yWest) == 0){

        if(this.isImageCoordInCube(obliqueImageCenter, startingSeed, xWest - obliqueImageCenter[0], yWest - obliqueImageCenter[1])){

            pixelStack.push( [xWest, yWest] );
          }
      }

      /*
      if(counter%100 == 0){
        console.log(counter + " color: " + color);
        console.log('cubeCoord ' + cubeCoord);
      }
      */
      //counter ++;


    }
  }
}


/*
  TODO: remove
  Add the current oblique image (1D array) and plane setting to a cached array.
  We could request it then to retrieve some data.
*/
ObliqueSampler.prototype.cacheOblique = function(name){


  // TODO add a warning if sizeis too big
/*

this._obliqueImage = {
  data: imageTypedArray,
  maskData: new Int8Array(width * height),
  width: width,
  height: height
};

*/

/*
if (typeof something === "undefined") {
  alert("something is undefined");
}
*/

  if(this._obliqueImage && this._obliqueImage.data.length ){

    var currentOblique = {
      data: this._obliqueImage.data.slice(),
      width: this._obliqueImage.width,
      height: this._obliqueImage.height,
      name: null,
      planePoint: this._plane.getPoint().slice(),
      planeNormalVector: this._plane.getNormalVector().slice()
    };

    this._cachedObliques.push(currentOblique);

  }

}




/*
  TODO: remove
  return the list of all obliques that were cached.
  This is not an array but an object! (easier to deal with)
*/
ObliqueSampler.prototype.listCachedObliques = function(name){
  var nameList = {};

  for(var i=0; i<this._cachedObliques.length; i++){
    nameList[this._cachedObliques[i].name] = i;
  }

  return nameList;
}


/*
  TODO: remove
  get the full cached-oblique object
  (what was declared as currentOblique in cacheOblique() )
  given an index.
*/
ObliqueSampler.prototype.getCachedObliqueByIndex = function(index){
  if(index >= 0 && index<this._cachedObliques.length){
    return this._cachedObliques[index];
  }else{
    console.log("ERROR: the requested of cached oblique index is out of range.");
  }

  return null;
}


/*
  TODO: remove
  Uses the method _exportObliqueForCanvas() to create a html5-canvas compatible
  dataset containing the cached oblique nmatching the index.
*/
ObliqueSampler.prototype.getCachedObliqueCanvasData = function(index, factor){
  var cachedOblique = this.getCachedObliqueByIndex(index);
  var obliqueCachedCanvasData = null;

  if(cachedOblique){
    obliqueCachedCanvasData = this._exportObliqueForCanvas(
      cachedOblique.data,
      cachedOblique.width,
      cachedOblique.height,
      factor
    );

  }

  return obliqueCachedCanvasData;
}


/*
  Find the best ratio to subsample the volume so that it is fast to display.
*/
ObliqueSampler.prototype.findOptimalPreviewFactor = function(){
  var candidate = 64;
  var timeLimit = 17; // we dont want to spend more than timeLimit ms to generate a preview
  var decreasingFactor = 0.5;
  var timeMs = 0;

  console.log("Pass #1");
  while(1){
    this.setSamplingFactor(1./candidate);
    this.update();
    var t0 = performance.now();
    this.startSampling(false);
    var t1 = performance.now();
    timeMs =  (t1 - t0);

    // if the time limit is reached or the factor is 1/2,
    // we leave the first estimation round
    if(timeMs > timeLimit || candidate==2){
      break;
    }
    console.log("at 1/" + candidate + " = " + timeMs + "ms");

    // next candidate
    candidate *= decreasingFactor;
  }

  // now we know the right candidate is between
  // the current _candidate_ and _candidate_*2
  var candidateSecondPass = candidate * 2;
  decreasingFactor = 0.95;

  console.log("Pass #2");
  while(1){
    this.setSamplingFactor(1./candidateSecondPass);
    this.update();
    var t0 = performance.now();
    this.startSampling(false);
    var t1 = performance.now();
    timeMs =  (t1 - t0);

    // if the time limit is reached or the factor is 1/2,
    // we leave the first estimation round
    if(timeMs >  timeLimit || candidateSecondPass<=candidate){
      candidateSecondPass /= decreasingFactor;
      break;
    }
    console.log("at 1/" + candidateSecondPass + " = " + timeMs + "ms");

    // next candidate
    candidateSecondPass *= decreasingFactor;
  }

  this._optimalPreviewSamplingFactor = 1./ candidateSecondPass;
  console.log("optimal candidate: " + candidateSecondPass);
  console.log(this._optimalPreviewSamplingFactor);

}


/*
  Return the optimal sampling factor as it was computed.
  This is useful when we want to use multiple instances of ObliqueSampler
  over the same dataset (minc file)
*/
ObliqueSampler.prototype.getOptimalPreviewSamplingFactor = function(){
  return this._optimalPreviewSamplingFactor;
}


/*
  Creates an instance of CachedOblique and returns it.
  May be used by and external source, to put in a CachedObliqueCollection.
*/
ObliqueSampler.prototype.generateCachedOblique = function(){

  // doing a like in this.getVerticeMatchList()
  // but we prefers to deep copy the vectors for caching...
  // (you get it, right?)
  var verticeMatchList = [];
  for(var v=0; v<this._planePolygon.length; v++){
    verticeMatchList.push({
      _2D: this._planePolygon2D[v].slice(),
      _3D: this._planePolygon[v].slice()
    });
  }

  var cachedOblique = new CachedOblique( //plane, data1D, width, height, name
    this._plane,  // will be deep copyied
    this._obliqueImage.data, // will be sliced to ensure deep copy
    this._obliqueImage.width,
    this._obliqueImage.height,
    verticeMatchList,
    null // auto: the current date
  );

  return cachedOblique;
}
