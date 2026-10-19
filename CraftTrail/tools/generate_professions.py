"""Generate the complete 3.3.5a crafting dependency catalog."""
import argparse
from pathlib import Path
from generate_engineering import generate

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--core-root', type=Path, required=True)
    parser.add_argument('--dbc-dir', type=Path, required=True)
    args = parser.parse_args()
    generate(args.core_root.resolve(), args.dbc_dir.resolve(), all_professions=True)
