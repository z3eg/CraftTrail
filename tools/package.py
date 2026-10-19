"""Package the runtime TOC files and a separate Engineering design preview."""
import argparse
import zipfile
from pathlib import Path

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--output', type=Path)
args = parser.parse_args()
toc = root / 'CraftTrail/CraftTrail.toc'
version = next(line.split(':', 1)[1].strip() for line in toc.read_text().splitlines() if line.startswith('## Version:'))
args.output = args.output or root / f'dist/CraftTrail-{version}.zip'
runtime = ['CraftTrail.toc', 'README.md'] + [line.strip() for line in toc.read_text().splitlines()
                                        if line.strip() and not line.startswith('#')]
args.output.parent.mkdir(parents=True, exist_ok=True)
with zipfile.ZipFile(args.output, 'w', zipfile.ZIP_DEFLATED) as archive:
    for name in runtime:
        archive.write(root / 'CraftTrail' / name, 'CraftTrail/' + name)
    archive.write(root / 'docs/engineering-preview.html', 'Engineering-preview.html')
    archive.write(root / 'docs/engineering-design.md', 'Engineering-design.md')
    archive.write(root / 'tools/Migrate-InkTrailSettings.ps1', 'Migrate-InkTrailSettings.ps1')
    archive.writestr('INSTALL.txt', 'Copy only the CraftTrail folder into Interface/AddOns.\n'
                     f'Restart WoW. Version: {version}. No server rebuild.\n'
                     'Upgrading from InkTrail: remove the old Interface/AddOns/InkTrail folder.\n'
                     'Optional settings migration with WoW closed: run Migrate-InkTrailSettings.ps1 -ClientPath <WoW directory>.\n'
                     'The in-game dependency tree supports all recipe professions.\n'
                     'Engineering-preview.html is the original separate browser design demonstration.\n')
with zipfile.ZipFile(args.output) as archive:
    assert archive.testzip() is None
    assert 'CraftTrail/CraftTrail.toc' in archive.namelist()
    assert not any(name.startswith('InkTrail/') for name in archive.namelist())
    assert 'CraftTrail/CraftTrail.lua' in archive.namelist()
    assert all('EngineeringData.lua' not in name for name in archive.namelist())
print(args.output)
