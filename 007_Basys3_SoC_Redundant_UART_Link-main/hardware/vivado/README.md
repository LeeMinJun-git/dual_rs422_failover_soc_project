# Vivado Integration

The exact final Vivado 2024.2 Block Design is stored as verified Base64 parts under `bd/parts/`. Its size, SHA-256, Git blob SHA-1, required custom IP instances, and AXI addresses are defined in `bd/system_bd_manifest.json`.

From the repository root, reconstruct and validate the final Block Design and all three packaged IP repositories:

```bash
python3 hardware/vivado/scripts/prepare_vivado_project.py
```

Create the Vivado project in batch mode:

```bash
vivado -mode batch -source hardware/vivado/scripts/create_project.tcl
```

Both steps can also be executed together:

```bash
python3 hardware/vivado/scripts/prepare_vivado_project.py --run-vivado
```

The generated project is written to:

```text
hardware/vivado/build/project/redundant_link.xpr
```

Requirements: Vivado 2024.2 and the Digilent Basys3 board files. The generated `build/` directory is intentionally excluded from Git.
