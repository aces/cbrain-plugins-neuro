/*
  Author: Jonathan Lurie
  Institution: McGill University, Montreal Neurological Institute - MCIN
  Date: started on Jully 2016
  email: lurie.jo@gmail.com
  License: MIT
*/

var VectorTools = function(){


}

/*
  performs a cross product between v1 and v2.
  args:
    v1: Array[3] - vector #1
    v2: Array[3] - vector #2
    normalize: boolean - normalize the output vector when true

  return:
    Array[3] - the vctor result of the cross product
*/
VectorTools.prototype.crossProduct = function(v1, v2, normalize){

  normalVector = [
      v1[1] * v2[2] - v1[2] * v2[1],
      (v1[0] * v2[2] - v1[2] * v2[0] ) * (-1),
      v1[0] * v2[1] - v1[1] * v2[0]
  ];

  if(normalize)
      normalVector = this.normalize(normalVector);

  return normalVector;
}


/*
  compute the dot product between v1 and v2.
  Note: v1 and v2 must be normalize so that the dot product is also
  the cosine of the angle between v1 and v2.
*/
VectorTools.prototype.dotProduct = function(v1, v2){
  if(v1.length != v2.length){
    console.log("ERROR: v1 and v2 must be the same size to compute a dot product");
    return null;
  }

  var sum = 0;

  for(var i=0; i<v1.length; i++){
    sum += (v1[i]*v2[i]);
  }

  return sum;

}


/*
  Return a normalized vector from v (does not replace v).
  args:
    v: Array[3] - vector to normalize

  return:
    Array[3] - a normalized vector
*/
VectorTools.prototype.normalize = function(v){
  var n = this.getNorm(v);
  var normalizedV = [v[0]/n, v[1]/n, v[2]/n];
  return normalizedV;
}


/*
  return the norm (length) of a vector [x, y, z]
*/
VectorTools.prototype.getNorm = function(v){
  return Math.sqrt(v[0]*v[0] + v[1]*v[1] + v[2]*v[2]);
}


/*
  Build a 3-member system for each x, y and z so that we can
  make some calculus about a 3D affine line into a 3D space.
  x = l + alpha * t
  y = m + beta * t
  z = n + gamma * t
  (the parametric variable is t)
  returns a tuple of tuple:
  ( (l, alpha), (m, beta), (n, gamma) )
*/
VectorTools.prototype.affine3DFromVectorAndPoint = function(V, point){
  var xTuple = [point[0] , V[0]];
  var yTuple = [point[1] , V[1]];
  var zTuple = [point[2] , V[2]];

  return [xTuple, yTuple, zTuple];

}



/*
  rotate the vector v using the rotation matrix m.
  Args:
    v: array - [x, y, z]
    m: array[array] -
        [[a, b, c],
         [d, e, f],
         [g, h, i]]

  Return rotated vector:
    [ax + by + cz,
     dx + ey + fz,
     gx + hy + iz]
*/
VectorTools.prototype.rotate = function(v, m){
  var vRot = [
    v[0]*m[0][0] + v[1]*m[0][1] + v[2]*m[0][2],
    v[0]*m[1][0] + v[1]*m[1][1] + v[2]*m[1][2],
    v[0]*m[2][0] + v[1]*m[2][1] + v[2]*m[2][2],
  ];

  console.log("HELLo");

  return vRot;
}


/*
  compute the angle p1p2p3 in radians.
  Does not give the sign, just absolute angle!
  args:
    p1, p2, p3: array [x, y, z] - 3D coordinate of each point
*/
VectorTools.prototype.getAnglePoints = function(p1, p2, p3){

  //  the configuration is somthing like that:
  //
  //  p1-----p2
  //        /
  //       /
  //      p3

  var v_p2p1 = [
    p1[0] - p2[0],
    p1[1] - p2[1],
    p1[2] - p2[2],
  ];

  var v_p2p3 = [
    p3[0] - p2[0],
    p3[1] - p2[1],
    p3[2] - p2[2],
  ];

  // normalizing those vectors
  v_p2p1 = this.normalize(v_p2p1);
  v_p2p3 = this.normalize(v_p2p3);

  var cosine = this.dotProduct(v_p2p1, v_p2p3);
  var angleRad = Math.acos(cosine);

  return angleRad;

}

// export as a module in case of use with nodejs
if(typeof module !== 'undefined' && typeof module.exports !== 'undefined')
  module.exports = VectorTools;
