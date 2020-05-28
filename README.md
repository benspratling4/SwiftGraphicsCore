# SwiftGraphicsCore
Core geometries &amp; protocols for a pure-Swift implementation of 2D graphics rendering.

WIP.  There are probably many convenience & efficient algorithms missing.  There may be missing concepts or cases.

## Linear Distance

`typealias SGFloat = Float64`


## 2D Coordinates

Coordinate system assumes x+ to the right, y+ is down the page.  Placing (0,0) in the upper left hand corner.

A position in the x-y plane

`struct Point`

`struct Size`


A rectangle, defined by an origin point and a size.

`struct Rect`


An affine transform, using homogenous coordinates for translation

`struct Transform2D`


A line segment between two points

`struct Line`


##  Bezier paths

`Path` represents a collection of `SubPath`s.  Each subpath is composed of a starting point and an array of segments.  Segments may be lines, or quadratic or cubic Bezier curves.  You don't interact with segments directly, but instead instantiate a `Path` then call functions like `.move(to point:Point)` or `addCurve(near controlPoint:Point, to point:Point)` on the `Path`.

When Filling on a GraphicsContext, the  `FillOptions` take a `subPathOverlapping` parameter which governs how the rasterzation algorithms determine if a point is filled when it is included in overlapping or self-overlapping subpaths. 


Precise algorithms for whether a point is in a SubPath is done, but algorithms for decomposiing the subpaths into sub-pixel triangles is not done.





## Bitmap Images

A `SampledImage` represents a raster image in a particular color space.  You can obtain a `SampledImage` for a set of path drawing commands by instantiating a `SampledGraphicsContext` and calling `.draw...(` methods on it, then copying the `underlyingImage`.

- [x] Get a `SampledImage` from a `SampledGraphicsContext`.
- [x] Create a `SampledGraphicsContext` from a `SampledImage` for convenience.
- [ ] Render a scaled-down `SampledImage` into a `SampledGraphicsContext`.
- [ ] Render a scaled-up `SampledImage` into a `SampledGraphicsContext`.


## Progress

- [x] Geometry primitives for points, sizes, rectangles, lines, triangles
- [x] Path subdivision algorithms for considering linearity
- [x] Basic rasterization of fill
- [x] Support for gradients in fill
- [ ] Efficient rasterization of stroke (Should probably involve creating approximate outlines then filling)
- [x] Abstracted font types with basic rendering without caching
- [ ] Advanced raster image rescaling
- [ ] Support for sRGB color space
- [ ] Support for Display-P3 color space
- [ ] Support for HSB color space
- [ ] Support for CMYK color space
