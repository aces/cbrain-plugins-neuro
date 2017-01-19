/*
  Author: Jonathan Lurie
  Institution: McGill University, Montreal Neurological Institute - MCIN
  Date: started on Jully 2016
  email: lurie.jo2gmail.com
  License: MIT

  VolumeNavigator is originally a (fancy) widget for MincNavigator.
*/

/*
  Constuctor.

  Args:
    outerBoxOptions: Object - size specification of the volume (mandatory)
    innerBoxOptions: Object - size of an inner box, can be null
    divID: String - DOM ID of the div to display the volume
    gui: bool - true, displau a gui using dat.gui
*/
var VolumeNavigator = function(outerBoxOptions, innerBoxOptions, divID, gui){
  this.displayGui = gui;
  this.raycaster = new THREE.Raycaster();
  this.raycaster.linePrecision = 5;
  this.mouse = new THREE.Vector2();

  // relate to grabbing an object (circle helper or arrow)
  this.objectGrabed = {
    shift: false,
    isGrabed: false,
    currentGrabPosition: new THREE.Vector3(),
    axis: [0, 0, 0], // each is a factor so should be 0 or 1
    translationOrRotation: 0, // 0:tranlation 1:rotation
    previousMouse: new THREE.Vector2()
  };

  this.outerBoxSize = outerBoxOptions;
  this.innerBoxSize = innerBoxOptions;

  this.domContainer = document.getElementById(divID);

  this.boxDiagonal = Math.sqrt(this.outerBoxSize.xSize * this.outerBoxSize.xSize +
      this.outerBoxSize.ySize * this.outerBoxSize.ySize +
      this.outerBoxSize.zSize * this.outerBoxSize.zSize);

  this.sceneOptions = {
      width: this.domContainer.clientWidth,
      height: this.domContainer.clientHeight,
      viewAngle: 45,
      near: 0.1,
      far: this.boxDiagonal * 20,
  };

  // plane equation as (ax + by + cz + d = 0)
  this.planeEquation = {
      a: 0,
      b: 0,
      c: 0,
      d: 0
  }

  this.originalQuaternion = null;
  this.savedGimbalSettings = {};

  // array of intersection points between the plane and the volume
  this.planePolygon = null;

  // array triangles
  this.polygonTriangles = null;

  // array of object (material, geometry, mesh).
  // Used to symbolize the intersections between the plane and the volume
  this.intersectionSpheres = [];

  // callback when a slider is moved (still mouse down)
  this.onChangeCallback = null;

  // callback when a slider has finished to slide (mouse up)
  this.onFinishChangeCallback = null;


  // all the callbacks with their event names
  this.callbacks = {
    onOrbitingX: null,  // when grabing the red circle while mouseMove
    onOrbitedX: null,   // when done orbiting on the red circle
    onOrbitingY: null,  // when grabing the green circle while mouseMove
    onOrbitedY: null,   // when done orbiting on the green circle
    onOrbitingZ: null,   // when grabing the blue circle while mouseMove
    onOrbitedZ: null,   // when done orbiting on the blue circle

    onMovingAlongNormal: null,
    onMovedAlongNormal: null,
    onMovingAlongOrthoU: null,
    onMovedAlongOrthoU: null,
    onMovingAlongOrthoV: null,
    onMovedAlongOrthoV: null
  }

  // manage the history of gimbal settings (this is actually a stack)
  this.gimbalSettingHistory = [];
  this.historyIterator = 0

  // temporary array of callbacks to call while moving the mouse
  // To be cleaned at mouseup
  this.movingCallbacks = [];
  // temporary array of callback to call at mouseUp.
  // To be cleaned at mouseup
  this.movedCallbacks = [];

  // the main object for dealing with translation and rotation
  this.gimbal= null;

  // Array containg each edge (12) equation in space
  this.cubeEdges = this._getEdgesEquations();

  this.vectorTools = new VectorTools();

  // initialize THREE js elements necessary to create and render a scene
  this.init();

  // build the box context
  this.buildInnerBox();
  this.buildOuterBox();
  this.initPolygonTriangles();

  // create the gimbal
  this.initGimbal();

  // init click and keyboard events
  this.initKeyEvents();

  this.setupLighting();

  // initialize the UI (dat.gui)
  if(this.displayGui)
    this.initGui();

  // just toi nitialize in order to update dat.gui field
  this.update();

  // animate and update
  this.animate();
}


/*
  Initialize the mouse and keyboard windows event
*/
VolumeNavigator.prototype.initKeyEvents = function(){
  window.addEventListener( 'mousedown', this.onMouseDown.bind(this), false );
  window.addEventListener( 'mouseup', this.onMouseUp.bind(this), false );
  window.addEventListener( 'mousemove', this.onMouseMove.bind(this), false );
  window.addEventListener( 'keyup', this.onKeyUp.bind(this), false );
  window.addEventListener( 'keydown', this.onKeyDown.bind(this), false );
  window.addEventListener( 'resize', this.onWindowResize.bind(this), false );
}


/*
  Keepd the proportion of the window when the window is resized.
*/
VolumeNavigator.prototype.onWindowResize = function(){
  this.sceneOptions.width = this.domContainer.clientWidth;
  this.sceneOptions.height = this.domContainer.clientHeight;
  this.camera.aspect = this.sceneOptions.width / this.sceneOptions.height;
  this.camera.updateProjectionMatrix();
  this.renderer.setSize( this.sceneOptions.width, this.sceneOptions.height );
}


/*
  Defines the callback for a situation.
  Args:
    cbName: string - name of the callback, must match children of this.callbacks
    cb: a function to call depending on the situation
*/
VolumeNavigator.prototype.setCallback = function(cbName, cb){
  var keys = Object.keys(this.callbacks);

  // Quit if a wrong callback is given
  if(keys.indexOf(cbName) == -1){
    console.warn("The givent callback (" + cbName + ") is not valid.");
    return;
  }

  this.callbacks[cbName] = cb;
}


/*
  call a callback from its given name. Just handles its existance.
*/
VolumeNavigator.prototype.callCallback = function(cbName){
  if(this.callbacks[cbName])
    this.callbacks[cbName]();
}


/*
  Call all the callback in the preview list
*/
VolumeNavigator.prototype.callAllMovingCallbacks = function(){

  this.movingCallbacks.forEach(function(elem){
    this.callCallback(elem);

  }, this);

}


/*
  Call all the callback in the moved list
*/
VolumeNavigator.prototype.callAllMovedCallbacks = function(){
  this.movedCallbacks.forEach(function(elem){
    this.callCallback(elem);

  }, this);
}


/*
  Adds a callback to the list by using its name.
  Perform a verification so that a callback is not added twice.
*/
VolumeNavigator.prototype.addMovedCallbacks = function(cbName){
  // adding cb to the list only if it does not exist
  if(this.movedCallbacks.indexOf(cbName) == -1 ){
    this.movedCallbacks.push(cbName);
  }
}


/*
  Adds a callback to the list by using its name.
  Perform a verification so that a callback is not added twice.
*/
VolumeNavigator.prototype.addMovingCallbacks = function(cbName){
  // adding cb to the list only if it does not exist
  if(this.movingCallbacks.indexOf(cbName) == -1 ){
    this.movingCallbacks.push(cbName);
  }
}


/*
  Keyboard event (DOWN)
  Note: regular chars (letter, num...) are repeated but
  special keys (shift, ctrl...) are not.
*/
VolumeNavigator.prototype.onKeyDown = function(event){
  if(event.keyCode != 16)
    return;

  // keep the switch for later, if we want more keys
  switch ( event.keyCode ) {
    // shift
    case 16:
      event.preventDefault();
      event.stopPropagation();

      this.objectGrabed.shift = true;
      break;

    default:
  }

}


/*
  Keyboard events (UP)- The change of keyboard layout should not afect
  the position of the key, since the keycode is used. Though, the letters
  mentionned in comment are the ones on a US/QWERTY keyboard.
*/
VolumeNavigator.prototype.onKeyUp = function(event){
  /*
  // To avoid multiple strike at one (part 1)
  if(typeof this.lastKeyupTimestamp === 'undefined'){
    this.lastKeyupTimestamp = 0;
  }

  // we dont consider event that are to fast (prevent keyup from being triggerd twice)
  if(event.timeStamp - this.lastKeyupTimestamp < 100){
    return;
  }
  */
  console.log("up: " + event.keyCode);

  switch ( event.keyCode ) {
    // shift
    case 16:
      event.preventDefault();
      event.stopPropagation();
      this.objectGrabed.shift = false;
      break;

    /*
    // space bar
    case 32:
      event.preventDefault();
      event.stopPropagation();
      this.AxisArrowHelperToggle();
      break;

    // char "u", tilt the gimbal over u unit vector
    case 85:
      event.preventDefault();
      event.stopPropagation();
      this.tiltGimbalU();
      break;

    // char "v", tilt the gimbal over u unit vector
    case 86:
      event.preventDefault();
      event.stopPropagation();
      this.tiltGimbalV();
      break;

    // char 'Q', move forward along normal vector
    case 81:
      event.preventDefault();
      event.stopPropagation();
      this.moveAlongNormal( this.objectGrabed.shift? 10 : 1 );
      break;

    // char 'A', move backward along normal vector
    case 65:
      event.preventDefault();
      event.stopPropagation();
      this.moveAlongNormal( this.objectGrabed.shift? -10 : -1 );
      break;


    // char 'W', move forward along U ortho vector
    case 87:
      event.preventDefault();
      event.stopPropagation();
      this.moveAlongOrthoU( this.objectGrabed.shift? 10 : 1 );
      break;

    // char 'S', move backward along U ortho vector
    case 83:
      event.preventDefault();
      event.stopPropagation();
      this.moveAlongOrthoU( this.objectGrabed.shift? -10 : -1 );
      break;

    // char 'E', move forward along V ortho  vector
    case 69:
      event.preventDefault();
      event.stopPropagation();
      this.moveAlongOrthoV( this.objectGrabed.shift? 10 : 1 );
      break;

    // char 'D', move backward along V ortho vector
    case 68:
      event.preventDefault();
      event.stopPropagation();
      this.moveAlongOrthoV( this.objectGrabed.shift? -10 : -1 );
      break;
    */
    default:
  }

  // To avoid multiple strike at one (part 2)
  //this.lastKeyupTimestamp = event.timeStamp;
}


/*
  The callback cb will be called when a slider from is moving
*/
VolumeNavigator.prototype.setOnChangeCallback = function(cb){
  this.onChangeCallback = cb;
}




/*
  The callback cb will be called when a slider from is done moving
*/
VolumeNavigator.prototype.setOnFinishChangeCallback = function(cb){
  this.onFinishChangeCallback = cb;
}


/*
    Create and initialize all the necessary to build a THREE scene
*/
VolumeNavigator.prototype.init = function(){
    // THREE.JS rendered
    this.renderer = new THREE.WebGLRenderer({
        antialias: true,
        alpha: true
    });

    // THREE.JS camera
    this.camera = new THREE.PerspectiveCamera(
        this.sceneOptions.viewAngle,
        this.sceneOptions.width / this.sceneOptions.height,
        this.sceneOptions.near,
        this.sceneOptions.far
    );

    // THREE.JS orbit controls
    this.controls = new THREE.OrbitControls( this.camera, this.renderer.domElement );
    this.controls.target.fromArray([this.outerBoxSize.xSize / 2, this.outerBoxSize.ySize / 2, this.outerBoxSize.zSize / 2])

    // THREE.JS scene
    this.scene = new THREE.Scene();

    // add the camera to the scene
    this.scene.add(this.camera);

    // the camera starts at 0,0,0
    // so pull it back, in a more comfortable position
    this.camera.position.z = this.boxDiagonal * 1.5;
    this.camera.position.y = this.boxDiagonal;
    this.camera.position.x = -this.boxDiagonal;

    // start the renderer
    this.renderer.setSize(this.sceneOptions.width, this.sceneOptions.height);

    // attach the render-supplied DOM element
    this.domContainer.appendChild(this.renderer.domElement);

    // add axis
    var axisHelper = new THREE.AxisHelper( this.boxDiagonal / 4 );
    this.scene.add( axisHelper );
}


/*
    Build the inner box (aka. brain within minc) ans displays it on the scene
*/
VolumeNavigator.prototype.buildInnerBox = function(){
  this.innerBox = {};

  // when null init the inner box as an "outerBox" helper
  if(!this.innerBoxSize){
    this.innerBoxSize = {
      xSize: this.outerBoxSize.xSize - 2,
      ySize: this.outerBoxSize.ySize - 2,
      zSize: this.outerBoxSize.zSize - 2,
      xOrigin: 1,
      yOrigin: 1,
      zOrigin: 1
    }
  }

  this.innerBox.material = new THREE.MeshBasicMaterial({
      color: 0x7E2FB4,
      wireframe: true,

  });

  // geometry
  this.innerBox.geometry = new THREE.CubeGeometry(
      this.innerBoxSize.xSize,
      this.innerBoxSize.ySize,
      this.innerBoxSize.zSize
  );

  // the corner of the box is at the origin
  this.innerBox.geometry.translate(
      this.innerBoxSize.xSize / 2 + this.innerBoxSize.xOrigin,
      this.innerBoxSize.ySize / 2 + this.innerBoxSize.yOrigin,
      this.innerBoxSize.zSize / 2 + this.innerBoxSize.zOrigin
  );

  this.innerBox.mesh = new THREE.Mesh( this.innerBox.geometry, this.innerBox.material )

  // adding the wireframe provide better understanding of the scene
  this.innerBox.helper = new THREE.EdgesHelper( this.innerBox.mesh, 0xDAB0F7 );
  this.scene.add( this.innerBox.helper );

}


/*
    Build the outer box, with only inner faces visible
*/
VolumeNavigator.prototype.buildOuterBox = function(){

    this.outerBox = {};

    // material
    this.outerBox.material = new THREE.MeshLambertMaterial( {
        transparent: true,
        opacity: 0.8,
        color: 0xc489ed,
        emissive: 0x000000,
        depthWrite: true,
        depthTest: true,
        side: THREE.BackSide
    });

    // geometry
    this.outerBox.geometry = new THREE.CubeGeometry(
        this.outerBoxSize.xSize,
        this.outerBoxSize.ySize,
        this.outerBoxSize.zSize
    );

    // the corner of the box is at the origin
    this.outerBox.geometry.translate(
        this.outerBoxSize.xSize / 2,
        this.outerBoxSize.ySize / 2,
        this.outerBoxSize.zSize /2
    );

    // add the outer box to the scene
    this.scene.add( new THREE.Mesh( this.outerBox.geometry, this.outerBox.material ) );
}



/*
    seting up both lights, ambient and point
*/
VolumeNavigator.prototype.setupLighting = function(){

    var ambientLight = new THREE.AmbientLight( 0xFFFFFF );
    this.scene.add( ambientLight );

    // create a point light
    var pointLight = new THREE.PointLight(0xFFFFFF);

    // set its position
    pointLight.position.x = this.boxDiagonal * 10;
    pointLight.position.y = this.boxDiagonal * 10;
    pointLight.position.z = this.boxDiagonal * 10;

    // add to the scene
    this.scene.add(pointLight);
}


/*
    Render the scene
*/
VolumeNavigator.prototype.render = function(){
  this.controls.update();
  this.renderer.render(this.scene, this.camera);
}


/*
    animate the scene
*/
VolumeNavigator.prototype.animate = function(){
    requestAnimationFrame(this.animate.bind(this));
    this.render();
}


/*
    Adds the settings available in dat.gui
*/
VolumeNavigator.prototype.initGui = function(){
  this.gui = new dat.GUI({ width: 400 });
  this.guiValue = {};

  this.guiValue.literalPlaneEquation = {
      literal: ""
  }

  this.guiValue.normalVector = {
      literal: ""
  }

  this.guiValue.point = {
      literal: ""
  }

  // used later but better to declare here to avoid resetting
  this.guiValue.customButton = {};
  this.guiValue.customList = {};

  var planeInfoFolder = this.gui.addFolder('Plane information');
  planeInfoFolder.add(this.guiValue.literalPlaneEquation, 'literal').name("Plane equation").listen();
  planeInfoFolder.add(this.guiValue.normalVector, 'literal').name("Normal vector").listen();
  planeInfoFolder.add(this.guiValue.point, 'literal').name("Point").listen();


  // additionnal buttons
  this.buildGuiButton("Toggle controls", this.AxisArrowHelperToggle.bind(this));
  this.buildGuiButton("Tilt gimbal U", this.tiltGimbalU.bind(this));
  this.buildGuiButton("Tilt gimbal V", this.tiltGimbalV.bind(this));
  this.buildGuiButton("Center the gimbal", this.placeGimbalAtPolygonCenter.bind(this));
  this.buildGuiButton("Restore position", this.restoreOriginalGimbalSettings.bind(this));
  this.buildGuiButton("Undo", this.undo.bind(this));
  this.buildGuiButton("Redo", this.redo.bind(this));

}


/*
  Add a button with its callback - generic, add as many bt as we want
*/
VolumeNavigator.prototype.buildGuiButton = function(name, callback){
  this.guiValue.customButton[name] = name;
  this.guiValue.customButton[name + "callback"] = callback;

  this.gui.add(this.guiValue.customButton, name + "callback").name(this.guiValue.customButton[name]);
}


/*
  Build the list of choice with a callback.
  args:
    listName: string - the name that will be displayed
    list: Array or Object (map) - the choices
    callback: function - function to call when a choice is done. It takes the value as argument.
*/
VolumeNavigator.prototype.buildGuiList = function(listName, list, callback){
  /*
  TODO: now listName is like that
  {
    "name0": 0,
    "name1": 1,
    "name2": 2,
    "name3": 3, ...
  }

  but this should be just a list [] at its equivalent map should be built here
  */

  var mapOfNames = {};
  for(i=0; i<list.length; i++){
    mapOfNames[list[i]] = i;
  }


  if(! (typeof this.guiValue.customList["controller"] === "undefined") ){
    // remove the current elem
    this.gui.remove(this.guiValue.customList["controller"]);
    this.guiValue.customList = {};
  }

  this.guiValue.customList["mapOfNames"] = mapOfNames;
  this.guiValue.customList["listName"] = listName;
  this.guiValue.customList["callback"] = callback;

  this.guiValue.customList["controller"] = this.gui.add(
    this.guiValue.customList,
    "listName",
    this.guiValue.customList["mapOfNames"]
  )
  .name(this.guiValue.customList["listName"]) // necessay, I think there is a bug in using the name
  .onFinishChange(callback);

}


/*
  called when a slider is moved.
  Update few things: equation, normal, point, hitpoint
*/
VolumeNavigator.prototype.update = function(){

  // update values related to plane equation, normal vector and plane point
  this.updatePlaneEquation();

  // compute the intersection points (aka. the intersection polygon)
  this.computeCubePlaneHitPoints();

  // Reorder the intersection polygon point cw to draw it easily
  this._orderPolygonPoints();

  // draw the intersection polygon
  this.updatePolygonTriangles();

  // draw a sphere at each vertex of the intersection polygon
  this.updateHitPointSpheres();

  // updqte the dat.gui display
  if(this.displayGui){
    this.updateGui();
  }

}


/*
    Updates the plane equation, based on three points of the plane
*/
VolumeNavigator.prototype.updatePlaneEquation = function(){

  var n = this.getPlaneNormal();
  var p = this.getPlanePoint();

  var eq = new THREE.Vector4(
      n[0],
      n[1],
      n[2],
      (-1) * (n[0]*p[0] + n[1]*p[1] + n[2]*p[2])
  );

  var roundFactor = 10000;
  this.planeEquation.a = Math.round(eq.x * roundFactor) / roundFactor;
  this.planeEquation.b = Math.round(eq.y * roundFactor) / roundFactor;
  this.planeEquation.c = Math.round(eq.z * roundFactor) / roundFactor;
  this.planeEquation.d = Math.round(eq.w * roundFactor) / roundFactor;

}


/*
  Update the display of the gui
*/
VolumeNavigator.prototype.updateGui = function(){
  var n = this.getPlaneNormal();
  var p = this.getPlanePoint();
  var roundFactor = 10000;

  // create a nice-to-display equation
  this.guiValue.literalPlaneEquation.literal =
      this.planeEquation.a + "x + " +
      this.planeEquation.b + "y + " +
      this.planeEquation.c + "z + " +
      this.planeEquation.d + " = 0";

  // Display/refresh the plane normal and the point

  var normalRounded = {
    x: Math.round(n[0] * roundFactor) / roundFactor,
    y: Math.round(n[1] * roundFactor) / roundFactor,
    z: Math.round(n[2] * roundFactor) / roundFactor
  };

  var pointRounded = {
    x: Math.round(p[0] * roundFactor) / roundFactor,
    y: Math.round(p[1] * roundFactor) / roundFactor,
    z: Math.round(p[2] * roundFactor) / roundFactor
  };

  this.guiValue.normalVector.literal = "(" + normalRounded.x + " ; " + normalRounded.y + " ; " + normalRounded.z + ")";

  this.guiValue.point.literal = "(" + pointRounded.x + " ; " + pointRounded.y + " ; " + pointRounded.z + ")";
}


/*
    return the plane equation as (ax + by + cz + d = 0).
*/
VolumeNavigator.prototype.getPlaneEquation = function(){
    return this.planeEquation;
}


/*
  get the normal vector of the plane as a array [x, y, z].
  Note: uses the gimbal normal, but does not return a THREE vector3 object
*/
VolumeNavigator.prototype.getPlaneNormal = function(){
  // we use the normal in z (convention)
  var normal = this.getGimbalNormalVector(2);

  return [normal.x, normal.y, normal.z];
}


/*
  Get the center point of the plane as an array [x, y, z]
*/
VolumeNavigator.prototype.getPlanePoint = function(){
  return this.getGimbalCenter();
}


/*
  Define the center point of the red square (symbolizes a point of the plane).
  Along with setPlaneNormal(), it defines the plane equation.
  Args:
    p: Array [x, y, z] - the absolute position to reach
*/
VolumeNavigator.prototype.setPlanePoint = function(p){

  if(this._isWithin(p)){
    this.setGimbalCenter(p);

    // updating equation and its display on dat.gui
    this.update();

    // call some impacted callback
    this.callThreeMovedAlongCallbacks();
  }else {
    console.log("ERROR: The point requested is not in the volume");
  }
}


/*
  Change the orientation of the gimbal so that the reference normal vector (in Z)
  becomes the _vector_ in argument.
  Note that the center of the gimbal is not changed.
  arg:
    vector: Array [x, y, z] - a normal vector (normalized or not)
*/
VolumeNavigator.prototype.setPlaneNormal = function(vector){

  this.setGimbalReferenceNormal(vector);

  // call some impacted callback
  this.callThreeMovedAlongCallbacks();
}



/*
  All at once! Changing the center and the reference normal vector of the gimbal.
  Note: the center of the gimbal is a point of the plane
  (but not the center of the plane, right? this wouldn't make sense, a plane is infinite!)
  Args:
    normal: Array [x, y, z] - Normal vector, will be transformed into a unit vector
    point: Array [x, y, z] - a point in the space. must be in the boundaries of the volume.
*/
VolumeNavigator.prototype.setPlaneNormalAndPoint = function(normal, point){
  if(this._isWithin(point)){
    this.setGimbalCenter(point);
    this.setGimbalReferenceNormal(normal);

    // updating equation and its display on dat.gui
    this.update();

    this.addToHistory(
      "Setting the normal vector (" +
      normal[0] + ", " +
      normal[1] + ", " +
      normal[2] +
      ") and the reference point ("+
      point[0] + ", " +
      point[1] + ", " +
      point[2] +
      ") to define a new plane (parametric)");

    // call some impacted callback
    this.callThreeMovedAlongCallbacks();
  }else {
    console.log("ERROR: The point requested is not in the volume");
  }
}


/*
  Instead of setting the plane with one point and one normal vector,
  we set it with two points. The first will be used as the center of tthe gimbal,
  and then, as a normal vector, we are using the vector between p1 and p2 (normalized).
  This feature is convenient for performing AC-PC cross section.
  Uses setPlaneNormalAndPoint() under the hood.

  Args:
    p1: Array [x, y, z] - Coords of the first point (AC)
    p2: Array [x, y, z] - Coords of the second point (PC)

  Note: args are arrays instead of THREE.Vector3 because this method is more likely
  to be called from the outside (a controller)
*/
VolumeNavigator.prototype.planeFromTwoPoints = function(p1, p2){
  if(p1 && p2 && p1.length == 3 && p2.length == 3){
    var p1p2 = [
        p2[0] - p1[0],
        p2[1] - p1[1],
        p2[2] - p1[2]
    ];

    var normal = this.vectorTools.normalize(p1p2);
    this.setPlaneNormalAndPoint(normal, p1);

    // adding that to history
    this.addToHistory("Cross section between (" +
      p1[0] + ", " +
      p1[1] + ", " +
      p1[2] + ") and (" +
      p2[0] + ", " +
      p2[1] + ", " +
      p2[2] + ")"
    );


  }
}


/*
  call the callback related to ending the translation of the gimbal in the 3D
*/
VolumeNavigator.prototype.callThreeMovedAlongCallbacks = function(){
  this.callCallback("onMovedAlongNormal");
  this.callCallback("onMovedAlongOrthoU");
  this.callCallback("onMovedAlongOrthoV");
}


/*
  Build the edge equations (12 of them). Helpfull when dealing with hit points.
  (Dont call it at every refresh, they dont change!)
*/
VolumeNavigator.prototype._getEdgesEquations = function(){
  var xLength = this.outerBoxSize.xSize;
  var yLength = this.outerBoxSize.ySize;
  var zLength = this.outerBoxSize.zSize;
  var edgeData = [];

  // 0
  //vector:
  var edge0Vect = [xLength, 0, 0];
  var edge0Point = [0, 0, 0];

  // 1
  // vector:
  var edge1Vect = [0, yLength, 0];
  var edge1Point = [0, 0, 0];

  // 2
  // vector:
  var edge2Vect = [0, 0, zLength];
  var edge2Point = [0, 0, 0];

  // 3
  // vector:
  var edge3Vect = [0, 0, zLength];
  var edge3Point = [xLength, 0, 0];

  // 4
  // vector:
  var edge4Vect = [xLength, 0, 0];
  var edge4Point = [0, 0, zLength];

  // 5
  // vector:
  var edge5Vect = [xLength, 0, 0];
  var edge5Point = [0, yLength, 0];

  // 6
  // vector:
  var edge6Vect = [0, 0, zLength];
  var edge6Point = [0, yLength, 0];

  // 7
  // vector:
  var edge7Vect = [0, 0, zLength];
  var edge7Point = [xLength, yLength, 0];

  // 8
  // vector:
  var edge8Vect = [xLength, 0, 0];
  var edge8Point = [0, yLength, zLength];

  // 9
  // vector:
  var edge9Vect = [0, yLength, 0];
  var edge9Point = [0, 0, zLength];

  // 10
  // vector:
  var edge10Vect = [0, yLength, 0];
  var edge10Point = [xLength, 0, 0];

  // 11
  // vector:
  var edge11Vect = [0, yLength, 0];
  var edge11Point = [xLength, 0, zLength];

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
}


/*
  Hit points are the intersection point between the plane and the volume.
  Here, we decided to sho them so hit points are also hint points.
  They are updated as the plane moves, or at least it's how it looks like,
  they are actually replaced by new ones every time -- Since the number of
  hit point may vary (from 3 to 6), it's easier to create them as we know.
*/
VolumeNavigator.prototype.updateHitPointSpheres = function(){
  // removing the existing spheres from the scene
  for(var s=0; s<this.intersectionSpheres.length; s++){
    this.scene.remove(this.intersectionSpheres[s].mesh);
  }

  // if there is any...
  if(this.planePolygon){

    // reseting the array
    this.intersectionSpheres = [];

    for(var s=0; s<this.planePolygon.length; s++){

      var geometry = new THREE.SphereGeometry( this.boxDiagonal/100, 16, 16 );
      var material = new THREE.MeshBasicMaterial( {color: 0x00ff00} );
      var mesh = new THREE.Mesh( geometry, material );

      var currentSphere = {
        geometry: geometry,
        material: material,
        mesh: mesh
      }

      currentSphere.geometry.translate(
          this.planePolygon[s][0],
          this.planePolygon[s][1],
          this.planePolygon[s][2]
      );

      this.intersectionSpheres.push(currentSphere);
      this.scene.add( currentSphere.mesh );
    }
  }

}


/*
  Build the list of intersection point between the volume and the plane.
  Points stored in this.planePolygon
*/
VolumeNavigator.prototype.computeCubePlaneHitPoints = function(){
  var hitPoints = [];

  for(var i=0; i<this.cubeEdges.length; i++){
    var edge = this.cubeEdges[i];
    var tempHitPoint = this._getHitPoint(edge[0], edge[1]);

    // 1- We dont want to add infinite because it mean an orthogonal edge
    // from this one (still of the cube) will cross the plane in a single
    // point -- and this later case is easier to deal with.
    // 2- Check if hitpoint is within the cube.
    // 3- Avoid multiple occurence for the same hit point
    if( tempHitPoint && // may be null if contains Infinity as x, y or z
        this._isWithin(tempHitPoint))
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
  this.planePolygon = hitPoints.length ? hitPoints : null;

}


/*
  Return true if the given point [x, y, z] is within the volume.
  (or on the edge)
*/
VolumeNavigator.prototype._isWithin = function(point){
  if(point[0] >=0 && point[0] <= this.outerBoxSize.xSize &&
     point[1] >=0 && point[1] <= this.outerBoxSize.ySize &&
     point[2] >=0 && point[2] <= this.outerBoxSize.zSize){

    return true;
  }else{
    return false;
  }
}


/*
  return a point in 3D space (tuple (x, y, z) ).
  vector and point define a "fixed vector" (droite affine)
  both are tuple (x, y, z)
  plane is the plane equation as a tuple (a, b, c, d)
*/
VolumeNavigator.prototype._getHitPoint = function(vector, point){

  // 3D affine system tuple:
  // ( (l, alpha), (m, beta), (n, gamma) )
  var affineSystem = this.vectorTools.affine3DFromVectorAndPoint(vector, point);

  // system resolution for t:
  // t = (a*l + b*m + c*n + d) / ( -1 * (a*alpha + b*beta + c*gamma) )

  var tNumerator = ( this.planeEquation.a* affineSystem[0][0] +
        this.planeEquation.b* affineSystem[1][0] +
        this.planeEquation.c* affineSystem[2][0] +
        this.planeEquation.d );

  var tDenominator = (-1) *
      ( this.planeEquation.a* affineSystem[0][1] +
        this.planeEquation.b* affineSystem[1][1] +
        this.planeEquation.c* affineSystem[2][1] );

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
  takes all the vertices of the intersection polygon and re-order the list so
  that the vertex are ordered cw
  (or ccw, we dont really care as long as it's no longer a mess)
*/
VolumeNavigator.prototype._orderPolygonPoints = function(){

  if(!this.planePolygon){
    return;
  }


  var nbVertice = this.planePolygon.length;
  var center = this.getPolygonCenter();

  // create normalized vectors from center to each vertex of the polygon
  var normalizedRays = [];
  for(var v=0; v<nbVertice; v++){
    var currentRay = [
      center[0] - this.planePolygon[v][0],
      center[1] - this.planePolygon[v][1],
      center[2] - this.planePolygon[v][2]
    ];

    normalizedRays.push(this.vectorTools.normalize(currentRay));
  }

  // for each, we have .vertice (a [x, y, z] array) and .angle (rad angle to planePolygonWithAngles[0])
  var planePolygonWithAngles = [];

  // find the angle of each towards the first vertex
  planePolygonWithAngles.push({vertex: this.planePolygon[0], angle: 0})
  for(var v=1; v<nbVertice; v++){
    var cos = this.vectorTools.dotProduct(normalizedRays[0], normalizedRays[v]);
    var angle = Math.acos(cos);
    var currentPolygonNormal = this.vectorTools.crossProduct(normalizedRays[0], normalizedRays[v], false);
    var planeNormal = this.getPlaneNormal();
    var angleSign = this.vectorTools.dotProduct(currentPolygonNormal, planeNormal)>0? 1:-1;
    angle *= angleSign;

    planePolygonWithAngles.push({vertex: this.planePolygon[v], angle: angle})
  }

  // sort vertices based on their angle to [0]
  planePolygonWithAngles.sort(function(a, b){
    return a.angle - b.angle;
  });

  // make a array of vertex only (ordered)
  var orderedVertice = [];
  for(var v=0; v<nbVertice; v++){
    orderedVertice.push(planePolygonWithAngles[v].vertex);
  }

  // attribute the ordered array to this.planePolygo
  this.planePolygon = orderedVertice;
}


/*
  return the 3D center of the polygon.
  (Note: the polygon is formed by the intersection of the plane and the cube).
  Return: [x, y, z] Array
*/
VolumeNavigator.prototype.getPolygonCenter = function(){
  if(!this.planePolygon)
    return;

  var nbVertice = this.planePolygon.length;

  // find the center of the polygon
  var xAvg = 0;
  var yAvg = 0;
  var zAvg = 0;

  for(var v=0; v<nbVertice; v++){
    xAvg += this.planePolygon[v][0];
    yAvg += this.planePolygon[v][1];
    zAvg += this.planePolygon[v][2];
  }

  xAvg /= nbVertice;
  yAvg /= nbVertice;
  zAvg /= nbVertice;
  var center = [xAvg, yAvg, zAvg];

  return center;
}


/*
  initialize the intersection polygon (made out of triangles)
*/
VolumeNavigator.prototype.initPolygonTriangles = function(){
  this.polygonTriangles = {};
  this.polygonTriangles.geometry = new THREE.Geometry();
  this.polygonTriangles.geometry.dynamic = true;

  this.polygonTriangles.material = new THREE.MeshBasicMaterial( {
    //map: texture, //THREE.ImageUtils.loadTexture('textures/texture-atlas.jpg'),
    side: THREE.DoubleSide,
    color: 0xffffff,
    transparent: true,
    opacity: 0.8
  });

  this.polygonTriangles.mesh = new THREE.Mesh( this.polygonTriangles.geometry, this.polygonTriangles.material );
  this.scene.add( this.polygonTriangles.mesh );
}


/*
  Update the bunch of triangles that shape the intersection polygon.
  Since webGl does not play well with size-changing buffer, it basically
  consist in re-creating all the triangles from scratch...
*/
VolumeNavigator.prototype.updatePolygonTriangles = function(){

  // there is no polygon to display
  if(!this.planePolygon)
    return;

  // there is a polygon intersection to display..

  // remove all existing triangles
  this.polygonTriangles.geometry.faces = [];
  this.polygonTriangles.geometry.vertices = [];

  // remove and rebuild (since we cannot change buffer size in webGL)
  this.scene.remove( this.polygonTriangles.mesh );
  this.initPolygonTriangles();
  var center = this.getPolygonCenter();

  // add the center to the geom
  this.polygonTriangles.geometry.vertices.push(
    new THREE.Vector3( center[0], center[1], center[2])
  );

  // add all the vertice to the geom
  for(v=0; v<this.planePolygon.length; v++){

    this.polygonTriangles.geometry.vertices.push(
      new THREE.Vector3(
        parseFloat(this.planePolygon[v][0]),
        parseFloat(this.planePolygon[v][1]),
        parseFloat(this.planePolygon[v][2])
      ));
  }

  // shaping the faces out of the vertice
  for(v=0; v<this.planePolygon.length - 1; v++){
    this.polygonTriangles.geometry.faces.push( new THREE.Face3( 0, v+1, v+2 ) );
  }

  // adding the last face manually (to close the loop)
  this.polygonTriangles.geometry.faces.push( new THREE.Face3( 0, this.planePolygon.length, 1 ) );

  this.polygonTriangles.geometry.computeFaceNormals();
  this.polygonTriangles.mesh.name = "intersectPolygon"

  // it was removed earlier
  this.scene.add( this.polygonTriangles.mesh );

}


/*
  return a copy of this.planePolygon
*/
VolumeNavigator.prototype.getPlanePolygon = function(){
  return this.planePolygon.slice();
}


/*
  Load a texture from a canvas onto the section polygon using a "star pattern"
  --> using the center of the polygon as the common vertex for every triangle that
  compose the polygon.
  args:
    canvasID: string - the id of the html5 canvas we want to use the content from.
    coordinates: array of [x, y] - each [x, y] are the vertex as represented in the
      2D image, but they are in the ThreeJS convention (percentage + origin at bottom-left)

    We must have as many [x, y] couples in coordinates as there is faces declared in
    this.polygonTriangles.geometry.faces.

    In addition, the coord couples from coordinates must be in the same order as the
    faces from this.polygonTriangles.geometry.faces were declared
    (this dirty sorting job is not supposed to be done here!)
*/
VolumeNavigator.prototype.mapTextureFromCanvas = function(canvasID, coordinates){
  var numOfVertice = coordinates.length;

  // getting the center in the texture system (percentage + orig at bottom left)
  var coordCenter = [0, 0];

  for(var v=0; v<numOfVertice; v++){
    coordCenter[0] += coordinates[v][0];
    coordCenter[1] += coordinates[v][1];
  }

  coordCenter[0] /= numOfVertice;
  coordCenter[1] /= numOfVertice;

  // those triangles are percent coord that will match each face.
  var mappingTriangles = [];

  for(var v=0; v<numOfVertice - 1; v++){
    mappingTriangles.push(
      [
        new THREE.Vector2(coordCenter[0], coordCenter[1]), // C
        new THREE.Vector2(coordinates[v][0], coordinates[v][1]), // A
        new THREE.Vector2(coordinates[v+1][0], coordinates[v+1][1]) // B
      ]
    );
  }

  // adding the last triangle to close the loop
  mappingTriangles.push(
    [
      new THREE.Vector2(coordCenter[0], coordCenter[1]), // C
      new THREE.Vector2(coordinates[numOfVertice-1][0], coordinates[numOfVertice-1][1]), // A
      new THREE.Vector2(coordinates[0][0], coordinates[0][1]) // B
    ]
  );


  // clearing out any existing UV mapping
  this.polygonTriangles.geometry.faceVertexUvs[0] = [];

  // mapping the UV within the geometry
  for(var v=0; v<numOfVertice; v++){
    this.polygonTriangles.geometry.faceVertexUvs[0].push(
      [
        mappingTriangles[v][0],
        mappingTriangles[v][1],
        mappingTriangles[v][2]
      ]
    );
  }

  // loading the texture
  var canvas = document.getElementById(canvasID);
  var texture = new THREE.Texture(canvas);
  texture.needsUpdate = true;
  this.polygonTriangles.material.map = texture;
  this.polygonTriangles.geometry.uvsNeedUpdate = true;

}


/*
  Creates the gimbal, which is the reference object for getting the plane equation.
  The reference normal vector is the normal of the zCircle (0, 0, 1),
  no good reason for that, just by convention.
*/
VolumeNavigator.prototype.initGimbal = function(){

  var center = [
    this.outerBoxSize.xSize / 2,
    this.outerBoxSize.ySize / 2,
    this.outerBoxSize.zSize / 2
  ]
  var origin = new THREE.Vector3( center[0], center[1], center[2] );

  var length = this.boxDiagonal / 10;
  var headLength = length * 0.8;
  var headWidth =  length * 0.6;

  var xColor = 0xff3333;
  var yColor = 0x00ff55;
  var zColor = 0x0088ff;

  // CIRCLE HELPERS - ROTATION
  var geometryX = new THREE.CircleGeometry( this.boxDiagonal / 2, 64 );
  var geometryY = new THREE.CircleGeometry( this.boxDiagonal / 2, 64 );
  var geometryZ = new THREE.CircleGeometry( this.boxDiagonal / 2, 64 );
  var materialX = new THREE.LineBasicMaterial( { color: xColor, linewidth:1.5 } );
  var materialY = new THREE.LineBasicMaterial( { color: yColor, linewidth:1.5 } );
  var materialZ = new THREE.LineBasicMaterial( { color: zColor, linewidth:1.5 } );
  // remove inner vertice
  geometryX.vertices.shift();
  geometryY.vertices.shift();
  geometryZ.vertices.shift();

  // X circle
  var circleX = new THREE.Line( geometryX, materialX );
  circleX.name = "xCircle";
  geometryX.rotateY(Math.PI / 2)
  // Y circle
  var circleY = new THREE.Line( geometryY, materialY );
  circleY.name = "yCircle";
  geometryY.rotateX(-Math.PI / 2)
  // Z circle
  var circleZ = new THREE.Line( geometryZ, materialZ );
  circleZ.name = "zCircle";

  this.gimbal = new THREE.Object3D();
  this.gimbal.add(circleX);
  this.gimbal.add(circleY);
  this.gimbal.add(circleZ);

  // DOUBLE SIDE ARROW
  var normalVectorArrow = new THREE.Vector3().copy(circleZ.geometry.faces[0].normal);
  var normalArrow = new THREE.ArrowHelper(
    normalVectorArrow ,
    new THREE.Vector3(0, 0, 0),
    length,
    0x12C9BD,
    headLength,
    headWidth
  );
  normalArrow.name = "normalArrow";
  // renaming the child because it's with them we will intersect
  normalArrow.cone.name = "normalArrow";
  normalArrow.line.name = "normalArrow";


  var normalReverseVectorArrow = new THREE.Vector3().copy(normalVectorArrow).negate();
  var normalReverseArrow = new THREE.ArrowHelper(
    normalReverseVectorArrow ,
    new THREE.Vector3(0, 0, 0),
    length,
    0xFCC200,
    headLength,
    headWidth
  );
  normalReverseArrow.name = "normalArrow";
  // renaming the child because it's with them we will intersect
  normalReverseArrow.cone.name = "normalArrow";
  normalReverseArrow.line.name = "normalArrow";

  this.gimbal.add(normalArrow);
  this.gimbal.add(normalReverseArrow);

  this.gimbal.translateOnAxis(origin.normalize(),  this.boxDiagonal / 2 );
  this.scene.add( this.gimbal );

  /*
  // creating a semi transparent sphere to better lead the user to were is the gimbal
  var sphereGeometry = new THREE.SphereGeometry( (this.boxDiagonal / 2)-1, 64, 64 );
  var sphereMaterial = new THREE.MeshBasicMaterial( {
    color: 0xffff00,
    transparent: true,
    opacity: 0.5,
    side: THREE.BackSide
  } );

  var sphere = new THREE.Mesh( sphereGeometry, sphereMaterial );
  this.gimbal.add( sphere );
  */

  this.originalQuaternion = new THREE.Quaternion().copy(this.gimbal.quaternion);
  this.saveGimbalSettings("_original_", true, "The first quaternion");

  // adding that to history
  this.addToHistory("Initial gimbal settings");

}


/*
  Creates a snapshot of the current gimbal settings (deep copy) and returns it.
  This is used for saving a specific configuration as well as
  buildind the history stack.
*/
VolumeNavigator.prototype.getCurrentGimbalSettings = function(){
  var gimbalSettings = {
    quat: new THREE.Quaternion().copy(this.gimbal.quaternion),
    center: new THREE.Vector3().copy(this.gimbal.position),
    name: null,
    desc: null, // will most likely remain blank
    date: new Date()  // now
  };

  return gimbalSettings;
}


/*
  Apply a given gimbal settings object.
  Does not call any callbacks.
  Args:
    gs: object as created by this.getCurrentGimbalSettings()
*/
VolumeNavigator.prototype.applyGimbalSettings = function(gs){
  this.setGimbalCenterV(gs.center);
  this.setGimbalQuaternion(gs.quat);
}


/*
  Add the current quaternion to the list.
  Args:
    name: String - name given to this q, useful to retrieve it (mandatory)
    replace: bool - if true, replace when name already in the list (mandatory)
    description: String - optional
*/
VolumeNavigator.prototype.saveGimbalSettings = function(name, replace, description){
  if(!name){
    console.warn("Name is mandatory when saving a quaternion.");
    return;
  }

  var gimbalSettings = this.getCurrentGimbalSettings();
  gimbalSettings.name = name;
  gimbalSettings.desc = description;

  if (!(name in this.savedGimbalSettings) || replace){
    this.savedGimbalSettings[name] = gimbalSettings;
    console.log("quaternions saved under the name " + name);
  }else{
    console.warn("The quaternion " + name + " is already in the list.");
  }
}


/*
  Restore/apply a quaternion that was previously saved (and call update() ).
  Args:
    name: String - unique identidfier of the quaternion
    exeCallbacks: bool - if true, execute the callbacks
*/
VolumeNavigator.prototype.restoreGimbalSettings = function(name, exeCallbacks){
  if (name in this.savedGimbalSettings){

    this.applyGimbalSettings(this.savedGimbalSettings[name]);

    this.addToHistory("Restoring gimbal settings: " + name);

    if(exeCallbacks){
      this.callThreeMovedAlongCallbacks();
    }
  }
}


/*
  Return the list of all the saved quaternions list
*/
VolumeNavigator.prototype.getsavedGimbalSettingsNameList = function(){
  return Object.keys(this.savedGimbalSettings);
}


/*
  Hide or show the axis arrow helper
*/
VolumeNavigator.prototype.AxisArrowHelperToggle = function(){
  this.gimbal.visible = !this.gimbal.visible;
  this.innerBox.helper.visible = !this.innerBox.helper.visible;
}


/*
  return true is the mouse pointer is currently within the canvas,
  return false if outside.
*/
VolumeNavigator.prototype.isMouseWithinCanvas = function(event){
  var scrollTop = window.pageYOffset || (document.documentElement || document.body.parentNode || document.body).scrollTop;

  var offsetLeft = this.getCanvasLeftOffset();

  if(event.clientX > offsetLeft &&
    event.clientX < offsetLeft + this.domContainer.offsetWidth &&
    event.clientY > this.domContainer.offsetTop  - scrollTop &&
    event.clientY < this.domContainer.offsetTop + this.domContainer.offsetHeight
    ){

    return true;
  }else{
    return false;
  }
}


/*
  If the canvas is encapsulated in a hierarchy of divs, we have to get all the
  relative offet so that we can get the [-1, 1] coord system
*/
VolumeNavigator.prototype.getCanvasLeftOffset = function(){
  var offsetLeft =  this.domContainer.offsetLeft;
  var parentContainer = this.domContainer.offsetParent;

  // adding parent's relative offsets (not using jquery makes it kind of cumbersome...)
  while(parentContainer){
    offsetLeft += parentContainer.offsetLeft;
    parentContainer = parentContainer.offsetParent;
  }

  return offsetLeft;
}


/*
  Update the mouse position with x and y in [-1; 1]
*/
VolumeNavigator.prototype.updateMousePosition = function(event){
  var scrollTop = window.pageYOffset || (document.documentElement || document.body.parentNode || document.body).scrollTop;

  var offsetLeft = this.getCanvasLeftOffset();

  this.mouse.x = ( (event.clientX - offsetLeft) / this.domContainer.offsetWidth ) * 2 - 1;
  this.mouse.y = - ( (event.clientY - this.domContainer.offsetTop + scrollTop) / this.domContainer.offsetHeight ) * 2 + 1;
}


/*
  Callback to perform when to mouse clicks
*/
VolumeNavigator.prototype.onMouseDown = function(event){

  if(this.isMouseWithinCanvas(event)){

    this.updateMousePosition(event);
    this.updateAxisRaycaster();
  }
}


/*
  callback to perform when the mouse does not click anymore (release)
*/
VolumeNavigator.prototype.onMouseUp = function(event){
  var endGrabPosition = new THREE.Vector3(this.mouse.x, this.mouse.y, 1);
  endGrabPosition.unproject(this.camera);

  if(this.objectGrabed.isGrabed){

    switch (this.objectGrabed.translationOrRotation) {
      // this is a tranlation...
      case 0:
        if(this.objectGrabed.axis[0] == 1){ // shift key was hold at the clicking
          // adding that to history
          this.addToHistory("Translating manually onto the plane");
        }else{ // regular case
          // adding that to history
          this.addToHistory("Translating manually along the normal vector");
        }
        break;

      // this is a rotation...
      case 1:
        var axisName = "";
        if(this.objectGrabed.axis[0] == 1){
          axisName = "X";
        }else if(this.objectGrabed.axis[1] == 1){
          axisName = "Y";
        }else if(this.objectGrabed.axis[2] == 1){
          axisName = "Z";
        }

        // adding that to history
        this.addToHistory("Grabbing axis " + axisName + " to perfom a manual rotation");
        break;
      default:

    }


    // restore the view we had before grabbing axis arrows (should not be necessary but I suspect a bug in OrbitControlJS)
    this.restoreOrbitData();

    this.objectGrabed.isGrabed = false;
    // disable the controls
    this.controls.enabled = true;

    // optionally auto place the center of the gimbal at the center of the polygon
    //this.placeGimbalAtPolygonCenter();

    /*
    if(this.onFinishChangeCallback){
      this.onFinishChangeCallback();
    }
    */

    this.callAllMovedCallbacks();



    // reset the callback lists
    this.movingCallbacks = [];
    this.movedCallbacks = [];
  }
}


/*
  Callback when the mouse moves.
  If the gimbal is grabed at some point, this will trigger the move
*/
VolumeNavigator.prototype.onMouseMove = function(event){

  // if no object is grabbed, we dont do anything
  if(!this.objectGrabed.isGrabed){
    return;
  }

  if(this.isMouseWithinCanvas(event)){
    this.updateMousePosition(event);

    // Mouse is supposed to have moved but sometimes the values are the same...
    if(this.objectGrabed.previousMouse.x == this.mouse.x &&
       this.objectGrabed.previousMouse.y == this.mouse.y){
      return;
    }

    // Tranlation or rotation?
    switch (this.objectGrabed.translationOrRotation) {
      // this is a tranlation...
      case 0:
        if(this.objectGrabed.axis[0] == 1){ // shift key was hold at the clicking
          this.mouseMoveTranslationSamePlane();
        }else{ // regular case
          this.mouseMoveTranslation();
        }
        break;

      // this is a rotation...
      case 1:
        this.mouseMoveRotation();
        break;
      default:

    }

    this.update();
    this.objectGrabed.previousMouse.copy(this.mouse);


    this.callAllMovingCallbacks();
    //this.test1();


    /*
    if(this.onChangeCallback){
      this.onChangeCallback();
    }
    */


  }
}


/*
  called by onMouseMove when we are dealing with a rotation
*/
VolumeNavigator.prototype.mouseMoveTranslation = function(event){
  var center = this.getGimbalCenter();

  // get the helper origin in 2D [-1, 1] range
  var gimbalCenter2D = this.getScreenCoord(center, true);

  // the dir vector is the normal to the plane or its opposite
  var normal = this.getGimbalNormalVector(2);

  // projecting the directional vector in 2D (from the center), to get a 2D vector
  var topPoint = [
    center[0] + normal.x,
    center[1] + normal.y,
    center[2] + normal.z
  ]

  var topPoint2D = this.getScreenCoord(topPoint, true);

  var directionalVector2D = [
    topPoint2D[0] - gimbalCenter2D[0],
    topPoint2D[1] - gimbalCenter2D[1],
    topPoint2D[2] - gimbalCenter2D[2]
  ];
  var directionalVector2D_normalized = this.vectorTools.normalize(directionalVector2D);

  // vector
  var mouseVector = [
    this.mouse.x - this.objectGrabed.previousMouse.x,
    this.mouse.y - this.objectGrabed.previousMouse.y,
    0
  ];

  var mouseVector_normalize = this.vectorTools.normalize(mouseVector);

  var dotProd = this.vectorTools.dotProduct(
    directionalVector2D_normalized,
    mouseVector_normalize
  );

  var distance = ( this.vectorTools.getNorm(mouseVector) / this.vectorTools.getNorm(directionalVector2D) ) * dotProd;

  // here we have to use the relative normal vector of the gimbal
  // before it was rotated with quaternions (this is simply (0, 0, 1) )
  var gimbalRelativeNormal = this.gimbal.children[2].geometry.faces[0].normal;
  this.gimbal.translateOnAxis( gimbalRelativeNormal,distance );

}


/*
  Happens when the center of the gimbal is clicked to be moved AND the SHIFT key
  is hold. Instead of moving the plane towards (or opposite to) the reference normal
  vector of the plane, the center of the gimbal moves within the plane
  (only X and Y in the gimbal reference move, Z remains)
*/
VolumeNavigator.prototype.mouseMoveTranslationSamePlane = function(event){

	this.raycaster.setFromCamera( this.mouse, this.camera );
  var hit = false;

  // intersection with a circle? (for rotation)
  var gimbalIntersections = this.raycaster.intersectObjects(
    //this.polygonTriangles.geometry.faces,
    this.scene.children,
    true
  );

  //console.log("THEN: this.polygonTriangles.geometry");
  //console.log(this.polygonTriangles.geometry.faces);


  for(i=0; i<gimbalIntersections.length; i++){
    if(gimbalIntersections[i].object.name == "intersectPolygon"){

      this.gimbal.position.copy(gimbalIntersections[i].point);
      break;
    }
  }
}


/*
  called by onMouseMove when we are dealing with a rotation
*/
VolumeNavigator.prototype.mouseMoveRotation = function(event){

  // get the helper origin in 2D [-1, 1] range
  var gimbalCenter2D = this.getScreenCoord(this.getGimbalCenter(), true);

  // angle previousPos -> center -> newPos
  var angle = this.vectorTools.getAnglePoints(
    [this.objectGrabed.previousMouse.x, this.objectGrabed.previousMouse.y, 0],
    gimbalCenter2D,
    [this.mouse.x, this.mouse.y, 0]
  );

  // v1 goes from center to previous mouse pos
  var v1 = [
    this.objectGrabed.previousMouse.x - gimbalCenter2D[0],
    this.objectGrabed.previousMouse.y - gimbalCenter2D[1],
    0
  ];

  // v2 goes from center to current mouse pos
  var v2 = [
    this.mouse.x - gimbalCenter2D[0],
    this.mouse.y - gimbalCenter2D[1],
    0
  ];

  var crossP = this.vectorTools.crossProduct(v2, v1, true);

  // vector from camera to gimbal center
  var cameraToGimbal = new THREE.Vector3().subVectors(
    this.gimbal.position,
    this.camera.position
  ).normalize();

  var axisIndex = this.objectGrabed.axis.indexOf(1);

  var normalVector = this.getGimbalNormalVector(axisIndex);
  var dotProd = normalVector.dot(cameraToGimbal);

  // the finale angle is the angle but with a decision over the sign of it
  var finalAngle = angle * crossP[2] * (dotProd>0?1:-1);
  this.rotateGimbal(finalAngle, axisIndex);
}


/*
  return the normal vector of one of the disc that compose the gimbal.
  The hardcoded normal vector does not take into consideration the rotation
  of the gimbal, thus we need a method for that. (returns a copy)
*/
VolumeNavigator.prototype.getGimbalNormalVector = function(axis){

  var circleQuaternion = new THREE.Quaternion().copy(this.gimbal.quaternion);
  var normalVector = new THREE.Vector3()
    .copy(this.gimbal.children[axis].geometry.faces[0].normal);

  normalVector.applyQuaternion(circleQuaternion).normalize();

  return normalVector;
}


/*
  The same as getGimbalNormalVector but returns a [x, y, z] JS Array
*/
VolumeNavigator.prototype.getGimbalNormalVectorArr = function(axis){
  var v = this.getGimbalNormalVector(axis);
  return [v.x, v.y, v.z];
}

/*
  return a hard copy of the gimbal's quaternion
*/
VolumeNavigator.prototype.getGimbalQuaternion = function(){
  return new THREE.Quaternion().copy(this.gimbal.quaternion);
}


/*
  set the quaternion
  Args:
    q: THREE.Quaternion - the quaternion to apply to the gimbal
*/
VolumeNavigator.prototype.setGimbalQuaternion = function(q){
  this.gimbal.quaternion.copy(q);
  this.update();
}


/*
  set the quaternion's element to apply to the gimbal
*/
VolumeNavigator.prototype.setGimbalQuaternionElem = function(x, y, z, w){
  this.gimbal.quaternion.x = x;
  this.gimbal.quaternion.y = y;
  this.gimbal.quaternion.z = z;
  this.gimbal.quaternion.w = w;

  this.update();
}


/*
  reinit the gimbal rotation to how it was at the very begining.
  Args:
    callCallback: bool - if true, calls the callbacks
*/
VolumeNavigator.prototype.restoreOriginalGimbalSettings = function(callCallback){
  this.restoreGimbalSettings("_original_", callCallback);
}


/*
  Called by a mouseDown event. Launch a raycaster to each arrow axis helper (the one used for translating the plane)
*/
VolumeNavigator.prototype.updateAxisRaycaster = function(){
  // if the axis helper are hidden, we dont go further
  if(!this.gimbal.visible){
    return;
  }

  // update the picking ray with the camera and mouse position
	this.raycaster.setFromCamera( this.mouse, this.camera );
  var hit = false;

  // intersection with a circle? (for rotation)
  var gimbalIntersections = this.raycaster.intersectObjects(this.gimbal.children, true );

  if(gimbalIntersections.length){

    this.objectGrabed.currentGrabPosition.copy(gimbalIntersections[0].point);
    hit = true;
    var objectName = gimbalIntersections[0].object.name;

    if(objectName == "xCircle"){
      this.objectGrabed.axis = [1, 0, 0];
      this.objectGrabed.translationOrRotation = 1;
      this.addMovingCallbacks("onOrbitingX");
      this.addMovedCallbacks("onOrbitedX");

    }else if (objectName == "yCircle"){
      this.objectGrabed.axis = [0, 1, 0];
      this.objectGrabed.translationOrRotation = 1;
      this.addMovingCallbacks("onOrbitingY");
      this.addMovedCallbacks("onOrbitedY");

    }else if (objectName == "zCircle"){
      this.objectGrabed.axis = [0, 0, 1];
      this.objectGrabed.translationOrRotation = 1;
      this.addMovingCallbacks("onOrbitingZ");
      this.addMovedCallbacks("onOrbitedZ");

    }else if (objectName == "normalArrow"){
      if(this.objectGrabed.shift){
        this.objectGrabed.axis = [1, 1, 1]; // just used that as a flag, not actual axis!
        this.addMovingCallbacks("onMovingAlongOrthoU");
        this.addMovingCallbacks("onMovingAlongOrthoV");
        this.addMovedCallbacks("onMovedAlongOrthoV");
        this.addMovedCallbacks("onMovedAlongOrthoU");
      }else{
        this.objectGrabed.axis = [0, 0, 0]; // just used that as a flag, not actual axis!
        this.addMovingCallbacks("onMovingAlongNormal");
        this.addMovedCallbacks("onMovedAlongNormal");
      }
      this.objectGrabed.translationOrRotation = 0;
    }
  }

  // in any case of hit...
  if(hit){
    this.objectGrabed.previousMouse.copy(this.mouse);
    this.objectGrabed.isGrabed = true;
    this.controls.enabled = false;
    this.saveOrbitData();
  }

}


/*
  save the OrbitControl setting to be able to restore this exact view later.
  This behavior is supposed to be built in THREE OrbitControl, but it does not work.
*/
VolumeNavigator.prototype.saveOrbitData = function(){
  this.orbitData = {
    target: new THREE.Vector3(),
    position: new THREE.Vector3(),
    zoom: this.controls.object.zoom
  }

  this.orbitData.target.copy(this.controls.target);
  this.orbitData.position.copy(this.controls.object.position);
}


/*
  Restore the view that was saved before.
  This behavior is supposed to be built in THREE OrbitControl, but it does not work.
*/
VolumeNavigator.prototype.restoreOrbitData = function(){
  this.controls.position0.copy(this.orbitData.position);
  this.controls.target0.copy(this.orbitData.target);
  this.controls.zoom0 = this.orbitData.zoom;
  this.controls.reset();
}


/*
  axis is 0 for x, 1 for y and 2 for z (relative to the gimbal)
*/
VolumeNavigator.prototype.rotateGimbal = function(angle, axis){
  var circleObject = this.gimbal.children[ axis ];

  // the rotation axis we want is the normal of the disk
  // the NoRot vector is the normal vector before the group was rotated
  var normalVectorNoRot = new THREE.Vector3().copy(circleObject.geometry.faces[0].normal);

  // the metods rotateOnAxis takes in consideration the internal quaternion
  // (no need to tune that manually, like I was trying to...)
  this.gimbal.rotateOnAxis( normalVectorNoRot, angle );

}


/*
  return the center of the arrow helper system,
  which is also the center of the gimbal
*/
VolumeNavigator.prototype.getGimbalCenter = function(){
  var center = this.gimbal.position;

  return [
    center.x,
    center.y,
    center.z
  ];
}


/*
  moves the helper centers to the center of the polygon
  (called at mouseup)
*/
VolumeNavigator.prototype.placeGimbalAtPolygonCenter = function(){
  if(!this.gimbal)
    return;

  this.setGimbalCenter( this.getPolygonCenter() );

  this.callCallback("onMovedAlongOrthoU");
  this.callCallback("onMovedAlongOrthoV");
}


/*
  Set the gimbal center position (absolute coord).
  Does not check if it is still in the volume.
  If check is needed, use this.setPlanePoint()
  Args:
    coord: Array [x, y, z]
*/
VolumeNavigator.prototype.setGimbalCenter = function(coord){
  this.gimbal.position.x = coord[0];
  this.gimbal.position.y = coord[1];
  this.gimbal.position.z = coord[2];

  console.log(this.gimbal.position);
}


/*
  Set the gimbal center to v, almost the same as setGimbalCenter() but uses a
  THREE js object instead, more convenient for doing it internally.
  Args:
    v: THREE.Vector3 - the center, will be (deep) copied.
*/
VolumeNavigator.prototype.setGimbalCenterV = function(v){
  this.gimbal.position.copy(v);
}

/*
  Change the gimbal normal, will be noralize.
  Args:
    vector: Array [x, y, z] - normal vector
*/
VolumeNavigator.prototype.setGimbalReferenceNormal = function(vector){
  // first, we restore the orinal quaternion to make sure we are performing
  // a rotation in the absolute system
  this.setGimbalQuaternion(this.savedGimbalSettings["_original_"].quat);

  // 1- make sure "vector" is normalized
  var futureNormal = new THREE.Vector3(vector[0], vector[1], vector[2]).normalize();
  var gimbalNormal = new THREE.Vector3().copy(this.getGimbalNormalVector(2));

  var newNormalQuaternion = new THREE.Quaternion().setFromUnitVectors(
    gimbalNormal, // from this...
    futureNormal // ...to that
  );

  this.setGimbalQuaternion(newNormalQuaternion); // update() is called there
}



/*
  Easier to access than rotateGimbal because it updates and call the right callbacks
*/
VolumeNavigator.prototype.rotateDegreeAndUpdate = function(angle, axis){

  var axisName = '';

  this.rotateGimbal(angle * Math.PI/180., axis);

  // updating equation and its display on dat.gui
  this.update();

  // call some impacted callback
  this.callThreeMovedAlongCallbacks();

  switch (axis) {
    case 0:
      this.callCallback("onOrbitedX");
      axisName = 'X';
      break;

    case 1:
      this.callCallback("onOrbitedY");
      axisName = 'Y';
      break;

    case 2:
      this.callCallback("onOrbitedZ");
      axisName = 'Z';
      break;

    default:;

  }

  this.addToHistory("Rotating of " + angle + "° around axis " + axisName + " (parametric)");

}


/*
  Move the center of the gimbal relative to its current position.
  To set the absolute position, use this.setPlanePoint()
*/
VolumeNavigator.prototype.moveGimbalCenterRelative = function(vector){
  this.gimbal.position.add(vector);
}


/*
  return the screen coord [x, y]
  args:
    coord3D: Array [x, y, z] - the 3D coodinate to convert
    normalized: bool - when true, x and y are within [-1, 1]
      if false, they are in pixel (ie. x[0, 800] and y[0, 600])
*/
VolumeNavigator.prototype.getScreenCoord = function(coord3D, normalized){

  var width = this.domContainer.offsetWidth;
  var height = this.domContainer.offsetHeight;

  var vector = new THREE.Vector3();
  vector.set( coord3D[0], coord3D[1], coord3D[2] );

  // map to normalized device coordinate (NDC) space
  vector.project( this.camera );

  if(!normalized){
    // map to 2D screen space
    vector.x = (   vector.x + 1 ) * (width  / 2 );
    vector.y = ( - vector.y + 1 ) * (height / 2 );
    vector.z = 0;
  }

  return [vector.x, vector.y, 0];
}


/*
  Tilt the gimbal so that u unit vectors becomes the reference normal vector
  (= normal of zCircle)
  In other word, this is a pi/2 rotation around Y axis
  (here, X relative to the gimbal world, dont forget we are using quaternions)
*/
VolumeNavigator.prototype.tiltGimbalU = function(){
  console.log("tiltGimbalU");
  // the X axis is the rotation axis (Y as defined originally)
  this.rotateGimbal(Math.PI/2., 0);
  this.update();

  this.callCallback("onOrbitedX");

  this.addToHistory("Using U orthogonal plane as reference");
}


/*
  Tilt the gimbal so that v unit vectors becomes the reference normal vector
  (= normal of zCircle)
  In other word, this is a pi/2 rotation around X axis
  (here, X relative to the gimbal world, dont forget we are using quaternions)
*/
VolumeNavigator.prototype.tiltGimbalV = function(){
  console.log("tiltGimbalV");
  // the Y axis is the rotation axis (Y as defined originally)
  this.rotateGimbal(Math.PI/2., 1);
  this.update();

  this.callCallback("onOrbitedY");

  // adding that to history
  this.addToHistory("Using V orthogonal plane as reference.");
}


/*
  This moves the plane along the reference normal vector (unit).
  Args:
    factor: number - negative to move backward, positive to move forward
      then, it can 1 or 10 depending on the step size we want to move
*/
VolumeNavigator.prototype.moveAlongNormal = function(factor){
  var resultVector = this.getGimbalNormalVector(2).multiplyScalar(factor);
  this.moveGimbalCenterRelative(resultVector);
  this.update();

  // adding that to history
  this.addToHistory("Translating along normal vector (factor: " + factor + ")");

  this.callCallback("onMovedAlongNormal");
}


/*
  This moves the plane along the orthogonal unit vector u.
  Args:
    factor: number - negative to move backward, positive to move forward
      then, it can 1 or 10 depending on the step size we want to move
*/
VolumeNavigator.prototype.moveAlongOrthoU = function(factor){
  var resultVector = this.getGimbalNormalVector(1).multiplyScalar(factor);
  this.moveGimbalCenterRelative(resultVector);
  this.update();

  // adding that to history
  this.addToHistory("Translating along U ortho vector (factor: " + factor + ")");

  this.callCallback("onMovedAlongOrthoU");
}


/*
  This moves the plane along the orthogonal unit vector v.
  Args:
    factor: number - negative to move backward, positive to move forward
      then, it can 1 or 10 depending on the step size we want to move
*/
VolumeNavigator.prototype.moveAlongOrthoV = function(factor){
  var resultVector = this.getGimbalNormalVector(0).multiplyScalar(factor);
  this.moveGimbalCenterRelative(resultVector);
  this.update();

  // adding that to history
  this.addToHistory("Translating along V ortho vector (factor: " + factor + ")");

  this.callCallback("onMovedAlongOrthoV");
}


/*
  Add a position to the history.

*/
VolumeNavigator.prototype.addToHistory = function(description){

  // this means we've 'undone' steps and we are about to add new ones (not redo)
  // so we have to remove the steps that once where "redo-able"
  var nbItemToRemove = (this.gimbalSettingHistory.length - 1) - this.historyIterator;
  if(nbItemToRemove > 0){
    this.gimbalSettingHistory.splice(-nbItemToRemove, nbItemToRemove);
  }

  // adding this new step
  var gimbalSettings = this.getCurrentGimbalSettings();
  gimbalSettings.name = "history"; // not sure it's useful
  gimbalSettings.desc = description;

  this.gimbalSettingHistory.push(gimbalSettings);

  // the iterator goes points the last element of the stack
  this.historyIterator = this.gimbalSettingHistory.length - 1;
}


/*
  Restore the gimbal settings at the given history position.
  Args:
    position: int - between 0 and this.gimbalSettingHistory.length-1
    exeCallbacks: bool - if true, the 3 main callbacks will be called in the end
*/
VolumeNavigator.prototype.gotoToHistory = function(position, exeCallbacks){
  // abort if out of range
  if(position < 0 || position > this.gimbalSettingHistory.length-1)
    return;

  this.historyIterator = position;
  this.applyGimbalSettings(this.gimbalSettingHistory[this.historyIterator]);

  if(exeCallbacks){
    this.callThreeMovedAlongCallbacks();
  }
}


/*
  One step rollback using gotoToHistory.
  Args:
    exeCallbacks: bool - if true, the 3 main callbacks will be called in the end
*/
VolumeNavigator.prototype.undo = function(exeCallbacks){
  this.gotoToHistory(this.historyIterator - 1, exeCallbacks);
}


/*
  One step rollforward using gotoToHistory.
  Args:
    exeCallbacks: bool - if true, the 3 main callbacks will be called in the end
*/
VolumeNavigator.prototype.redo = function(exeCallbacks){
  this.gotoToHistory(this.historyIterator + 1, exeCallbacks);
}
