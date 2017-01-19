//(function () {
'use strict';
/* Internal type codes. These have nothing to do with HDF5. */
var type_enum = {
    INT8: 1,
    UINT8: 2,
    INT16: 3,
    UINT16: 4,
    INT32: 5,
    UINT32: 6,
    FLT: 7,
    DBL: 8,
    STR: 9
};


var type_matching = [
  "int8",
  "uint8",
  "int16",
  "uint16",
  "int32",
  "uint32",
  "float32",
  "float64",
  "undef" // STR type is not compatible with minc
  // we deal rgb8 manually
];


/*
  The hdf5 reader deals with type_enum while minc adapter deals with
  the types from type_matching. This function return the minc equivalent.
  args:
    typeEnumVal: int - a value from type_enum

*/
function getTypeMatchMinc(typeEnumVal){
  return type_matching[typeEnumVal - 1];
}



/* The following polyfill copied verbatim from MDN 2016-06-16 */
if (!Array.prototype.find) {
    Array.prototype.find = function(predicate) {
        if (this === null) {
            throw new TypeError('Array.prototype.find called on null or undefined');
        }
        if (typeof predicate !== 'function') {
            throw new TypeError('predicate must be a function');
        }
        var list = Object(this);
        var length = list.length >>> 0;
        var thisArg = arguments[1];
        var value;

        for (var i = 0; i < length; i++) {
            value = list[i];
            if (predicate.call(thisArg, value, i, list)) {
                return value;
            }
        }
        return undefined;
    };
}

function defined(x) {
    return typeof x !== 'undefined';
}

function typeName(x) {
    if (!defined(x)) {
        return "undefined";
    }
    return x.constructor.name;
}

var type_sizes = [0, 1, 1, 2, 2, 4, 4, 4, 8, 0];

function typeSize(typ) {
    if (typ >= type_enum.INT8 && typ < type_sizes.length) {
        return type_sizes[typ];
    }
    throw new Error('Unknown type ' + typ);
}

function typeIsFloat(typ) {
    return (typ >= type_enum.FLT && typ <= type_enum.DBL);
}


  /*
   * The remaining code after this point is not truly HDF5 specific -
   * it's mostly about converting the MINC file into the form
   * BrainBrowser is able to use. Therefore it is used for both HDF5
   * and NetCDF files.
   */

  /*
   * Join does not seem to be defined on the typed arrays in
   * javascript, so I've re-implemented it here, sadly.
   */
  function join(array, string) {
    var result = "";
    if (array && array.length) {
      var i;
      for (i = 0; i < array.length - 1; i += 1) {
        result += array[i];
        result += string;
      }
      result += array[i];
    }
    return result;
  }

  /*
   * Recursively print out the structure and contents of the file.
   * Primarily useful for debugging.
   */
  function printStructure(link, level) {
    var i;
    var msg = "";
    for (i = 0; i < level * 2; i += 1) {
      msg += " ";
    }
    msg += link.name + (link.children.length ? "/" : "");
    if (link.type > 0) {
      msg += ' ' + typeName(link.array);
      if (link.dims.length) {
        msg += '[' + link.dims.join(', ') + ']';
      }
      if (link.array) {
        msg += ":" + link.array.length;
      } else {
        msg += " NULL";
      }
    }
    console.log(msg);

    Object.keys(link.attributes).forEach(function (name) {
      var value = link.attributes[name];

      msg = "";
      for (i = 0; i < level * 2 + 1; i += 1) {
        msg += " ";
      }
      msg += link.name + ':' + name + " " +
        typeName(value) + "[" + value.length + "] ";
      if (typeof value === "string") {
        msg += JSON.stringify(value);
      } else {
        msg += "{" + join(value.slice(0, 16), ', ');
        if (value.length > 16) {
          msg += ", ...";
        }
        msg += "}";
      }
      console.log(msg);
    });

    link.children.forEach(function (child) {
      printStructure(child, level + 1);
    });
  }

  /* Find a dataset with a given name, by recursively searching through
   * the links. Groups will have 'type' fields of -1, since they contain
   * no data.
   * TODO (maybe): Use associative array for children?
   */
  function findDataset(link, name, level) {
    var result;
    if (link && link.name === name && link.type > 0) {
      result = link;
    } else {
      link.children.find( function( child ) {
        result = findDataset(child, name, level + 1);
        return defined(result);
      });
    }
    return result;
  }

  /* Find an attribute with a given name.
   */
  function findAttribute(link, name, level) {
    var result = link.attributes[name];
    if (result)
      return result;

    link.children.find( function (child ) {
      result = findAttribute( child, name, level + 1);
      return defined(result);
    });
    return result;
  }

  /**
   * @doc function
   * @name hdf5.scaleVoxels
   * @param {object} image The link object corresponding to the image data.
   * @param {object} image_min The link object corresponding to the image-min
   * data.
   * @param {object} image_max The link object corresponding to the image-max
   * data.
   * @param {object} valid_range An array of exactly two items corresponding
   * to the minimum and maximum valid _raw_ voxel values.
   * @param {boolean} debug True if we should print debugging information.
   * @returns A new ArrayBuffer containing the rescaled data.
   * @description
   * Convert the MINC data from voxel to real range. This returns a
   * new buffer that contains the "real" voxel values. It does less
   * work for floating-point volumes, since they don't need scaling.
   *
   * For debugging/testing purposes, also gathers basic voxel statistics,
   * for comparison against mincstats.
   */
  function scaleVoxels(image, image_min, image_max, valid_range, debug) {
    /*
    var new_abuf = new ArrayBuffer(image.array.length *
                                   Float32Array.BYTES_PER_ELEMENT);
    var new_data = new Float32Array(new_abuf);

    */

    // 1D array to store the voxel data,
    // not initialized yet because it depends on the hdf5 type.
    var new_abuf = null;
    var new_data = null;

    // we could simply use image.type, but written types are easier to read...
    switch (getTypeMatchMinc(image.type)) {
      case 'int8':
        new_abuf = new ArrayBuffer(image.array.length * Int8Array.BYTES_PER_ELEMENT);
        new_data = new Int8Array(new_abuf);
        break;

      case 'int16':
        new_abuf = new ArrayBuffer(image.array.length * Int16Array.BYTES_PER_ELEMENT);
        new_data = new Int16Array(new_abuf);
        break;

      case 'int32':
        new_abuf = new ArrayBuffer(image.array.length * Int32Array.BYTES_PER_ELEMENT);
        new_data = new Int32Array(new_abuf);
        break;

      case 'float32':
        new_abuf = new ArrayBuffer(image.array.length * Float32Array.BYTES_PER_ELEMENT);
        new_data = new Float32Array(new_abuf);
        break;

      case 'float64':
        new_abuf = new ArrayBuffer(image.array.length * Float64Array.BYTES_PER_ELEMENT);
        new_data = new Float64Array(new_abuf);
        break;

      case 'uint8':
        new_abuf = new ArrayBuffer(image.array.length * Uint8Array.BYTES_PER_ELEMENT);
        new_data = new Uint8Array(new_abuf);
        break;

      case 'uint16':
        new_abuf = new ArrayBuffer(image.array.length * Uint16Array.BYTES_PER_ELEMENT);
        new_data = new Uint16Array(new_abuf);
        break;

      case 'uint32':
        new_abuf = new ArrayBuffer(image.array.length * Uint32Array.BYTES_PER_ELEMENT);
        new_data = new Uint32Array(new_abuf);
        break;

      default:
        var error_message = "Unsupported data type: " + header.datatype;
        console.log({ message: error_message } );
        //BrainBrowser.events.triggerEvent("error", { message: error_message } );
        throw new Error(error_message);

    }


    var n_slice_dims = image.dims.length - image_min.dims.length;

    if (n_slice_dims < 1) {
      throw new Error("Too few slice dimensions: " + image.dims.length +
                      " " + image_min.dims.length);
    }
    var n_slice_elements = 1;
    var i;
    for (i = image_min.dims.length; i < image.dims.length; i += 1) {
      n_slice_elements *= image.dims[i];
    }
    if (debug) {
      console.log(n_slice_elements + " voxels in slice.");
    }
    var s = 0;
    var c = 0;
    var x = -Number.MAX_VALUE;
    var n = Number.MAX_VALUE;
    var im = image.array;
    var im_max = image_max.array;
    var im_min = image_min.array;
    if (debug) {
      console.log("valid range is " + valid_range[0] + " to " + valid_range[1]);
    }

    var vrange;
    var rrange;
    var vmin = valid_range[0];
    var rmin;
    var j;
    var v;
    var is_float = typeIsFloat(image.type);
    for (i = 0; i < image_min.array.length; i += 1) {
      if (debug) {
        console.log(i + " " + im_min[i] + " " + im_max[i] + " " +
                    im[i * n_slice_elements]);
      }
      if (is_float) {
        /* For floating-point volumes there is no scaling to be performed.
         * We do scan the data and make sure voxels are within the valid
         * range, and collect our statistics.
         */
        for (j = 0; j < n_slice_elements; j += 1) {
          v = im[c];
          if (v < valid_range[0] || v > valid_range[1]) {
            new_data[c] = 0.0;
          }
          else {
            new_data[c] = v;
            s += v;
            if (v > x) {
              x = v;
            }
            if (v < n) {
              n = v;
            }
          }
          c += 1;
        }
      }
      else {
        /* For integer volumes we have to scale each slice according to image-min,
         * image-max, and valid_range.
         */
        vrange = (valid_range[1] - valid_range[0]);
        rrange = (im_max[i] - im_min[i]);
        rmin = im_min[i];

        /*
        console.log(n_slice_elements);
        console.log(vrange);
        console.log(rrange);
        console.log(rmin);
        console.log("-----------------");
        */


        for (j = 0; j < n_slice_elements; j += 1) {

          // v normalization to avoid "flickering".
          // v is scaled to the range [0, im_max[i]]
          // (possibly uint16 if the original per-slice min-max was not scaled up/down)
          v = (im[c] - vmin) / vrange * rrange + rmin;

          // we scale up/down to match the type of the target array
          v = v / im_max[i] * valid_range[1];


          new_data[c] = v;
          s += v;
          c += 1;
          if (v > x) {
            x = v;
          }
          if (v < n) {
            n = v;
          }

        }

      }
    }

    if (debug) {
      console.log("Min: " + n);
      console.log("Max: " + x);
      console.log("Sum: " + s);
      console.log("Mean: " + s / c);
    }

    return new_abuf;
  }

  /**
   * @doc function
   * @name hdf5.isRgbVolume
   * @param {object} header The header object representing the structure
   * of the MINC file.
   * @param {object} image The typed array object used to represent the
   * image data.
   * @returns {boolean} True if this is an RGB volume.
   * @description
   * A MINC volume is an RGB volume if all three are true:
   * 1. The voxel type is unsigned byte.
   * 2. It has a vector_dimension in the last (fastest-varying) position.
   * 3. The vector dimension has length 3.
   */
  function isRgbVolume(header, image) {
    var order = header.order;
    return (image.array.constructor.name === 'Uint8Array' &&
            order.length > 0 &&
            order[order.length - 1] === "vector_dimension" &&
            header.vector_dimension.space_length === 3);
  }

  /**
   * @doc function
   * @name hdf5.rgbVoxels
   * @param {object} image The 'link' object created using createLink(),
   * that corresponds to the image within the HDF5 or NetCDF file.
   * @returns {object} A new ArrayBuffer that contains the original RGB
   * data augmented with alpha values.
   * @description
   * This function copies the RGB voxels to the destination buffer.
   * Essentially we just convert from 24 to 32 bits per voxel. This
   * is another MINC-specific function.
   */
  function rgbVoxels(image) {
    var im = image.array;
    var n = im.length;
    var new_abuf = new ArrayBuffer(n / 3 * 4);
    var new_byte = new Uint8Array(new_abuf);
    var i, j = 0;
    for (i = 0; i < n; i += 3) {
      new_byte[j+0] = im[i+0];
      new_byte[j+1] = im[i+1];
      new_byte[j+2] = im[i+2];
      new_byte[j+3] = 255;
      j += 4;
    }
    return new_abuf;
  }


  /**
   * @doc function
   * @name hdf5Loader
   * @param {object} data An ArrayBuffer object that contains the binary
   * data to be interpreted as an HDF5 file.
   *
   * @description This function is the primary entry point for loading
   * either MINC 1.0 or 2.0 files. It attempts to interpret the file
   * as an HDF5 (MINC 2.0) file. If that fails (e.g. throws an
   * exception), the code falls back to interpreting the file as a
   * NetCDF (MINC 1.0) file.
   */
  var hdf5Loader = function (data) {
    var debug = false;

    var root;
    try {
      root = hdf5Reader(data, debug);
    } catch (e) {
      if (debug) {
        console.log(e);
        console.log("Error, this may be NetCDF...");
      }

    }
    if (debug) {
      printStructure(root, 0);
    }

    /* The rest of this code is MINC-specific, so like some of the
     * functions above, it can migrate into minc.js once things have
     * stabilized.
     *
     * This code is responsible for collecting up the various pieces
     * of important data and metadata, and reorganizing them into the
     * form the volume viewer can handle.
     */
    var image = findDataset(root, "image");
    if (!defined(image)) {
      throw new Error("Can't find image dataset.");
    }
    var valid_range = findAttribute(image, "valid_range", 0);
    /* If no valid_range is found, we substitute our own. */
    if (!defined(valid_range)) {
      var min_val;
      var max_val;
      switch (image.type) {
      case type_enum.INT8:
        min_val = -(1 << 7);
        max_val = (1 << 7) - 1;
        break;
      case type_enum.UINT8:
        min_val = 0;
        max_val = (1 << 8) - 1;
        break;
      case type_enum.INT16:
        min_val = -(1 << 15);
        max_val = (1 << 15) - 1;
        break;
      case type_enum.UINT16:
        min_val = 0;
        max_val = (1 << 16) - 1;
        break;
      case type_enum.INT32:
        min_val = -(1 << 31);
        max_val = (1 << 31) - 1;
        break;
      case type_enum.UINT32:
        min_val = 0;
        max_val = (1 << 32) - 1;
        break;
      }
      valid_range = Float32Array.of(min_val, max_val);
    }


    var image_min = findDataset(root, "image-min");
    if (!defined(image_min)) {
      image_min = {
        array: Float32Array.of(0),
        dims: []
      };
    }

    var image_max = findDataset(root, "image-max");
    if (!defined(image_max)) {
      image_max = {
        array: Float32Array.of(1),
        dims: []
      };
    }


    /* Create the header expected by the existing brainbrowser code.
     */
    var header = {};
    var tmp = findAttribute(image, "dimorder", 0);
    if (typeof tmp !== 'string') {
      throw new Error("Can't find dimension order.");
    }
    header.order = tmp.split(',');

    header.order.forEach(function(dimname) {
      var dim = findDataset(root, dimname);
      if (!defined(dim)) {
        throw new Error("Can't find dimension variable " + dimname);
      }

      header[dimname] = {};

      tmp = findAttribute(dim, "step", 0);
      if (!defined(tmp)) {
        tmp = Float32Array.of(1);
      }
      header[dimname].step = tmp[0];

      tmp = findAttribute(dim, "start", 0);
      if (!defined(tmp)) {
        tmp = Float32Array.of(0);
      }
      header[dimname].start = tmp[0];

      tmp = findAttribute(dim, "length", 0);
      if (!defined(tmp)) {
        throw new Error("Can't find length for " + dimname);
      }
      header[dimname].space_length = tmp[0];

      tmp = findAttribute(dim, "direction_cosines", 0);
      if (defined(tmp)) {
        // why is the bizarre call to slice needed?? it seems to work, though!
        header[dimname].direction_cosines = Array.prototype.slice.call(tmp);
      }
      else {
        if (dimname === "xspace") {
          header[dimname].direction_cosines = [1, 0, 0];
        } else if (dimname === "yspace") {
          header[dimname].direction_cosines = [0, 1, 0];
        } else if (dimname === "zspace") {
          header[dimname].direction_cosines = [0, 0, 1];
        }
      }
    });

    var new_abuf;

    if (isRgbVolume(header, image)) {
      header.order.pop();
      header.datatype = 'rgb8';
      new_abuf = rgbVoxels(image);
    }
    else {

      //header.datatype = 'float32';
      header.datatype = getTypeMatchMinc(image.type)

      new_abuf = scaleVoxels(image, image_min, image_max, valid_range, debug);
    }

    return { header_text: JSON.stringify(header),
             raw_data: new_abuf};
  };
