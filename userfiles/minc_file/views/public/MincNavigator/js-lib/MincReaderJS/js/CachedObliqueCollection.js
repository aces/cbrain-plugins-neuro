/*
  Author: Jonathan Lurie
  Institution: McGill University, Montreal Neurological Institute - MCIN
  Date: started on Jully 2016
  email: lurie.jo@gmail.com
  License: MIT
*/

var CachedObliqueCollection = function(){
  this._collection = [];
}


/*
  Add an object of type CachedOblique to the collection
*/
CachedObliqueCollection.prototype.addOblique = function(o){
  // TODO: add a typeof verification
  this._collection.push(o);
}


/*
  Return the number of cached oblique currently available in the collection
*/
CachedObliqueCollection.prototype.getNumberOfObliques = function(){
  return this._collection.length;
}


/*
  Makes a list of the obliques currently in the collection
*/
CachedObliqueCollection.prototype.getObliqueNameList = function(){
  var names = new Array(this._collection.length);

  for(i=0; i<names.length; i++){
    names[i] = this._collection[i].getName();
  }

  return names;
}


/*
  Return the nth cached oblique.
*/
CachedObliqueCollection.prototype.getOblique = function(n){
  if(n>=0 && n<this._collection.length){
    return this._collection[n];
  }else{
    console.log("ERROR: this oblique is out of range.");
    return null;
  }
}
