# Art sources and licences

Every texture and model file under `data/materials/` and `data/models/`, and the radio's pixel font under `data/ui/fonts/`, is listed here (the `.tres` sets and `.import` settings beside them are ours). All are CC0 (public domain), from ambientCG, Poly Haven or Kenney; the source URL is recorded so each can be checked. The one exception is the title's font, Yatra One (Story 24.6): SIL Open Font License 1.1, with its licence beside it as `ui/fonts/YatraOne.OFL.txt`. Downloads are images, glTF, and fonts only.

Material sets are ambientCG 1K-JPG downloads, repacked: `<set>_albedo.jpg` is the colour map; `<set>_nr.jpg` holds the OpenGL normal map's red and green in R and G and the roughness map in B (glass: roughness 0.05 to 0.45 from the smudge mask). Their `.import` files are checked in (VRAM compressed, mipmaps, normal-map detection off so B survives).

Street clutter models (Story 15.9) are Poly Haven 1K glTF downloads, reworked in Blender: joined, decimated, rebased to stand on their origin, and saved as glTF with colour and OpenGL normal maps resized to 512 px or less (roughness and metal maps dropped). `tree/tree_leaves.png` is a leaf-clump atlas rendered from the Tree Small 02 leaves, which the low-poly tree's cards show. Their texture `.import` files are checked in like the material library's.

Crew bodies (Story 20.1) are Kenney's Mini Characters (GLB), rigged and animated, with their shared `colormap.png`. `tools/models/crew_bodies.py` rewrites only their texture coordinates, so a crew look can recolour skin, hair and outfit; meshes, rigs and animations are as made.

The drone decals and race numbers (Story 27.2: block print, jharokha jali, chakra, lotus, peacock feather, sun, stripes, the team emblem) are no files at all: `scripts/drone/decal_art.gd` draws them in code when first worn. They are original to this game and ours, so no licence is needed.

`tests/test_material_library.gd` fails if a file is missing from this table or its licence is anything else.

| File | Source | Licence |
| --- | --- | --- |
| `materials/concrete_albedo.jpg` | ambientCG Concrete034: https://ambientcg.com/view?id=Concrete034 | CC0 |
| `materials/concrete_nr.jpg` | ambientCG Concrete034: https://ambientcg.com/view?id=Concrete034 | CC0 |
| `materials/brick_albedo.jpg` | ambientCG Bricks097: https://ambientcg.com/view?id=Bricks097 | CC0 |
| `materials/brick_nr.jpg` | ambientCG Bricks097: https://ambientcg.com/view?id=Bricks097 | CC0 |
| `materials/cladding_albedo.jpg` | ambientCG MetalPlates004: https://ambientcg.com/view?id=MetalPlates004 | CC0 |
| `materials/cladding_nr.jpg` | ambientCG MetalPlates004: https://ambientcg.com/view?id=MetalPlates004 | CC0 |
| `materials/glass_nr.jpg` | ambientCG SurfaceImperfections003: https://ambientcg.com/view?id=SurfaceImperfections003 | CC0 |
| `materials/paving_albedo.jpg` | ambientCG PavingStones128: https://ambientcg.com/view?id=PavingStones128 | CC0 |
| `materials/paving_nr.jpg` | ambientCG PavingStones128: https://ambientcg.com/view?id=PavingStones128 | CC0 |
| `materials/asphalt_albedo.jpg` | ambientCG Asphalt031: https://ambientcg.com/view?id=Asphalt031 | CC0 |
| `materials/asphalt_nr.jpg` | ambientCG Asphalt031: https://ambientcg.com/view?id=Asphalt031 | CC0 |
| `materials/kerb_albedo.jpg` | ambientCG Granite002B: https://ambientcg.com/view?id=Granite002B | CC0 |
| `materials/kerb_nr.jpg` | ambientCG Granite002B: https://ambientcg.com/view?id=Granite002B | CC0 |
| `materials/sand_albedo.jpg` | ambientCG Ground097: https://ambientcg.com/view?id=Ground097 | CC0 |
| `materials/sand_nr.jpg` | ambientCG Ground097: https://ambientcg.com/view?id=Ground097 | CC0 |
| `materials/rock_albedo.jpg` | ambientCG Rock029: https://ambientcg.com/view?id=Rock029 | CC0 |
| `materials/rock_nr.jpg` | ambientCG Rock029: https://ambientcg.com/view?id=Rock029 | CC0 |
| `materials/painted_metal_albedo.jpg` | ambientCG PaintedMetal014: https://ambientcg.com/view?id=PaintedMetal014 | CC0 |
| `materials/painted_metal_nr.jpg` | ambientCG PaintedMetal014: https://ambientcg.com/view?id=PaintedMetal014 | CC0 |
| `models/car/car.bin` | Poly Haven Covered Car: https://polyhaven.com/a/covered_car | CC0 |
| `models/car/car.gltf` | Poly Haven Covered Car: https://polyhaven.com/a/covered_car | CC0 |
| `models/car/covered_car_diff.jpg` | Poly Haven Covered Car: https://polyhaven.com/a/covered_car | CC0 |
| `models/car/covered_car_nor_gl.jpg` | Poly Haven Covered Car: https://polyhaven.com/a/covered_car | CC0 |
| `models/aircon/aircon.bin` | Poly Haven Exterior Aircon Unit: https://polyhaven.com/a/exterior_aircon_unit | CC0 |
| `models/aircon/aircon.gltf` | Poly Haven Exterior Aircon Unit: https://polyhaven.com/a/exterior_aircon_unit | CC0 |
| `models/aircon/exterior_aircon_unit_01_diff.jpg` | Poly Haven Exterior Aircon Unit: https://polyhaven.com/a/exterior_aircon_unit | CC0 |
| `models/aircon/exterior_aircon_unit_01_nor_gl.jpg` | Poly Haven Exterior Aircon Unit: https://polyhaven.com/a/exterior_aircon_unit | CC0 |
| `models/aircon/exterior_aircon_unit_02_diff.jpg` | Poly Haven Exterior Aircon Unit: https://polyhaven.com/a/exterior_aircon_unit | CC0 |
| `models/aircon/exterior_aircon_unit_02_nor_gl.jpg` | Poly Haven Exterior Aircon Unit: https://polyhaven.com/a/exterior_aircon_unit | CC0 |
| `models/bench/bench.bin` | Poly Haven Modular Street Seating: https://polyhaven.com/a/modular_street_seating | CC0 |
| `models/bench/bench.gltf` | Poly Haven Modular Street Seating: https://polyhaven.com/a/modular_street_seating | CC0 |
| `models/bench/modular_street_seating_armrests_diff.jpg` | Poly Haven Modular Street Seating: https://polyhaven.com/a/modular_street_seating | CC0 |
| `models/bench/modular_street_seating_armrests_nor_gl.jpg` | Poly Haven Modular Street Seating: https://polyhaven.com/a/modular_street_seating | CC0 |
| `models/bench/modular_street_seating_supports_diff.jpg` | Poly Haven Modular Street Seating: https://polyhaven.com/a/modular_street_seating | CC0 |
| `models/bench/modular_street_seating_supports_nor_gl.jpg` | Poly Haven Modular Street Seating: https://polyhaven.com/a/modular_street_seating | CC0 |
| `models/bench/modular_street_seating_timber_diff.jpg` | Poly Haven Modular Street Seating: https://polyhaven.com/a/modular_street_seating | CC0 |
| `models/bench/modular_street_seating_timber_nor_gl.jpg` | Poly Haven Modular Street Seating: https://polyhaven.com/a/modular_street_seating | CC0 |
| `models/tree/tree.bin` | Poly Haven Tree Small 02: https://polyhaven.com/a/tree_small_02 | CC0 |
| `models/tree/tree.gltf` | Poly Haven Tree Small 02: https://polyhaven.com/a/tree_small_02 | CC0 |
| `models/tree/tree_leaves.png` | Poly Haven Tree Small 02: https://polyhaven.com/a/tree_small_02 | CC0 |
| `models/tree/tree_small_02_branch_diff.jpg` | Poly Haven Tree Small 02: https://polyhaven.com/a/tree_small_02 | CC0 |
| `models/tree/tree_small_02_branch_nor_gl.jpg` | Poly Haven Tree Small 02: https://polyhaven.com/a/tree_small_02 | CC0 |
| `models/tree/tree_small_02_diff.jpg` | Poly Haven Tree Small 02: https://polyhaven.com/a/tree_small_02 | CC0 |
| `models/tree/tree_small_02_nor_gl.jpg` | Poly Haven Tree Small 02: https://polyhaven.com/a/tree_small_02 | CC0 |
| `models/crew/character-female-b.glb` | Kenney Mini Characters: https://kenney.nl/assets/mini-characters | CC0 |
| `models/crew/character-female-c.glb` | Kenney Mini Characters: https://kenney.nl/assets/mini-characters | CC0 |
| `models/crew/character-female-d.glb` | Kenney Mini Characters: https://kenney.nl/assets/mini-characters | CC0 |
| `models/crew/character-female-e.glb` | Kenney Mini Characters: https://kenney.nl/assets/mini-characters | CC0 |
| `models/crew/character-female-f.glb` | Kenney Mini Characters: https://kenney.nl/assets/mini-characters | CC0 |
| `models/crew/character-male-a.glb` | Kenney Mini Characters: https://kenney.nl/assets/mini-characters | CC0 |
| `models/crew/character-male-b.glb` | Kenney Mini Characters: https://kenney.nl/assets/mini-characters | CC0 |
| `models/crew/character-male-d.glb` | Kenney Mini Characters: https://kenney.nl/assets/mini-characters | CC0 |
| `models/crew/character-male-f.glb` | Kenney Mini Characters: https://kenney.nl/assets/mini-characters | CC0 |
| `models/crew/colormap.png` | Kenney Mini Characters: https://kenney.nl/assets/mini-characters | CC0 |
| `ui/fonts/PixelOperatorMonoHB.ttf` | Pixel Operator by Jayvee Enaguas (HarvettFox96): https://www.dafont.com/pixel-operator.font | CC0 |
| `ui/fonts/PixelOperatorMono-Bold.ttf` | Pixel Operator by Jayvee Enaguas (HarvettFox96): https://www.dafont.com/pixel-operator.font | CC0 |
| `ui/fonts/YatraOne-Regular.ttf` | Yatra One by The Yatra Project Authors: https://github.com/google/fonts/tree/main/ofl/yatraone | SIL Open Font License 1.1 |
