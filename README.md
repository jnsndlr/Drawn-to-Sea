# Drawn to Sea

Godot 4 parchment ocean material study. Open `project.godot` in Godot and press F6
with `scenes/map.tscn` open, or F5 to run the project.

Left- or middle-drag to pan, right-drag to orbit, scroll up to zoom in and down
to zoom out. Mac trackpad two-finger scrolling and pinch also zoom. Zoom stays anchored under the cursor. Space pauses the sea; R resets
the view and pan position.
The shader exposes wave height, separate wave/shore ink strengths, and paper/ink colors in its material.

See [PLAN.md](PLAN.md) for the proposed visual development sequence and open questions.

Current prototype: procedural parchment, two island silhouettes, animated ink
crest outlines, stationary land and coastlines, coastal rings, aged edges, a map border, and displaced 3D water.
Compass rose, labels, and on-screen material controls are planned next.

The water uses a muted blue-green watercolor wash with paper grain showing through.
Ocean ink contours come from a domain-warped, three-octave space-time noise field:
cells slowly morph, join and separate, with an independent smooth visibility mask
revealing only fragments. No global texture drift is applied. Water-side shoreline
rings expand/recede with staggered phases and fade gently; the land outline stays
fixed. Fine lines use screen derivatives for antialiasing. Small 3D displacement
combines the same cell field with directional gravity waves spread around the circle.

Shader controls include `wave_speed`, `shore_motion`, `line_visibility`, and
`crest_width`. Space freezes all water animation. This is a stylized procedural
approximation, not a fluid solver or breaking-surf simulation.

Technique references: [GPU Gems water synthesis](https://developer.nvidia.com/gpugems/gpugems/part-i-natural-effects/chapter-1-effective-water-simulation-physical-models)
and [multidimensional shader noise](https://stegu.github.io/webgl-noise/).

Use **Water controls** in the top right to show/hide the live sliders. Adjust motion
speed, wave height, cell size, visible fragments, line thickness, shoreline travel,
wave ink darkness, and shore ink darkness. Reset water defaults restores the current art direction without
changing the camera. Values apply for the current run and are not saved on exit.

## Illustrated terrain study

The map mesh now rises into two plateau islands, narrow beaches and four offshore
rocks. Terrain and water share one coastline function, including rock outlines.
Object-space paper texture, stepped face shading, cliff-lip ink, fractures and
selective hatching give the actual geometry an illustrated treatment. Right-drag
to orbit and scroll/pinch to inspect it closely. Terrain generation and shading
live in `shaders/terrain.gdshaderinc`; `terrain_height` in the main shader controls
relief. This first terrain pass is visual geometry only, without terrain collision,
trees or buildings.

## Card sailing prototype

Click a card to play it into the discard pile. Cards resolve one at a time:
Short Sail advances 1.2 units, Full Sail 2.4, Port/Starboard turn 45 degrees before
advancing 0.8, and Back Water reverses 0.8. The deck contains two of each maneuver
plus one each of Chain, Ball, Canister, Grape, Bar, and Bomb Shot. Cannon cards
auto-aim at the nearest living practice raft in range with a clear line across water.
Cards show range and damage: Chain 3.5/20, Ball 6/30, Canister 2/45, Grape 3/35,
Bar 4.5/25, and Bomb 4/40. No valid target keeps the card in hand.
Muzzle flash, smoke, flying ammunition and impact bursts resolve before the next
card can play; damage lands at contact. Four lashed-barrel rafts with small sails
have 60 hull each, visible health labels, and sink at zero. Restart restores them.
Start with five cards and five energy. Unplayed cards stay in hand between turns.
**End turn** starts the next turn and resets energy to five (unused energy does not
carry over) and automatically draws until your hand has five cards. Existing cards
stay in hand, and hands already at five or more are kept as-is. **Draw 1 card** is optional, free, and available once per turn,
including the opening turn. An empty draw pile reshuffles the discard.
**Discard → +1 energy**, then click a card, trades that card for one energy without
playing it. Repeat for as many cards as you want, even above five energy. After a
discard, no further draws are allowed that turn; a card already drawn stays yours.
Empty hands do not refill mid-turn: end the turn to refill to five. Discarding
blocks draws only for the current turn, not the next turn’s automatic refill.

Short Sail, Port, Starboard, and Back Water cost 1 energy; Full Sail, Chain,
Canister, Grape, and Bar cost 2; Ball and Bomb cost 3. Costs appear on each card,
and unaffordable cards dim. Invalid cannon shots spend no energy. Turn controls
lock while a card resolves or after the ship is lost. Restart resets the economy.
Counters and the most recently discarded card appear beneath the map.

Land and offshore rocks block the ship. One collision cancels the remaining move,
removes one of three hull points, knocks the ship back and briefly shakes the
camera. At zero hull, cards stop working until **Restart voyage**. Reaching the
chart edge stops movement without damage. Restart restores the ship and deck.

The placeholder ship leaves a widening, fading ink wake that is masked off land,
plus subtle broken oval ripples that continue to breathe around an idle hull.
The terrain and collision now share a baked two-channel coastline texture, sampled
with the same bilinear interpolation on CPU and GPU. Movement uses a conservative
hull perimeter and small swept steps to prevent crossing narrow rocks in one frame.
Space pauses the ambient water only; it does not pause card movement.

Run gameplay checks with:
`Godot --headless --path . --script res://tests/sailing_test.gd`

The hand is displayed as overlapping, fanned parchment cards. Hover to lift and
enlarge a card, then click to play it; it flies into the discard stack. Draw and
discard counts are shown on the physical stacks beside the hand. Cards dim while
a move resolves. The illustrations are original procedural nautical drawings.
