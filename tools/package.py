"""Package the runtime TOC files and a separate Engineering design preview."""
import argparse
import zipfile
from pathlib import Path

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--output', type=Path)
args = parser.parse_args()
toc = root / 'InkTrail/InkTrail.toc'
version = next(line.split(':', 1)[1].strip() for line in toc.read_text().splitlines() if line.startswith('## Version:'))
args.output = args.output or root / f'dist/CraftTrail-{version}.zip'
runtime = ['InkTrail.toc', 'README.md'] + [line.strip() for line in toc.read_text().splitlines()
                                        if line.strip() and not line.startswith('#')]
args.output.parent.mkdir(parents=True, exist_ok=True)
with zipfile.ZipFile(args.output, 'w', zipfile.ZIP_DEFLATED) as archive:
    for name in runtime:
        archive.write(root / 'InkTrail' / name, 'InkTrail/' + name)
    archive.write(root / 'docs/engineering-preview.html', 'Engineering-preview.html')
    archive.write(root / 'docs/engineering-design.md', 'Engineering-design.md')
    archive.writestr('INSTALL.txt', 'Copy only the InkTrail folder into Interface/AddOns.\n'
                     f'Restart WoW. Version: {version}. No server rebuild.\n'
                     'The in-game dependency tree supports all recipe professions.\n'
                     'Engineering-preview.html is the original separate browser design demonstration.\n')
with zipfile.ZipFile(args.output) as archive:
    assert archive.testzip() is None
    assert 'InkTrail/InkTrail.toc' in archive.namelist()
    assert all('EngineeringData.lua' not in name for name in archive.namelist())
print(args.output)
