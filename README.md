# ErrorWater
An incomplete water shader written for unity's built-in render pipline developed for use in VRChat. This shader does things substantially different than most others available. For the animation of waves on the water surface it uses texture arrays containing a flipbook animation for both normals and vertex offsets, unlike most shaders which simply use two scrolling normal maps. This is a cheap way to get better looking water movement without complex calculations, as high-quality water simulations can be pre-baked from software like Blender. See the included blender file for an example. Distortion of the image underneath the water surface to simulate refraction is done by calculating the refraction direction and sampling the screen at a fixed distance along the refracted ray. This is more physically accurate than simply offsetting screen UV's by the normal, but introduces significant issues with rays exiting the screen and occlusion behind objects in front of the water. If the depth texture is available (note that soft particles must be enabled in the project for the shader to recognize if it is available) then the occlusion issue is solved by checking if the refracted pixel is in front of the water, and if it is then falling back to a different refraction behavior less likely to cause occlusion. Fog is also calculated from the depth texture using log^2 falloff. Additionally, this water shader uses my SSR implementation for forward rendering to give much better looking reflections.

# To Do List
- Add PBR lighting calculations (currently only uses probes and SSR for reflections)
- Add different varaiants without tesselation for AMD users
- Possibly add features for more ocean like water like foam and procedural waves