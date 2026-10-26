"""Export verb hidden flags, which BYOND cannot reflect at runtime.

Run from the repository root. Normal tools/build builds run this automatically;
after changing `set hidden`, direct DreamMaker users should regenerate it first:
    python tools/statbrowser/hidden_verbs.py --compiler DreamMaker roguetown.dme
"""
import argparse
import json
from pathlib import Path
import re
import subprocess
import xml.etree.ElementTree as ET


def extract_settings(xml):
    root = ET.fromstring(xml[xml.index('<?xml'):])
    source_files = {}
    settings = {}

    def walk(node, owner=''):
        for child in node:
            if child.tag in ('object', 'obj', 'mob', 'area', 'turf'):
                walk(child, owner + '/' + child.text.strip())
            elif child.tag in ('proc', 'verb'):
                anchor = child.get('file')
                if not anchor:
                    continue
                filename, number = anchor.rsplit(':', 1)
                source = Path(filename.replace('\\', '/'))
                if not source.is_file():
                    continue
                if source not in source_files:
                    try:
                        text = source.read_text(encoding='utf-8-sig')
                    except UnicodeDecodeError:
                        text = source.read_text(encoding='cp1252')
                    source_files[source] = text.splitlines()
                lines = source_files[source]
                start = int(number) - 1
                # Macro-generated definitions can have virtual source positions.
                if start >= len(lines):
                    continue
                indent = len(lines[start]) - len(lines[start].lstrip())
                for line in lines[start + 1:]:
                    stripped = line.lstrip()
                    if stripped and len(line) - len(stripped) <= indent and not stripped.startswith(('//', '#')):
                        break
                    match = re.match(r'\s*set\s+hidden\s*=\s*(\w+)', line)
                    if match:
                        value = match[1]
                        if value not in ('0', '1', 'FALSE', 'TRUE'):
                            raise ValueError(f'Unsupported hidden setting: {anchor}: {line}')
                        settings[f'{owner}/{child.tag}/{child.text.strip()}'] = value in ('1', 'TRUE')

    walk(root)
    return dict(sorted(settings.items()))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('dme')
    parser.add_argument('--compiler', default='DreamMaker')
    parser.add_argument('--define', action='append', default=[])
    args = parser.parse_args()
    result = subprocess.run([args.compiler, '-o', *('-D' + value for value in args.define), args.dme],
                            capture_output=True, encoding='utf-8-sig', errors='replace', check=True)
    settings = extract_settings(result.stdout)
    if not settings:
        raise ValueError('Compiler returned no hidden settings')
    target = Path('html/statbrowser_hidden_verbs.json')
    content = json.dumps(settings, indent=2) + '\n'
    if not target.exists() or target.read_text() != content:
        target.write_text(content, encoding='utf-8', newline='\n')
    print(f'Exported {len(settings)} verb visibility settings')


if __name__ == '__main__':
    main()
