# Drawn to Sea — first visual prototype

## Intent

A real 3D water surface that reads as an old pirate map: warm parchment,
weathered edges, sepia ink, engraved wave marks, and subtle moving relief.
The first test should establish the art direction before adding gameplay.

## Proposed foundation

- Godot 4 with GDScript and a custom spatial shader.
- Compatibility renderer initially: this effect needs no advanced rendering
  features, and this leaves a browser prototype possible.
- An orthographic camera looking down at an angle, with orbit and zoom.
- A subdivided plane with gentle vertex displacement for the sea.
- Paper texture anchored to map coordinates; animated wave contours layered
  over it. Avoid moving all the grain with the waves, which would look like fabric.
- One or two procedural island silhouettes to judge shore readability.

## Implementation sequence

1. **Material study:** create the plane, camera, parchment colors and grain,
   edge aging, wave displacement, and animated ink marks.
2. **Map composition:** add island outlines, coastal contour rings, a border,
   compass rose, and sparse labels. Keep decoration independent of water motion.
3. **Comparison controls:** expose wave height, speed, ink strength, and paper
   aging; allow pause and reset. Compare a still frame with the animated result.
4. **Art review:** judge the actual running scene at several zoom levels.
   Adjust scale and contrast before replacing procedural paper with painted assets.
5. **Interaction slice:** after choosing the visual direction, add either a small
   ship or route drawing, based on the intended game loop.

## First-test acceptance criteria

- A still frame immediately reads as a parchment nautical chart.
- Motion reads as water, with visible but restrained 3D relief.
- Grain stays anchored without distracting flicker or swimming.
- Coastlines remain readable while the surrounding water moves.
- Camera movement and material adjustments work in the running scene.
- Target a stable 60 FPS on the development Mac; measure before claiming it.

## Questions awaiting direction

- Desktop, browser, or both?
- Living parchment chart, strongly stylized ocean, or a map-to-ocean transition?
- Camera-only visual study, sailing ship, or drawing interaction first?

## Scope after the first test

Ship movement, buoyancy, navigation, route drawing, world generation, combat,
and progression need separate decisions. No physical fluid simulation is needed
to evaluate this visual concept.
