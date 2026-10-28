# Art sources and licences

Every texture and model file under `data/materials/` and `data/models/` is listed here (the `.tres` sets and `.import` settings beside them are ours). All are CC0 (public domain), from ambientCG or Poly Haven; the source URL is recorded so each can be checked. Downloads are images and glTF only.

Material sets are ambientCG 1K-JPG downloads, repacked: `<set>_albedo.jpg` is the colour map; `<set>_nr.jpg` holds the OpenGL normal map's red and green in R and G and the roughness map in B (glass: roughness 0.05 to 0.45 from the smudge mask). Their `.import` files are checked in (VRAM compressed, mipmaps, normal-map detection off so B survives).

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
