#!/usr/bin/env python3
"""Verify Rojo maps source text and server/client boundaries into the place."""
from pathlib import Path
import sys
import xml.etree.ElementTree as ET

root = ET.parse(sys.argv[1] if len(sys.argv) > 1 else 'build/vanilla-rpg.rbxlx').getroot()
instances = {}
def visit(element, path):
    for item in element.findall('Item'):
        props = item.find('Properties')
        name = props.find("*[@name='Name']").text
        here = path + '/' + name
        instances[here] = item
        visit(item, here)
visit(root, '')
expected = {}
for folder, prefix in [('shared', '/ReplicatedStorage/Shared'),
                        ('server', '/ServerScriptService/Server'),
                        ('client', '/StarterPlayer/StarterPlayerScripts/Client'),
                        ('character', '/StarterPlayer/StarterCharacterScripts')]:
    for source in (Path('src') / folder).glob('*.lua'):
        name = source.name.removesuffix('.lua').removesuffix('.server').removesuffix('.client')
        kind = 'Script' if '.server.' in source.name else 'LocalScript' if '.client.' in source.name else 'ModuleScript'
        expected[prefix + '/' + name] = (source, kind)
for path, (source, kind) in expected.items():
    item = instances[path]
    assert item.attrib['class'] == kind, path
    embedded = item.find("Properties/*[@name='Source']").text
    assert embedded == source.read_text(), 'Stale embedded source: ' + path
assert instances['/StarterPlayer/StarterCharacterScripts/Health'].attrib['class'] == 'Script'
assert instances['/Workspace/Spawn'].attrib['class'] == 'SpawnLocation'
assert not any('SessionStore' in path for path in instances if path.startswith('/ReplicatedStorage'))
print(f'Rojo mapping passed: {len(expected)} scripts match source; persistence stays server-only; spawn exists.')
