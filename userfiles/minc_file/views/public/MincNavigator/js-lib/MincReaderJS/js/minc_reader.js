
/*
* Create a volume object given a header and some byte data that
* represents the voxels. Format-specific functions have to be
* used to create the header and byte_data, but this function
* combines the information into the generic data structure used
* elsewhere in the volume viewer.
*/
var createVolume = function(header, native_data) {
  var image_creation_context = document.createElement("canvas").getContext("2d");
  var cached_slices = {};

  // Populate the header with the universal fields.
  finishHeader(header);

  var volume = {
    position: {},
    current_time: 0,
    data: native_data,
    header: header,
    intensity_min: 0,
    intensity_max: 255,

    /*
      Set the color map because it will be needed by getSliceImage.
    */
    setColorMap: function(colorMap){
      volume.color_map = colorMap;
    },

    /*
    Return a slice from the minc cube as a 1D typed array,
    along with some relative data (slice size, step, etc.)
    args:
      axis: string - "xspace", "yspace" or zspace (mandatory)
      slice_num: int - index of the slice [0; length-1] (optional, default: length-1)
      time: int - index of time (optional, default: 0)

      TODO: add some method to a slice (get value) because it's a 1D array... and compare with Python
    */
    slice: function(axis, slice_num, time) {
      slice_num = slice_num === undefined ? volume.position[axis] : slice_num;
      time = time === undefined ? volume.current_time : time;

      var header = volume.header;

      if(header.order === undefined ) {
        return null;
      }

      time = time || 0;

      cached_slices[axis] = cached_slices[axis] || [];
      cached_slices[axis][time] =  cached_slices[axis][time] || [];

      if(cached_slices[axis][time][slice_num] !== undefined) {
        return cached_slices[axis][time][slice_num];
      }

      var time_offset = header.time ? time * header.time.offset : 0;

      var axis_space = header[axis];
      var width_space = axis_space.width_space;
      var height_space = axis_space.height_space;

      var width = axis_space.width;
      var height = axis_space.height;

      var axis_space_offset = axis_space.offset;
      var width_space_offset = width_space.offset;
      var height_space_offset = height_space.offset;

      // Calling the volume data's constructor guarantees that the
      // slice data buffer has the same type as the volume.
      //
      var slice_data = new volume.data.constructor(width * height);

      var slice;

      // Rows and colums of the result slice.
      var row, col;

      // Indexes into the volume, relative to the slice.
      // NOT xspace, yspace, zspace coordinates!!!
      var x, y, z;

      // Linear offsets into volume considering an
      // increasing number of axes: (t) time,
      // (z) z-axis, (y) y-axis, (x) x-axis.
      var tz_offset, tzy_offset, tzyx_offset;

      // Whether the dimension steps positively or negatively.
      var x_positive = width_space.step  > 0;
      var y_positive = height_space.step > 0;
      var z_positive = axis_space.step   > 0;

      // iterator for the result slice.
      var i = 0;
      var intensity = 0;
      var intensitySum = 0;
      var min = NaN;
      var max = NaN;

      z = z_positive ? slice_num : axis_space.space_length - slice_num - 1;
      if (z >= 0 && z < axis_space.space_length) {
        tz_offset = time_offset + z * axis_space_offset;

        for (row = height - 1; row >= 0; row--) {
          y = y_positive ? row : height - row - 1;
          tzy_offset = tz_offset + y * height_space_offset;

          for (col = 0; col < width; col++) {
            x = x_positive ? col : width - col - 1;
            tzyx_offset = tzy_offset + x * width_space_offset;

            intensity = volume.data[tzyx_offset];

            // keeping some statistics
            if(!i){
                min = intensity;
                max = intensity;
            }

            min = Math.min(min, intensity);
            max = Math.max(max, intensity);
            intensitySum += intensity;

            slice_data[i++] = intensity;

          }
        }
      }


      slice = {
        axis: axis,
        data: slice_data,
        width_space: width_space,
        height_space: height_space,
        width: width,
        height: height,
        min: min,
        max: max,
        avg: intensitySum / i,

        getValue: function(x, y){
            if(x >= 0 && x<this.width && y>=0 && y<this.height){
                return this.data[ y*this.width + x ]
            }else{
                return undefined;
            }
        }

      };

      cached_slices[axis][time][slice_num] = slice;

      return slice;
    },

    /*
      get the index where the data starts and endsm for each dimension.
      The data starts when it shows a difference from getNoDataValue(n)
      TODO: works only if NO_DATA is white 
    */
    getDataInnerBox: function(){
      // the toleranceFactor is a factor [0; 1] under witch data is sopposed to
      // be relevant. Example: 255 * 0.90 = 229 --> data is relevant when under 229
      var toleranceFactor = 0.999;

      var noDataValue = this.getNoDataValue(5);
      //console.log("noDataValue: " + noDataValue);

      var dimensionInfo = this.getDimensionInfo();
      //console.log(dimensionInfo);

      // in the same order as the dimensions are described in the header (header.order[])
      var innerBoxData = [];

      //console.log("dimensionInfo.length " + dimensionInfo.length);

      // for each dimension
      for(var d=0; d<dimensionInfo.length; d++){
        var currentAvgValue = noDataValue;
        var start = 0;
        var end = dimensionInfo[d].space_length - 1;

        // at the begining
        while(currentAvgValue > (noDataValue*toleranceFactor) && start < end){
          var currentSlice = this.slice(dimensionInfo[d].name, start);
          currentAvgValue = currentSlice.avg;
          start ++;
        }

        start --;

        // reset the avg value
        currentAvgValue = noDataValue;

        // at the end
        while(currentAvgValue > (noDataValue*toleranceFactor) && end > 0){
          var currentSlice = this.slice(dimensionInfo[d].name, end);
          currentAvgValue = currentSlice.avg;
          end --;
        }

        end ++;

        var box1D = {
          name: dimensionInfo[d].name,
          start: start,
          end: end
        }

        innerBoxData.push(box1D);




      }

      return innerBoxData;

    },

    /*
        return the header of the data
    */
    getHeader: function(){
        return header;
    },


    getDimensionInfo: function(){
        var info = [];

        for(var d=0; d<header.order.length; d++){
            var name = header.order[d];

            var elem = {
                name: name,
                height: header[name].height,
                width: header[name].width,
                space_length: header[name].space_length
            }

            info.push(elem);

        }

        return info;
    },

    /*
      PRIVATE
      Calculate the world to voxel transform and save it, so we
      can access it efficiently. The transform is:
      cxx / stepx | cxy / stepx | cxz / stepx | (-o.x * cxx - o.y * cxy - o.z * cxz) / stepx
      cyx / stepy | cyy / stepy | cyz / stepy | (-o.x * cyx - o.y * cyy - o.z * cyz) / stepy
      czx / stepz | czy / stepz | czz / stepz | (-o.x * czx - o.y * czy - o.z * czz) / stepz
      0           | 0           | 0           | 1

      Origin equation taken from (http://www.bic.mni.mcgill.ca/software/minc/minc2_format/node4.html)
    */
    saveOriginAndTransform: function(header) {
      var startx = header.xspace.start;
      var starty = header.yspace.start;
      var startz = header.zspace.start;
      var cx = header.xspace.direction_cosines;
      var cy = header.yspace.direction_cosines;
      var cz = header.zspace.direction_cosines;
      var stepx = header.xspace.step;
      var stepy = header.yspace.step;
      var stepz = header.zspace.step;
      header.voxel_origin = {
        x: startx * cx[0] + starty * cy[0] + startz * cz[0],
        y: startx * cx[1] + starty * cy[1] + startz * cz[1],
        z: startx * cx[2] + starty * cy[2] + startz * cz[2]
      };
      var o = header.voxel_origin;

      var tx = (-o.x * cx[0] - o.y * cx[1] - o.z * cx[2]) / stepx;
      var ty = (-o.x * cy[0] - o.y * cy[1] - o.z * cy[2]) / stepy;
      var tz = (-o.x * cz[0] - o.y * cz[1] - o.z * cz[2]) / stepz;

      header.w2v = [
        [cx[0] / stepx, cx[1] / stepx, cx[2] / stepx, tx],
        [cy[0] / stepy, cy[1] / stepy, cy[2] / stepy, ty],
        [cz[0] / stepz, cz[1] / stepz, cz[2] / stepz, tz]
      ];
    },


    /*
      Originaly for debug purpose. valid if slice.data is a Uint8Array
      Returns a canvas compliant imageData.
      args:
        slice: obj - slice got with slice() (mandatory)
        factor: float - a factor to shrink slice.data into [0; 255] (optional)
              example: if slice.data are uint16, factor can be (1./255.)
    */
    getSliceImageNoColorMap: function(slice, factor){
      var simpleImageContext = document.createElement("canvas").getContext("2d");
      var width = slice.width;
      var height = slice.height;

      var image = simpleImageContext.createImageData(width, height);
      var rgbaArray = new Uint8ClampedArray(slice.data.length * 4);

      // from single channel array to RGBA buff, just repeat the value...
      for(var i=0; i<slice.data.length; i++){
        rgbaArray[i*4] = slice.data[i] * factor;
        rgbaArray[i*4 +1] = slice.data[i] * factor;
        rgbaArray[i*4 +2] = slice.data[i] * factor;
        rgbaArray[i*4 +3] = 255;
      }

      image.data.set(rgbaArray, 0);

      return image;
    },


    /*
      return the datatype used for encoding the voxel.
      string, example 'uint8'
    */
    getDataType: function(){
      return this.header.datatype;
    },

    /*
      WARNNING: a color_map should be loaded first (as an atribute of volume)
      Create an image from a slice and a color map. The image is canvas compliant.
      args:
        slice: slice object, previously got from the slice() method (mandatory)
        zoom: float - a zoom factor (optional, default: 1)
        contrast: float - contrast factor  (optional)
        brightness: float - brightness factor (optional)
    */
    getSliceImage: function(slice, zoom, contrast, brightness) {
      zoom = zoom || 1;

      var color_map = volume.color_map;
      var error_message;

      if (!color_map) {
        error_message = "No color map set for this volume. Cannot render slice.";
        //volume.triggerEvent("error", error_message);
        throw new Error(error_message);
      }

      var xstep = slice.width_space.step;
      var ystep = slice.height_space.step;
      var target_width = Math.abs(Math.floor(slice.width * xstep * zoom));
      var target_height = Math.abs(Math.floor(slice.height * ystep * zoom));
      var source_image = image_creation_context.createImageData(slice.width, slice.height);
      var target_image = image_creation_context.createImageData(target_width, target_height);

      if (volume.header.datatype === 'rgb8') {
        var tmp = new Uint8ClampedArray(slice.data.buffer);
        source_image.data.set(tmp, 0);
      }
      else {
        color_map.mapColors(slice.data, {
          min: volume.intensity_min,
          max: volume.intensity_max,
          contrast: contrast,
          brightness: brightness,
          destination: source_image.data
        });
      }

      target_image.data.set(
        nearestNeighbor(
          source_image.data,
          source_image.width,
          source_image.height,
          target_width,
          target_height,
          {block_size: 4}
        )
      );

      return target_image;
    },

    /*
      return an average value of what is seems to be the NO_DATA value.
      This value is found by checking at the corners of the minc cube.
      Sample is the size of each sample taken at every corner,
      if 5, then 125 voxels will be used at every corner to evaluate the void value,
      for a total sample of 500 voxels
    */
    getNoDataValue: function(sample){
      var sum = 0;
      var numberOfVoxels = sample * sample * sample * 8;

      // corner 1
      for(var i=0; i<sample; i++){
        for(var j=0; j<sample; j++){
          for(var k=0; k<sample; k++){
            sum += this.getIntensityValue(i, j, k);
          }
        }
      }

      // corner 2
      for(var i=header[header.order[0]].space_length - 1 - sample; i<header[header.order[0]].space_length - 1; i++){
        for(var j=0; j<sample; j++){
          for(var k=0; k<sample; k++){
            sum += this.getIntensityValue(i, j, k);
          }
        }
      }

      // corner 3
      for(var i=header[header.order[0]].space_length - 1 - sample; i<header[header.order[0]].space_length - 1; i++){
        for(var j=0; j<sample; j++){
          for(var k=header[header.order[2]].space_length - 1 - sample; k<header[header.order[2]].space_length - 1; k++){
            sum += this.getIntensityValue(i, j, k);
          }
        }
      }

      // corner 4
      for(var i=0; i<sample; i++){
        for(var j=0; j<sample; j++){
          for(var k=header[header.order[2]].space_length - 1 - sample; k<header[header.order[2]].space_length - 1; k++){
            sum += this.getIntensityValue(i, j, k);
          }
        }
      }

      // corner 5
      for(var i=0; i<sample; i++){
        for(var j=header[header.order[1]].space_length - 1 - sample; j<header[header.order[1]].space_length - 1; j++){
          for(var k=0; k<sample; k++){
            sum += this.getIntensityValue(i, j, k);
          }
        }
      }

      // corner 6
      for(var i=header[header.order[0]].space_length - 1 - sample; i<header[header.order[0]].space_length - 1; i++){
        for(var j=header[header.order[1]].space_length - 1 - sample; j<header[header.order[1]].space_length - 1; j++){
          for(var k=0; k<sample; k++){
            sum += this.getIntensityValue(i, j, k);
          }
        }
      }

      // corner 7
      for(var i=header[header.order[0]].space_length - 1 - sample; i<header[header.order[0]].space_length - 1; i++){
        for(var j=header[header.order[1]].space_length - 1 - sample; j<header[header.order[1]].space_length - 1; j++){
          for(var k=header[header.order[2]].space_length - 1 - sample; k<header[header.order[2]].space_length - 1; k++){
            sum += this.getIntensityValue(i, j, k);
          }
        }
      }

      // corner 8
      for(var i=0; i<sample; i++){
        for(var j=header[header.order[1]].space_length - 1 - sample; j<header[header.order[1]].space_length - 1; j++){
          for(var k=header[header.order[2]].space_length - 1 - sample; k<header[header.order[2]].space_length - 1; k++){
            sum += this.getIntensityValue(i, j, k);
          }
        }
      }

      return sum / numberOfVoxels;
    },

    /*
      Return the intensity value from the minc cube.
      args:
        i: int - depending on the orientation, it may be along the x axis (mandatory)
        j: int - depending on the orientation, it may be along the y axis (mandatory)
        k: int - depending on the orientation, it may be along the z axis (mandatory)
        time: int - instance in time (optional, default: 0)
    */
    getIntensityValue: function(i, j, k, time) {
      var header = volume.header;
      var vc = volume.getVoxelCoords();
      i = i === undefined ? vc.i : i;
      j = j === undefined ? vc.j : j;
      k = k === undefined ? vc.k : k;
      time = time === undefined ? volume.current_time : time;

      if (i < 0 || i >= header[header.order[0]].space_length ||
        j < 0 || j >= header[header.order[1]].space_length ||
        k < 0 || k >= header[header.order[2]].space_length) {
          return 0;
      }
      var time_offset = header.time ? time * header.time.offset : 0;
      var xyzt_offset = (i * header[header.order[0]].offset +
        j * header[header.order[1]].offset +
        k * header[header.order[2]].offset +
        time_offset);

      return volume.data[xyzt_offset];
    },


    /*
      PRIVATE (mostly)
    */
    getVoxelCoords: function() {
      var header = volume.header;
      var position = {
        xspace: header.xspace.step > 0 ? volume.position.xspace : header.xspace.space_length - volume.position.xspace,
        yspace: header.yspace.step > 0 ? volume.position.yspace : header.yspace.space_length - volume.position.yspace,
        zspace: header.zspace.step > 0 ? volume.position.zspace : header.zspace.space_length - volume.position.zspace
      };

      return {
        i: position[header.order[0]],
        j: position[header.order[1]],
        k: position[header.order[2]],
      };
    },


    /*
      PRIVATE (mostly)
    */
    setVoxelCoords: function(i, j, k) {
      var header = volume.header;
      var ispace = header.order[0];
      var jspace = header.order[1];
      var kspace = header.order[2];

      volume.position[ispace] = header[ispace].step > 0 ? i : header[ispace].space_length - i;
      volume.position[jspace] = header[jspace].step > 0 ? j : header[jspace].space_length - j;
      volume.position[kspace] = header[kspace].step > 0 ? k : header[kspace].space_length - k;
    },


    /*
      TODO
    */
    getWorldCoords: function() {
      var voxel = volume.getVoxelCoords();
      return volume.voxelToWorld(voxel.i, voxel.j, voxel.k);
    },


    /*
      TODO
    */
    setWorldCoords: function(x, y, z) {
      var voxel = volume.worldToVoxel(x, y, z);

      volume.setVoxelCoords(voxel.i, voxel.j, voxel.k);
    },


    /*
      Voxel to world matrix applied here is:
      cxx * stepx | cyx * stepy | czx * stepz | ox
      cxy * stepx | cyy * stepy | czy * stepz | oy
      cxz * stepx | cyz * stepy | czz * stepz | oz
      0           | 0           | 0           | 1

      Taken from (http://www.bic.mni.mcgill.ca/software/minc/minc2_format/node4.html)
    */
    voxelToWorld: function(i, j, k) {
      var ordered = {};
      var x, y, z;
      var header = volume.header;

      ordered[header.order[0]] = i;
      ordered[header.order[1]] = j;
      ordered[header.order[2]] = k;

      x = ordered.xspace;
      y = ordered.yspace;
      z = ordered.zspace;

      var cx = header.xspace.direction_cosines;
      var cy = header.yspace.direction_cosines;
      var cz = header.zspace.direction_cosines;
      var stepx = header.xspace.step;
      var stepy = header.yspace.step;
      var stepz = header.zspace.step;
      var o = header.voxel_origin;

      return {
        x: x * cx[0] * stepx + y * cy[0] * stepy + z * cz[0] * stepz + o.x,
        y: x * cx[1] * stepx + y * cy[1] * stepy + z * cz[1] * stepz + o.y,
        z: x * cx[2] * stepx + y * cy[2] * stepy + z * cz[2] * stepz + o.z
      };
    },


    /*
      Inverse of the voxel to world matrix.
    */
    worldToVoxel: function(x, y, z) {
      var xfm = header.w2v;   // Get the world-to-voxel transform.
      var result = {
        vx: x * xfm[0][0] + y * xfm[0][1] + z * xfm[0][2] + xfm[0][3],
        vy: x * xfm[1][0] + y * xfm[1][1] + z * xfm[1][2] + xfm[1][3],
        vz: x * xfm[2][0] + y * xfm[2][1] + z * xfm[2][2] + xfm[2][3]
      };

      var ordered = {};
      ordered[header.order[0]] = Math.round(result.vx);
      ordered[header.order[1]] = Math.round(result.vy);
      ordered[header.order[2]] = Math.round(result.vz);

      return {
        i: ordered.xspace,
        j: ordered.yspace,
        k: ordered.zspace
      };
    },


    /*
      returns the minimum value found within the dataset.
    */
    getVoxelMin: function() {
      return volume.header.voxel_min;
    },


    /*
      returns the maximum value found within the dataset.
    */
    getVoxelMax: function() {
      return volume.header.voxel_max;
    },

    /*
      given a width and height (from the panel), this function returns the "best"
      single zoom level that will guarantee that the image fits exactly into the
      current panel.
    */
    getPreferredZoom: function(width, height) {
      var header = volume.header;
      var x_fov = header.xspace.space_length * Math.abs(header.xspace.step);
      var y_fov = header.yspace.space_length * Math.abs(header.yspace.step);
      var z_fov = header.zspace.space_length * Math.abs(header.xspace.step);
      var xw = width / x_fov;
      var yw = width / y_fov;
      var yh = height / y_fov;
      var zh = height / z_fov;
      return Math.min(yw, xw, zh, yh);
    },


    /*
      each edge has a index, TODO: write about it.
      return a list of edge data like that:
      edgeData[n][vector, point]
      where n is [0, 11] (a cube has 12 edges),
      vector is a tuple (x, y, z),
      and point is a point from the edge, also a tuple (x, y, z)
    */
    getEdgesEquations: function(){
      var iLength = header[header.order[0]].space_length;
      var jLength = header[header.order[1]].space_length;
      var kLength = header[header.order[2]].space_length;

      var edgeData = [];

      // 0
      //vector:
      var edge0Vect = [iLength, 0, 0];
      var edge0Point = [0, 0, 0];

      // 1
      // vector:
      var edge1Vect = [0, jLength, 0];
      var edge1Point = [0, 0, 0];

      // 2
      // vector:
      var edge2Vect = [0, 0, kLength];
      var edge2Point = [0, 0, 0];

      // 3
      // vector:
      var edge3Vect = [0, 0, kLength];
      var edge3Point = [iLength, 0, 0];

      // 4
      // vector:
      var edge4Vect = [iLength, 0, 0];
      var edge4Point = [0, 0, kLength];

      // 5
      // vector:
      var edge5Vect = [iLength, 0, 0];
      var edge5Point = [0, jLength, 0];

      // 6
      // vector:
      var edge6Vect = [0, 0, kLength];
      var edge6Point = [0, jLength, 0];

      // 7
      // vector:
      var edge7Vect = [0, 0, kLength];
      var edge7Point = [iLength, jLength, 0];

      // 8
      // vector:
      var edge8Vect = [iLength, 0, 0];
      var edge8Point = [0, jLength, kLength];

      // 9
      // vector:
      var edge9Vect = [0, jLength, 0];
      var edge9Point = [0, 0, kLength];

      // 10
      // vector:
      var edge10Vect = [0, jLength, 0];
      var edge10Point = [iLength, 0, 0];

      // 11
      // vector:
      var edge11Vect = [0, jLength, 0];
      var edge11Point = [iLength, 0, kLength];

      edgeData.push( [edge0Vect, edge0Point] );
      edgeData.push( [edge1Vect, edge1Point] );
      edgeData.push( [edge2Vect, edge2Point] );
      edgeData.push( [edge3Vect, edge3Point] );
      edgeData.push( [edge4Vect, edge4Point] );
      edgeData.push( [edge5Vect, edge5Point] );
      edgeData.push( [edge6Vect, edge6Point] );
      edgeData.push( [edge7Vect, edge7Point] );
      edgeData.push( [edge8Vect, edge8Point] );
      edgeData.push( [edge9Vect, edge9Point] );
      edgeData.push( [edge10Vect, edge10Point] );
      edgeData.push( [edge11Vect, edge11Point] );

      return edgeData;

    },

    /*
      return True if the given point is within the data cube.
      when allowEdges is true, the upper boundaries are pushed
      by +1 in x, y and z
    */
    isWithin: function(point, allowEdges){
      var iLength = header[header.order[0]].space_length;
      var jLength = header[header.order[1]].space_length;
      var kLength = header[header.order[2]].space_length;

      if(allowEdges){
          if(point[0] >= 0 &&
            point[1] >= 0 &&
            point[2] >= 0 &&
            point[0] <= iLength &&
            point[1] <= jLength &&
            point[2] <= kLength ){
            return true
           }
      }else{
          if(point[0] >= 0 &&
            point[1] >= 0 &&
            point[2] >= 0 &&
            point[0] < iLength &&
            point[1] < jLength &&
            point[2] < kLength ){
              return true
            }
      }

      return false
    },

  };

  return volume;
};




/*
  Scan the entire data and look for the min and max.
  The extremas are set into the header.
  args:
    native_data: typed array - 1D large array that contains
        all voxel data for each of the 3 dimensions.
    header: obj - object that describe the data stored in native_data
*/
var scanDataRange = function(native_data, header) {
  var d = 0;
  var n_min = +Infinity;
  var n_max = -Infinity;

  for (d = 0; d < native_data.length; d++) {
    var value = native_data[d];
    if (value > n_max)
    n_max = value;
    if (value < n_min)
    n_min = value;
  }
  header.voxel_min = n_min;
  header.voxel_max = n_max;
};


/*
  initialize the large 1D array of data depending on the type found.
  Rearange the original ArrayBuffer into a typed array.
  args:
    header: obj - header of the data
    raw_data: ArrayBuffer - sub object given by hdf5Loader
*/
var createMincData = function(header, raw_data){

  var native_data = null;

  switch (header.datatype) {
    case 'int8':
    native_data = new Int8Array(raw_data);
    break;
    case 'int16':
    native_data = new Int16Array(raw_data);
    break;
    case 'int32':
    native_data = new Int32Array(raw_data);
    break;
    case 'float32':
    native_data = new Float32Array(raw_data);
    break;
    case 'float64':
    native_data = new Float64Array(raw_data);
    break;
    case 'uint8':
    native_data = new Uint8Array(raw_data);
    break;
    case 'uint16':
    native_data = new Uint16Array(raw_data);
    break;
    case 'uint32':
    case 'rgb8':
    native_data = new Uint32Array(raw_data);
    break;
    default:
    var error_message = "Unsupported data type: " + header.datatype;
    console.log({ message: error_message } );
    //BrainBrowser.events.triggerEvent("error", { message: error_message } );
    throw new Error(error_message);
  }

  scanDataRange(native_data, header);
  return native_data;
}








/*
  create the minc data giving the header and raw data.
  args:
    header: obj - sub object given by hdf5Loader in the first place,
            but then processed by parseHeader (mandatory)
    raw_data: ArrayBuffer - sub object given by hdf5Loader

*/
var createMincVolume = function(header, raw_data){
  var volume = createVolume(header, createMincData(header, raw_data));
  volume.type = "minc";

  volume.saveOriginAndTransform(header);
  volume.intensity_min = header.voxel_min;
  volume.intensity_max = header.voxel_max;

  return volume;

}




/*
  Creates common fields all headers must contain.
  args:
    header: obj - header to describe the data,
      pretty empty at this stage.
*/
var finishHeader = function(header) {
  header.xspace.name = "xspace";
  header.yspace.name = "yspace";
  header.zspace.name = "zspace";

  header.xspace.width_space  = header.yspace;
  header.xspace.width        = header.yspace.space_length;
  header.xspace.height_space = header.zspace;
  header.xspace.height       = header.zspace.space_length;

  header.yspace.width_space  = header.xspace;
  header.yspace.width        = header.xspace.space_length;
  header.yspace.height_space = header.zspace;
  header.yspace.height       = header.zspace.space_length;

  header.zspace.width_space  = header.xspace;
  header.zspace.width        = header.xspace.space_length;
  header.zspace.height_space = header.yspace;
  header.zspace.height       = header.yspace.space_length;

  if (header.voxel_min === undefined)
  header.voxel_min = 0;
  if (header.voxel_max === undefined)
  header.voxel_max = 255;
}


/*
  Tranforms a hdf5 text header (given by hdf5Loader() )
  into a functional object minc header.
  args:
    header_text: string - text header from hdf5 output
*/
var parseHeader = function(header_text) {
  var header;
  var error_message;

  try{
    header = JSON.parse(header_text);
  } catch(error) {
    error_message = "server did not respond with valid JSON" + "\n" +
    "Response was: \n" + header_text;

    console.log( { message: error_message });

    //  BrainBrowser.events.triggerEvent("error", { message: error_message });
    throw new Error(error_message);
  }

  if(header.order.length === 4) {
    header.order = header.order.slice(1);
  }

  header.datatype = header.datatype || "uint8";

  header.xspace.space_length = parseFloat(header.xspace.space_length);
  header.yspace.space_length = parseFloat(header.yspace.space_length);
  header.zspace.space_length = parseFloat(header.zspace.space_length);

  header.xspace.start = parseFloat(header.xspace.start);
  header.yspace.start = parseFloat(header.yspace.start);
  header.zspace.start = parseFloat(header.zspace.start);

  header.xspace.step = parseFloat(header.xspace.step);
  header.yspace.step = parseFloat(header.yspace.step);
  header.zspace.step = parseFloat(header.zspace.step);

  header.xspace.direction_cosines = header.xspace.direction_cosines || [1, 0, 0];
  header.yspace.direction_cosines = header.yspace.direction_cosines || [0, 1, 0];
  header.zspace.direction_cosines = header.zspace.direction_cosines || [0, 0, 1];

  header.xspace.direction_cosines = header.xspace.direction_cosines.map(parseFloat);
  header.yspace.direction_cosines = header.yspace.direction_cosines.map(parseFloat);
  header.zspace.direction_cosines = header.zspace.direction_cosines.map(parseFloat);

  /* Incrementation offsets for each dimension of the volume.
  * Note that this somewhat format-specific, so it does not
  * belong in the generic "createVolume()" code.
  */
  header[header.order[0]].offset = header[header.order[1]].space_length * header[header.order[2]].space_length;
  header[header.order[1]].offset = header[header.order[2]].space_length;
  header[header.order[2]].offset = 1;

  if(header.time) {
    header.time.space_length = parseFloat(header.time.space_length);
    header.time.start = parseFloat(header.time.start);
    header.time.step = parseFloat(header.time.step);
    header.time.offset = header.xspace.space_length * header.yspace.space_length * header.zspace.space_length;
  }


  return header;


}



/*
  - brough back from utils -
  Returns a Uint8ClampedArray (a specific kind of typed array for [0, 255] int)
  that will fill a canvas.
*/
var nearestNeighbor = function(source, width, height, target_width, target_height, options) {
  options = options || {};

  var block_size = options.block_size || 1;
  var ArrayType = options.array_type || Uint8ClampedArray;

  var x_ratio, y_ratio;
  var source_y_offset, source_block_offset;
  var target;
  var target_x, target_y;
  var target_y_offset, target_block_offset;
  var k;

  //Do nothing if size is the same
  if(width === target_width && height === target_height) {
    return source;
  }

  target = new ArrayType(target_width * target_height * block_size);
  x_ratio   = width / target_width;
  y_ratio   = height / target_height;
  for (target_y = 0; target_y < target_height; target_y++) {
    source_y_offset = Math.floor(target_y * y_ratio) * width;
    target_y_offset = target_y * target_width;

    for (target_x = 0; target_x < target_width; target_x++)  {
      source_block_offset = (source_y_offset + Math.floor(target_x * x_ratio)) * block_size;
      target_block_offset = (target_y_offset + target_x) * block_size;

      for (k = 0; k < block_size; k++) {
        target[target_block_offset+ k] = source[source_block_offset + k];
      }
    }
  }

  return target;
}


/*
  This is a wrapper for reading a Minc2 file (hdf5).
  Return: volume
*/
var readMincBuffer = function(buffer){
  hdf5_data = hdf5Loader(buffer);


  minc_header = parseHeader(hdf5_data.header_text);

  //console.log('minc_header:');
  //console.log(minc_header);

  minc_volume = createMincVolume(minc_header, hdf5_data.raw_data);

  //console.log('minc_volume:');
  //console.log(minc_volume);

  return minc_volume;

}
