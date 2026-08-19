#!/usr/bin/env python3
"""Convert Claude Design Skillstack plugins into Cursor plugins and install them.

Reads plugins/individual/* plus .claude-plugin/marketplace.json, writes Cursor
manifests (.cursor-plugin/plugin.json), adds required YAML frontmatter to agents
and commands, then copies each plugin to ~/.cursor/plugins/local/<name>/.
"""

from __future__ import annotations

import json
import os
import re
import shutil
import sys
from pathlib import Path

REPO_URL = "https://github.com/shannonjlove/claudedesignskills"
DEFAULT_LOCAL_ROOT = Path.home() / ".cursor" / "plugins" / "local"

DISPLAY_NAMES = {
    "aframe-webxr": "A-Frame WebXR",
    "animated-component-libraries": "Animated Component Libraries",
    "animejs": "Anime.js",
    "babylonjs-engine": "Babylon.js",
    "barba-js": "Barba.js",
    "blender-web-pipeline": "Blender Web Pipeline",
    "gsap-scrolltrigger": "GSAP ScrollTrigger",
    "lightweight-3d-effects": "Lightweight 3D Effects",
    "locomotive-scroll": "Locomotive Scroll",
    "lottie-animations": "Lottie Animations",
    "modern-web-design": "Modern Web Design",
    "motion-framer": "Framer Motion",
    "pixijs-2d": "PixiJS 2D",
    "playcanvas-engine": "PlayCanvas",
    "react-spring-physics": "React Spring Physics",
    "react-three-fiber": "React Three Fiber",
    "rive-interactive": "Rive Interactive",
    "scroll-reveal-libraries": "Scroll Reveal Libraries",
    "spline-interactive": "Spline Interactive",
    "substance-3d-texturing": "Substance 3D Texturing",
    "threejs-webgl": "Three.js WebGL",
    "web3d-integration-patterns": "Web3D Integration Patterns",
}

CURSOR_CATEGORY = {
    "3d-graphics": "developer-tools",
    "2d-graphics": "developer-tools",
    "animation": "developer-tools",
    "components": "developer-tools",
    "scroll": "developer-tools",
    "transitions": "developer-tools",
    "3d-authoring": "developer-tools",
    "integration": "developer-tools",
    "design": "developer-tools",
    "bundle": "developer-tools",
}


def default_repo_root() -> Path:
    return Path(__file__).resolve().parents[2]


def load_marketplace(root: Path) -> dict:
    path = root / ".claude-plugin" / "marketplace.json"
    with path.open(encoding="utf-8") as handle:
        return json.load(handle)


def kebab_to_title(name: str) -> str:
    return DISPLAY_NAMES.get(name, name.replace("-", " ").title())


def first_paragraph_after(heading: str, text: str) -> str:
    pattern = rf"^## {re.escape(heading)}\s*\n+(.+?)(?:\n\n|\n## |\Z)"
    match = re.search(pattern, text, flags=re.MULTILINE | re.DOTALL)
    if not match:
        return ""
    return " ".join(match.group(1).strip().split())


def ensure_frontmatter(path: Path, name: str, description: str) -> bool:
    original = path.read_text(encoding="utf-8")
    if original.lstrip().startswith("---"):
        return False
    body = original.lstrip()
    desc = description.replace("\n", " ").strip()
    if len(desc) > 280:
        desc = desc[:277].rstrip() + "..."
    front = f"---\nname: {name}\ndescription: {desc}\n---\n\n"
    path.write_text(front + body, encoding="utf-8")
    return True


def command_name(plugin_name: str, command_path: Path) -> str:
    return f"{plugin_name}-{command_path.stem}"


def write_plugin_manifest(plugin_dir: Path, entry: dict, license_text: str) -> dict:
    claude_manifest_path = plugin_dir / ".claude-plugin" / "plugin.json"
    claude = {}
    if claude_manifest_path.exists():
        with claude_manifest_path.open(encoding="utf-8") as handle:
            claude = json.load(handle)

    name = entry["name"]
    description = entry.get("description") or claude.get("description") or kebab_to_title(name)
    author = entry.get("author") or claude.get("author") or {
        "name": "Claude Design Skillstack",
        "email": "oladotun.olatunji@gmail.com",
    }
    keywords = claude.get("keywords") or entry.get("tags") or [name]
    tags = entry.get("tags") or keywords
    category = CURSOR_CATEGORY.get(entry.get("category", ""), "developer-tools")

    skills_dir = plugin_dir / "skills"
    agents_dir = plugin_dir / "agents"
    commands_dir = plugin_dir / "commands"

    for agent_path in sorted(agents_dir.glob("*.md")) if agents_dir.exists() else []:
        role = first_paragraph_after("Role", agent_path.read_text(encoding="utf-8"))
        ensure_frontmatter(
            agent_path,
            agent_path.stem,
            role or f"{kebab_to_title(name)} specialist. Use for {name} architecture and implementation.",
        )

    for command_path in sorted(commands_dir.glob("*.md")) if commands_dir.exists() else []:
        text = command_path.read_text(encoding="utf-8")
        desc = first_paragraph_after("Description", text)
        if not desc:
            first_line = next((line.strip("# ").strip() for line in text.splitlines() if line.strip()), "")
            desc = first_line or f"Run the {command_path.stem} command for {kebab_to_title(name)}."
        ensure_frontmatter(command_path, command_name(name, command_path), desc)

    cursor_plugin = {
        "name": name,
        "displayName": kebab_to_title(name),
        "version": entry.get("version") or claude.get("version") or "1.0.0",
        "description": description,
        "author": author,
        "homepage": REPO_URL,
        "repository": REPO_URL,
        "license": "MIT",
        "keywords": keywords,
        "category": category,
        "tags": tags,
    }
    if skills_dir.exists():
        cursor_plugin["skills"] = "./skills/"
    if agents_dir.exists():
        cursor_plugin["agents"] = "./agents/"
    if commands_dir.exists():
        cursor_plugin["commands"] = "./commands/"

    cursor_dir = plugin_dir / ".cursor-plugin"
    cursor_dir.mkdir(exist_ok=True)
    (cursor_dir / "plugin.json").write_text(
        json.dumps(cursor_plugin, indent=2) + "\n",
        encoding="utf-8",
    )

    readme_path = plugin_dir / "README.md"
    if not readme_path.exists():
        skill_names = [p.name for p in skills_dir.iterdir() if p.is_dir()] if skills_dir.exists() else []
        agent_names = [p.stem for p in agents_dir.glob("*.md")] if agents_dir.exists() else []
        command_names = [p.stem for p in commands_dir.glob("*.md")] if commands_dir.exists() else []
        readme = [
            f"# {kebab_to_title(name)}",
            "",
            description,
            "",
            "## Installation",
            "",
            "Install locally for Cursor:",
            "",
            "```bash",
            "python3 scripts/cursor/install_cursor_plugins.py --plugin " + name,
            "```",
            "",
            f"Source: {REPO_URL}",
            "",
            "## Components",
            "",
            f"- Skills: {', '.join(skill_names) or 'none'}",
            f"- Agents: {', '.join(agent_names) or 'none'}",
            f"- Commands: {', '.join(command_names) or 'none'}",
            "",
        ]
        readme_path.write_text("\n".join(readme), encoding="utf-8")

    license_path = plugin_dir / "LICENSE"
    if not license_path.exists():
        license_path.write_text(license_text, encoding="utf-8")

    return cursor_plugin


def copy_to_local(plugin_dir: Path, dest_root: Path) -> Path:
    dest = dest_root / plugin_dir.name
    if dest.exists():
        shutil.rmtree(dest)
    dest_root.mkdir(parents=True, exist_ok=True)
    shutil.copytree(
        plugin_dir,
        dest,
        ignore=shutil.ignore_patterns(".git"),
    )
    return dest


def write_cursor_marketplace(root: Path, entries: list[dict]) -> Path:
    marketplace = {
        "name": "claude-design-skillstack",
        "owner": {
            "name": "Shannon J. Love",
            "email": "sjlove@shannonjeffreylove.com",
        },
        "metadata": {
            "description": (
                "Cursor marketplace for the Claude Design Skillstack: 3D/WebGL, "
                "animation, and modern web development plugins."
            ),
            "version": "1.0.0",
            "homepage": REPO_URL,
            "repository": REPO_URL,
        },
        "plugins": entries,
    }
    cursor_dir = root / ".cursor-plugin"
    cursor_dir.mkdir(exist_ok=True)
    path = cursor_dir / "marketplace.json"
    path.write_text(json.dumps(marketplace, indent=2) + "\n", encoding="utf-8")
    return path


def write_catalog_plugin(root: Path, dest_root: Path, plugins: list[dict]) -> Path:
    catalog_name = "claude-design-skillstack"
    catalog_dir = dest_root / catalog_name
    if catalog_dir.exists():
        shutil.rmtree(catalog_dir)

    skills_dir = catalog_dir / "skills" / catalog_name
    skills_dir.mkdir(parents=True)
    (catalog_dir / ".cursor-plugin").mkdir()

    lines = [
        "---",
        "name: claude-design-skillstack",
        "description: Catalog of connected Claude Design Skillstack plugins for 3D/WebGL, animation, scroll, and modern web design. Use when choosing among Three.js, GSAP, React Three Fiber, Framer Motion, Babylon.js, Lottie, Rive, or related skills, or when installing the shannonjlove/claudedesignskills marketplace.",
        "---",
        "",
        "# Claude Design Skillstack",
        "",
        f"Connected marketplace: {REPO_URL}",
        "",
        "Load the matching plugin skill before implementing 3D, animation, or interactive web work. Plugins are installed under `~/.cursor/plugins/local/<plugin-name>/`.",
        "",
        "## Plugins",
        "",
    ]
    for plugin in plugins:
        lines.append(f"- **{plugin['name']}** — {plugin['description']}")
    lines.extend(
        [
            "",
            "## Reinstall",
            "",
            "```bash",
            "python3 scripts/cursor/install_cursor_plugins.py",
            "```",
            "",
        ]
    )
    (skills_dir / "SKILL.md").write_text("\n".join(lines), encoding="utf-8")

    manifest = {
        "name": catalog_name,
        "displayName": "Claude Design Skillstack",
        "version": "1.0.0",
        "description": "Catalog and installer index for the Claude Design Skillstack Cursor plugins.",
        "author": {"name": "Shannon J. Love", "email": "sjlove@shannonjeffreylove.com"},
        "homepage": REPO_URL,
        "repository": REPO_URL,
        "license": "MIT",
        "keywords": ["design", "3d", "animation", "webgl", "marketplace"],
        "category": "developer-tools",
        "tags": ["design", "skills", "marketplace"],
        "skills": "./skills/",
    }
    (catalog_dir / ".cursor-plugin" / "plugin.json").write_text(
        json.dumps(manifest, indent=2) + "\n", encoding="utf-8"
    )
    (catalog_dir / "README.md").write_text(
        "# Claude Design Skillstack\n\n"
        "Cursor catalog plugin for the connected Claude Design Skillstack marketplace.\n\n"
        f"Source: {REPO_URL}\n",
        encoding="utf-8",
    )
    shutil.copyfile(root / "LICENSE", catalog_dir / "LICENSE")
    return catalog_dir


def main(argv: list[str]) -> int:
    root = default_repo_root()
    dest_root = Path(os.environ.get("CURSOR_PLUGIN_LOCAL_ROOT", DEFAULT_LOCAL_ROOT))
    only_plugin = None
    install_local = True
    args = argv[1:]
    while args:
        arg = args.pop(0)
        if arg == "--plugin":
            only_plugin = args.pop(0)
        elif arg == "--dest":
            dest_root = Path(args.pop(0))
        elif arg == "--root":
            root = Path(args.pop(0)).resolve()
        elif arg == "--no-install":
            install_local = False
        elif arg in {"-h", "--help"}:
            print(
                "Usage: install_cursor_plugins.py [--root DIR] [--plugin NAME] [--dest DIR] [--no-install]",
                file=sys.stderr,
            )
            return 0
        else:
            print(f"Unknown argument: {arg}", file=sys.stderr)
            return 2

    marketplace = load_marketplace(root)
    license_text = (root / "LICENSE").read_text(encoding="utf-8")
    individual_dir = root / "plugins" / "individual"
    cursor_entries = []
    installed = []

    for entry in marketplace["plugins"]:
        name = entry["name"]
        source = entry.get("source", "")
        if "/bundles/" in source:
            continue
        if only_plugin and name != only_plugin:
            continue
        plugin_dir = (root / source).resolve()
        if not plugin_dir.is_dir():
            plugin_dir = individual_dir / name
        if not plugin_dir.is_dir():
            print(f"skip missing plugin: {name}", file=sys.stderr)
            continue
        cursor_plugin = write_plugin_manifest(plugin_dir, entry, license_text)
        cursor_entries.append(
            {
                "name": name,
                "source": f"./plugins/individual/{name}",
                "description": cursor_plugin["description"],
                "keywords": cursor_plugin.get("keywords", []),
                "category": entry.get("category", "developer-tools"),
                "tags": cursor_plugin.get("tags", []),
            }
        )
        if install_local:
            dest = copy_to_local(plugin_dir, dest_root)
            installed.append(str(dest))

    if not only_plugin:
        write_cursor_marketplace(root, cursor_entries)
        if install_local:
            catalog = write_catalog_plugin(root, dest_root, cursor_entries)
            installed.append(str(catalog))

    print(f"converted {len(cursor_entries)} plugins")
    for path in installed:
        print(f"installed {path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
