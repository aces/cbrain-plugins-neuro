window.addEventListener('load', function(){
  console.warn = function() {};

  var url      = null;
  let threedeediv = document.getElementById('threedeediv')
  let options = {
    webgl2: true,            // enable WebGL2 if `true` (default: false)
    embedLight: false,       // embeds the light into the camera if true (default: false)
    antialias: false,        // enables antialias if true (default: true)
    showAxisHelper: true,    // shows the axis helper at (0, 0, 0) when true (default: false)
    axisHelperSize: 3,       // length of the the 3 axes of the helper (default: 100)
    controlType: 'orbit',    // 'orbit': locked poles or 'trackball': free rotations (default: 'trackball')
    cameraPosition: {x: 0, y:0, z: 10}, // inits position of the camera (default: {x: 0, y: 0, z: 100})
    cameraLookAt: {x: 0, y: 0, z: 0},   // inits position to look at (default: {x: 0, y: 0, z: 0})
    raycastOnDoubleClick: true,         // performs a raycast when double clicking (default: `true`).
                                        // If some object from the scene are raycasted, the event 'onRaycast'
                                        // is emitted with the list of intersected object from the scene as argument.
  }
    
  // local storage is available
  if (typeof(Storage) !== "undefined") {
    var localStorageKey = "plyUrl";
    url = localStorage.getItem( localStorageKey );

    if( url ){
      // remove the key so that the user could use another instance of MincNavigator
      localStorage.removeItem(localStorageKey);
    }else{
      console.log("the key '" + localStorageKey + "' does not exist in LocalStorage.");
    }

  // local storage NOT available
  } else {
    console.log("LocalStorage is not available on your Browser.");
  }

  if( !url ){
    return;
  }

  var xmlhttp = new XMLHttpRequest(),
  method = 'GET',
  url = url;
  xmlhttp.responseType = "arraybuffer";

  xmlhttp.open(method, url, true);
  
  let tc          = new threecontext(threedeediv, options)
  xmlhttp.onload = function () {
    var arrayBuffer = xmlhttp.response;

    if (!arrayBuffer) {
      console.log("Not able to get arrayBuffer information from " + url + " for plyLoader");
      return;
    };

    tc.plyLoader(arrayBuffer);
  }

  xmlhttp.send();
});