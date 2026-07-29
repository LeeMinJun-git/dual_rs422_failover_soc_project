#!/usr/bin/env python3
"""Reconstruct and validate the final Vivado 2024.2 source tree."""
from __future__ import annotations

import base64
import hashlib
import json
import shutil
import subprocess
import sys
import tempfile
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
VIVADO_DIR = ROOT / "hardware" / "vivado"
IP_DIR = ROOT / "hardware" / "ip"
BUILD_DIR = VIVADO_DIR / "build"


def extract_single_root(archive: Path, destination: Path) -> Path:
    if not archive.is_file():
        raise FileNotFoundError(f"Missing archive: {archive}")
    with tempfile.TemporaryDirectory() as tmp:
        tmp_path = Path(tmp)
        with zipfile.ZipFile(archive) as zf:
            bad = zf.testzip()
            if bad:
                raise RuntimeError(f"Corrupt member in {archive.name}: {bad}")
            zf.extractall(tmp_path)
        entries = [p for p in tmp_path.iterdir() if p.name != "__MACOSX"]
        source = entries[0] if len(entries) == 1 and entries[0].is_dir() else tmp_path
        if destination.exists():
            shutil.rmtree(destination)
        shutil.copytree(source, destination)
    return destination


def reconstruct_bd() -> Path:
    manifest_path = VIVADO_DIR / "bd" / "system_bd_manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    parts_dir = VIVADO_DIR / "bd" / "parts"
    data = b"".join(
        base64.b64decode((parts_dir / name).read_text(encoding="ascii").strip())
        for name in manifest["parts"]
    )
    if len(data) != manifest["size_bytes"]:
        raise RuntimeError("Block Design size does not match the manifest")
    if hashlib.sha256(data).hexdigest() != manifest["sha256"]:
        raise RuntimeError("Block Design SHA-256 does not match the manifest")
    git_blob_sha1 = hashlib.sha1(
        f"blob {len(data)}\0".encode("ascii") + data
    ).hexdigest()
    if git_blob_sha1 != manifest["git_blob_sha1"]:
        raise RuntimeError("Block Design Git blob SHA-1 does not match the manifest")
    design = json.loads(data.decode("utf-8"))["design"]
    if design["design_info"].get("tool_version") != "2024.2":
        raise RuntimeError("Unexpected Vivado version in Block Design")
    if design["design_info"].get("validated") != "true":
        raise RuntimeError("Block Design is not marked as validated")
    components = design.get("components", {})
    for name in manifest["required_components"]:
        if name not in components:
            raise RuntimeError(f"Missing final component: {name}")
    text = data.decode("utf-8")
    for address in manifest["required_addresses"]:
        if address not in text:
            raise RuntimeError(f"Missing AXI address: {address}")
    source_dir = BUILD_DIR / "source"
    source_dir.mkdir(parents=True, exist_ok=True)
    output = source_dir / "system_bd.bd"
    output.write_bytes(data)
    return output


def prepare_ip_repositories() -> list[Path]:
    repo_dir = BUILD_DIR / "ip_repo"
    repo_dir.mkdir(parents=True, exist_ok=True)
    redundant = extract_single_root(
        IP_DIR / "redundant_link_core" / "redundant_link_core_source.zip",
        repo_dir / "redundant_link_core_source",
    ) / "rtl"
    sensor = extract_single_root(
        IP_DIR / "sensor_guard_ip" / "sensor_guard_ip_source.zip",
        repo_dir / "sensor_guard_ip_source",
    )
    voltage = extract_single_root(
        IP_DIR / "voltage_display_ip" / "voltage_display_ip_source.zip",
        repo_dir / "voltage_display_ip_source",
    ) / "packaged_ip" / "voltage_display_ip_1.0"
    paths = [redundant, sensor, voltage]
    for path in paths:
        if not (path / "component.xml").is_file():
            raise RuntimeError(f"Missing packaged-IP metadata: {path}")
    return paths


def main() -> int:
    BUILD_DIR.mkdir(parents=True, exist_ok=True)
    bd = reconstruct_bd()
    repos = prepare_ip_repositories()
    print(f"Validated final Block Design: {bd}")
    for repo in repos:
        print(f"Prepared IP repository: {repo}")
    print("Run Vivado 2024.2 with:")
    print("  vivado -mode batch -source hardware/vivado/scripts/create_project.tcl")
    if "--run-vivado" in sys.argv:
        subprocess.run(
            ["vivado", "-mode", "batch", "-source", str(VIVADO_DIR / "scripts" / "create_project.tcl")],
            cwd=ROOT,
            check=True,
        )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        raise SystemExit(1)
