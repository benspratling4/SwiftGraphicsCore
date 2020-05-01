# SwiftGraphicsCore
Core geometries &amp; protocols for a pure-Swift implementation of 2D graphics rendering.

WIP.  There are probably many convenience & efficient algorithms missing.  There may be missing concepts or cases.

## Linear Distance

`typealias SGFloat = Float64`


## 2D Coordinates

Coordinate system assumes x+ to the right, y+ is down the page.  Placing (0,0) in the upper left hand corner.

`struct Point`

`struct Size`

`struct Transform2D`


##  Bezier paths

Check out `Path`, `SubPath`, `PathSegment`.

Precise algorithms for whether a point is in a SubPath is done, but algorithms for decomposiing the subpaths into sub-pixel triangles is not done.
