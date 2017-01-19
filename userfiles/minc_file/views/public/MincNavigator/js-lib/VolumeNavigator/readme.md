Display a box in 3D with a plane to play with. Then get the plane equation from it.

[DEMO](https://jonathanlurie.github.io/VolumeNavigator/)

## How to use

see `index.html` or ...  

**Import**

```html
<script src="js/dat.gui.min.js"></script>
<script src="js/three.js"></script>
<script src="js/OrbitControls.js"></script>
<script src="VolumeNavigator.js"></script>
```

**Create a div with an ID**
```html
<div id="container"></div>
```

**Add a piece of Javascript in body**

```javascript

// shape of the outer box
var outerBoxOptions = {
    xSize: 330,
    ySize: 350,
    zSize: 385
}

// shape of the inner box, can also be null for an auto setting
var innerBoxOptions = {
    xSize: 150,
    ySize: 210,
    zSize: 280,
    xOrigin: 100,
    yOrigin: 30,
    zOrigin: 45
}

// create a VolumeNavigator instance
var vn = new VolumeNavigator(outerBoxOptions, innerBoxOptions, "container");
```

*Note: the outer box will be automatically stuck to the origin.*
