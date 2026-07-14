#!/usr/bin/env python3
"""
Stash Podman Quadlet Generator

Generates customized .container quadlet files from a configuration template.
Usage: python3 generate-quadlet.py <config_file> [output_file]
"""

import sys
import os
import re
from pathlib import Path
from typing import Dict, Tuple

class QuadletGenerator:
    def __init__(self, template_path: str, config_path: str, output_path: str = None):
        """Initialize generator with template and config files."""
        self.template_path = Path(template_path)
        self.config_path = Path(config_path)

        # Default output path
        if output_path:
            self.output_path = Path(output_path)
        else:
            config_name = self.config_path.stem
            self.output_path = self.config_path.parent / f"{config_name}.container"

        self.config: Dict[str, str] = {}
        self.template: str = ""

    def load_template(self) -> bool:
        """Load template file."""
        try:
            with open(self.template_path, 'r') as f:
                self.template = f.read()
            print(f"✓ Template loaded: {self.template_path}")
            return True
        except FileNotFoundError:
            print(f"✗ Template not found: {self.template_path}", file=sys.stderr)
            return False

    def load_config(self) -> bool:
        """Load configuration file."""
        try:
            with open(self.config_path, 'r') as f:
                for line in f:
                    line = line.strip()
                    # Skip empty lines and comments
                    if not line or line.startswith('#'):
                        continue

                    if '=' in line:
                        key, value = line.split('=', 1)
                        self.config[key.strip()] = value.strip()

            print(f"✓ Config loaded: {self.config_path}")
            print(f"  Found {len(self.config)} configuration variables")
            return True
        except FileNotFoundError:
            print(f"✗ Config not found: {self.config_path}", file=sys.stderr)
            return False

    def validate_config(self) -> Tuple[bool, list]:
        """Validate that all required variables are present."""
        required_vars = [
            'DESCRIPTION', 'CONTAINER_NAME', 'IMAGE', 'IMAGE_TAG',
            'PORT', 'TIMEZONE', 'RESTART_SEC', 'PULL_POLICY',
            'CONFIG_PATH', 'DATA_PATH', 'METADATA_PATH', 'CACHE_PATH',
            'BLOBS_PATH', 'GENERATED_PATH', 'STASH_DATA_PATH',
            'STASH_GENERATED_PATH', 'STASH_METADATA_PATH', 'STASH_CACHE_PATH',
            'INSTALL_TARGET'
        ]

        missing = [var for var in required_vars if var not in self.config]

        if missing:
            print(f"✗ Missing configuration variables:", file=sys.stderr)
            for var in missing:
                print(f"  - {var}", file=sys.stderr)
            return False, missing

        return True, []

    def generate(self) -> str:
        """Generate quadlet content from template and config."""
        result = self.template

        # Replace all variables
        for key, value in self.config.items():
            placeholder = f"{{{{{key}}}}}"
            result = result.replace(placeholder, value)

        # Find any unreplaced variables
        unreplaced = re.findall(r'{{[A-Z_]+}}', result)
        if unreplaced:
            print(f"⚠ Warning: Unreplaced variables: {', '.join(set(unreplaced))}")

        return result

    def write_output(self, content: str) -> bool:
        """Write generated content to output file."""
        try:
            self.output_path.parent.mkdir(parents=True, exist_ok=True)
            with open(self.output_path, 'w') as f:
                f.write(content)

            # Make executable-like permissions (not strictly needed but good practice)
            os.chmod(self.output_path, 0o644)

            print(f"✓ Quadlet generated: {self.output_path}")
            return True
        except IOError as e:
            print(f"✗ Failed to write output: {e}", file=sys.stderr)
            return False

    def preview(self, content: str, lines: int = 10) -> None:
        """Show preview of generated content."""
        print(f"\n--- Preview (first {lines} lines) ---")
        preview_lines = content.split('\n')[:lines]
        for i, line in enumerate(preview_lines, 1):
            print(f"{i:2d}: {line}")
        if len(content.split('\n')) > lines:
            print(f"... ({len(content.split(chr(10))) - lines} more lines)")
        print("---\n")

    def run(self, preview: bool = False) -> bool:
        """Run the complete generation process."""
        print("Stash Podman Quadlet Generator")
        print("=" * 40)
        print()

        # Load files
        if not self.load_template():
            return False
        if not self.load_config():
            return False

        # Validate config
        valid, missing = self.validate_config()
        if not valid:
            return False

        # Generate
        print("\n✓ Validation passed")
        content = self.generate()

        # Preview if requested
        if preview:
            self.preview(content)

        # Write output
        if not self.write_output(content):
            return False

        print()
        print("Generation complete!")
        print(f"Next steps:")
        print(f"  1. Review: cat {self.output_path}")
        print(f"  2. Install: cp {self.output_path} ~/.config/containers/systemd/")
        print(f"  3. Start: systemctl --user daemon-reload && systemctl --user enable --now {self.output_path.name}")

        return True


def print_usage():
    """Print usage information."""
    print("Usage: python3 generate-quadlet.py <config_file> [options]")
    print()
    print("Arguments:")
    print("  <config_file>       Configuration file (e.g., stash.config)")
    print()
    print("Options:")
    print("  -o, --output FILE   Output file (default: <config_name>.container)")
    print("  -p, --preview       Show preview before writing")
    print("  -h, --help          Show this help message")
    print()
    print("Examples:")
    print("  # Generate with default output name")
    print("  python3 generate-quadlet.py stash.config")
    print()
    print("  # Generate with custom output")
    print("  python3 generate-quadlet.py stash.config -o my-stash.container")
    print()
    print("  # Generate with preview")
    print("  python3 generate-quadlet.py stash.config -p")


def main():
    """Main entry point."""
    # Check for help first
    if len(sys.argv) > 1 and sys.argv[1] in ['-h', '--help', 'help']:
        print_usage()
        sys.exit(0)

    # Check arguments
    if len(sys.argv) < 2:
        print_usage()
        sys.exit(1)

    # Parse arguments
    config_file = sys.argv[1]
    output_file = None
    preview = False

    i = 2
    while i < len(sys.argv):
        arg = sys.argv[i]
        if arg in ['-h', '--help']:
            print_usage()
            sys.exit(0)
        elif arg in ['-o', '--output']:
            if i + 1 < len(sys.argv):
                output_file = sys.argv[i + 1]
                i += 1
            else:
                print("Error: --output requires an argument", file=sys.stderr)
                sys.exit(1)
        elif arg in ['-p', '--preview']:
            preview = True
        else:
            print(f"Error: Unknown option: {arg}", file=sys.stderr)
            sys.exit(1)
        i += 1

    # Find template
    script_dir = Path(__file__).parent
    template_file = script_dir / "quadlet" / "stash.container.template"
    config_path = Path(config_file)

    # Check if config file exists
    if not config_path.exists():
        print(f"Error: Config file not found: {config_file}", file=sys.stderr)
        print(f"Tip: Copy stash.config.template to {config_file} and customize", file=sys.stderr)
        sys.exit(1)

    # Run generator
    generator = QuadletGenerator(str(template_file), config_file, output_file)
    if not generator.run(preview=preview):
        sys.exit(1)


if __name__ == '__main__':
    main()
