/*
  Author: Jonathan Lurie
  Institution: McGill University, Montreal Neurological Institute - MCIN
  Date: started on Jully 2016
  email: lurie.jo@gmail.com
  License: MIT
*/

/*
  simple verification from casio website: http://bit.ly/29LMfQ9
*/
var Plane = function(){
  // the plane equation is:
  // ax + by + cz + d = 0
  // here are those coeficents:
  this._a = null;
  this._b = null;
  this._c = null;
  this._d = null;

  this._n = null;   // the normal vector to the plane
  this._u = null;   // one of the vector that belong to the plane
  this._v = null;   // another vector that belong to the plane, orthogonal to _u
  this._p = null;   // When the plane is defined with a point and a normal vector, this is the point

  this._vecTools = new VectorTools();    // some (simple) tool to perform vector calculus
}


/*
  initialize the equation of the plane from 3 points
  each point is a Array [x, y, z]
*/
Plane.prototype.makeFromThreePoints = function(P, Q, R){
  // vector from P to Q
  var vPQ = [Q[0] - P[0], Q[1] - P[1], Q[2] - P[2]];
  var vPR = [R[0] - P[0], R[1] - P[1], R[2] - P[2]];

  this._n = this._vecTools.crossProduct(vPQ, vPR, false);

  this._a = this._n[0];
  this._b = this._n[1];
  this._c = this._n[2];
  this._d = (-1) * (this._a * P[0] + this._b * P[1] + this._c * P[2] );

  this._defineUandVwith2points(P, Q);

}


/*
  TODO: not really achieved because not very useful (is that event a good reason?)
  Initialize the plane directly using the equation
*/
Plane.prototype.makeFromEquation = function(a, b, c, d){
  this._a = a;
  this._b = b;
  this._c = c;
  this._d = d;

  // TODO define u and v
}


/*
  initialize the equation of the plane from 1 point and a vector.
  The point does not have to be within the cube.
  point and vector are both tuple (x, y, z)
*/
Plane.prototype.makeFromOnePointAndNormalVector = function(point, vector){
    this._p = point;
    this._n = vector;
    this._a = this._n[0];
    this._b = this._n[1];
    this._c = this._n[2];
    this._d = (-1) * (this._a * point[0] + this._b * point[1] + this._c * point[2] );

    // find another point on the plane...

    // The next 3 cases are for when a plane is (at least in 1D)
    // aligned with the referential
    var point2 = null;

    // case 1
    if(this._c != 0){
      //console.log("case1");
      var x2 = point[0];
      var y2 = point[1] - 1;
      var z2 = (-1) * ( (this._a * x2 + this._b * y2 + this._d) / this._c );
      point2 = [x2, y2, z2];
    }

    // case 2
    if(this._b != 0 && !point2){
      //console.log("case2");
      var x2 = point[0];
      var z2 = point[2] + 1;
      var y2 = (-1) * ( (this._a * x2 + this._c * z2 + this._d) / this._b );
      point2 = [x2, y2, z2];
    }

    // case 3
    if(this._a != 0 && !point2){
      //console.log("case3");
      var y2 = point[1];
      var z2 = point[2] + 1;
      var x2 =  (-1) * ( (this._b * y2 + this._c * z2 + this._d) / this._a );
      point2 = [x2, y2, z2];
    }

    this._defineUandVwith2points(point, point2);
}


/*
  return the abcd factors of the plane equation as a tuple
  assuming ax + by + cz + d = 0
*/
Plane.prototype.getPlaneEquation = function(){
  return [this._a, this._b, this._c, this._d];
}


/*
  return tuple with normal the vector
*/
Plane.prototype.getNormalVector = function(){
  return this._n.slice();
}


/*
  return tuple with the point from the vector
*/
Plane.prototype.getPoint = function(){
  return this._p.slice();
}


/*
  u and v are two vectors frome this plane.
  they are orthogonal and normalize so that we can build a regular grid
  along this plane.
  BEWARE: the equation and normal to the plane must be set
  Some calculus hints come from there: http://bit.ly/29coWgs .
  args: P and Q are two points from the plane. vPQ, when normalized
  will be used as u
*/
Plane.prototype._defineUandVwith2points = function(P, Q){
  this._u = this._vecTools.normalize([
      Q[0] - P[0],
      Q[1] - P[1],
      Q[2] - P[2]
    ]);

  this._v = this._vecTools.crossProduct(this._u, this._n, true);
}


/*
  return the unit vector u as a tuple (x, y, z)
*/
Plane.prototype.getUvector = function(){
  return this._u;
}


/*
  return the unit vector v as a tuple (x, y, z)
*/
Plane.prototype.getVvector = function(){
  return this._v;
}


/*
  copy all the data from otherPlane to _this_ one,
  except this._vecTools (which does not matter).
*/
Plane.prototype.copy = function(otherPlane){
  // numbers
  this._a = otherPlane._a;
  this._b = otherPlane._b;
  this._c = otherPlane._c;
  this._d = otherPlane._d;

  // arrays
  this._n = otherPlane._n.slice();
  this._u = otherPlane._u.slice();
  this._v = otherPlane._v.slice();
  this._p = otherPlane._p.slice();
}



/*
  Initialize _this_ plane as an orthogonal plane of the one in args.
  The normal of _this_ plane is the u unit vector of _plane_.
  Args:
    plane: Plane instance - a valid and constructed plane
*/
Plane.prototype.buildOrthoU = function(plane){
  this.makeFromOnePointAndNormalVector(
    plane.getPoint(),
    plane.getUvector().slice()
  );
}


/*
  Initialize _this_ plane as an orthogonal plane of the one in args.
  The normal of _this_ plane is the v unit vector of _plane_.
  Args:
    plane: Plane instance - a valid and constructed plane
*/
Plane.prototype.buildOrthoV = function(plane){
  this.makeFromOnePointAndNormalVector(
    plane.getPoint(),
    plane.getVvector().slice()
  );
}






function testPlane(){
  var p = new Plane();
  //p.makeFromThreePoints( [1, -2, 0], [3, 1, 4], [0, -1, 2]);
  //p.makeFromThreePoints( [1, -2, 0], [3, 10, 4], [0, -1, 2])
  p.makeFromThreePoints( [0, 0, 0], [1, 0, 0], [0, 1, 1]);
  console.log(p.getPlaneEquation() );
}

//testPlane();
