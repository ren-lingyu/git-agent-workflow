import copy
import errno
import hashlib
import json
import os
from pathlib import Path
import shutil
import socket
import subprocess
import sys

from frictionless import Package, Resource
from jsonschema import Draft7Validator, FormatChecker

root = Path.cwd()
inputs = Path(sys.argv[1])
schema_path = Path(sys.argv[2])
rscript = sys.argv[3]
rprobe = sys.argv[4]
results = []

def observe(case, operation):
    try:
        value = operation()
        results.append({'case': case, 'result': value})
    except Exception as exc:
        results.append({'case': case, 'error': type(exc).__name__ + ': ' + str(exc)[:1500]})

# An ordinary Nix derivation must have no non-loopback network route.
sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
try:
    sock.connect(('192.0.2.1', 9))
except OSError as exc:
    assert exc.errno == errno.ENETUNREACH, exc
    results.append({'case': 'network-denial', 'result': 'ENETUNREACH; no external route'})
else:
    raise AssertionError('Network isolation not established')
finally:
    sock.close()

schema = json.loads(schema_path.read_text())
assert hashlib.sha256(schema_path.read_bytes()).hexdigest() == 'a9ef0fc168b3402ae7aa7d22bbcb798e0db6b639e7ee15ff4aa177463cea7112'
Draft7Validator.check_schema(schema)
validator = Draft7Validator(schema, format_checker=FormatChecker())

def structure(descriptor):
    return [str(e.message) for e in validator.iter_errors(descriptor)]

multi = ['tmp/doc-01-file-url-probe.el', 'tmp/doc-01-file-url-probe.scm', 'tmp/doc-01-file-url-probe.txt']
roles = ['runner', 'query', 'output']

def create(name, selected, roles):
    directory = root / name
    directory.mkdir()
    resources = []
    for index, relative in enumerate(selected):
        target = directory / 'files' / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(inputs / relative, target)
        resources.append(Resource.from_descriptor({
            'name': 'artifact-' + str(index), 'type': 'file',
            'path': 'files/' + relative, 'description': roles[index],
            'originalPath': relative, 'role': roles[index],
            'evidence': {'state': 'historical snapshot', 'limits': ['not a new experiment']}
        }).to_descriptor())
    package = Package.from_descriptor({
        '$schema': 'https://datapackage.org/profiles/2.0/datapackage.json',
        'name': name, 'title': 'Historical archive test',
        'description': 'Selected historical evidence; isolated candidate comparison',
        'resources': resources, 'capturePurpose': 'tool comparison',
        'relations': [{'source': 'artifact-0', 'target': 'artifact-1'}] if len(selected) > 1 else []
    }, basepath=str(directory))
    descriptor = package.to_descriptor()
    native_errors = structure(descriptor)
    # Minimal version adapter: DP 2.0 ordinary files omit the old file type.
    for resource in descriptor['resources']:
        resource.pop('type', None)
    assert not structure(descriptor), structure(descriptor)
    (directory / 'datapackage.json').write_text(json.dumps(descriptor, ensure_ascii=False, indent=2))
    results.append({'case': 'native-versus-adapted-' + name,
                    'result': {'native_2_0_errors': native_errors, 'adapter': 'omit legacy type=file', 'adapted_errors': structure(descriptor)}})
    for relative in selected:
        assert (inputs / relative).read_bytes() == (directory / 'files' / relative).read_bytes()
    return directory

directories = {name: create(name, selected, role) for name, selected, role in [
    ('multi', multi, roles), ('single', ['PLAN.md'], ['historical planning document']),
    ('single-second', ['PLAN.md'], ['historical planning document'])
]}
for name, directory in directories.items():
    def check(directory=directory):
        package = Package(str(directory / 'datapackage.json'))
        return {'resource_count': len(package.resources),
                'metadata_bytes': (directory / 'datapackage.json').stat().st_size,
                'roles': [r.custom['role'] for r in package.resources],
                'read_bytes': [len(r.read_bytes()) for r in package.resources],
                'official_2_0_errors': structure(json.loads((directory / 'datapackage.json').read_text())),
                'frictionless_validation': package.validate().to_descriptor()}
    observe('python-create-read-' + name, check)

original = json.loads((directories['multi'] / 'datapackage.json').read_text())
def python_edit():
    package = Package.from_descriptor(original, basepath=str(directories['multi']))
    package.title = 'Edited title'
    package.get_resource('artifact-0').description = 'Edited runner'
    package.to_json(str(root / 'python-edited.json'))
    reread = Package(str(root / 'python-edited.json'))
    assert reread.custom['relations'] == original['relations']
    assert reread.get_resource('artifact-0').custom['evidence'] == original['resources'][0]['evidence']
    return {'custom_fields_retained': True, 'native_reexport_errors': structure(json.loads((root / 'python-edited.json').read_text()))}
observe('python-edit', python_edit)

mutations = {
    'missing-resources': lambda d: d.pop('resources'),
    'wrong-title-type': lambda d: d.update(title=42),
    'wrong-schema-type': lambda d: d.update({'$schema': 42}),
    'wrong-contributor-roles': lambda d: d.update(contributors=[{'title': 'Example', 'roles': 42}]),
    'missing-file': lambda d: d['resources'][0].update(path='files/not-present.txt'),
    'traversal': lambda d: d['resources'][0].update(path='../canary.txt'),
    'absolute': lambda d: d['resources'][0].update(path=str(root / 'canary.txt')),
    'dangling-custom-relation': lambda d: d['relations'][0].update(target='not-present'),
    'remote-resource': lambda d: d['resources'][0].update(path='https://example.invalid/unavailable.txt', scheme='https'),
}
(root / 'canary.txt').write_text('disposable boundary canary')
for name, mutate in mutations.items():
    descriptor = copy.deepcopy(original)
    mutate(descriptor)
    def check(descriptor=descriptor):
        answer = {'official_schema_errors': structure(descriptor)}
        try:
            package = Package.from_descriptor(descriptor, basepath=str(directories['multi']))
            answer['frictionless_valid'] = package.validate().valid
            if package.resources:
                try:
                    answer['read_result'] = package.resources[0].read_bytes().decode(errors='replace')[:150]
                except Exception as exc:
                    answer['read_error'] = str(exc)[:300]
        except Exception as exc:
            answer['frictionless_error'] = str(exc)[:500]
        return answer
    observe('python-negative-' + name, check)

bad = root / 'broken.json'
bad.write_text('{')
observe('python-broken-json', lambda: Package(str(bad)).to_descriptor())

def special_paths():
    directory = root / 'special'
    directory.mkdir()
    info = []
    for i, path in enumerate(['files/tmp/space name.txt', 'files/tmp/中文.txt', 'files/tmp/100%.txt', 'files/a/same.txt', 'files/b/same.txt', 'files/tmp/datapackage.json']):
        target = directory / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(path.encode())
        resource = Resource.from_descriptor({'name': 'special-' + str(i), 'type': 'file', 'path': path}, basepath=str(directory))
        assert resource.read_bytes() == path.encode()
        info.append(resource.to_descriptor())
    return {'paths': [r['path'] for r in info], 'byte_roundtrip': True}
observe('python-special-paths', special_paths)

def symlink_read():
    link = directories['multi'] / 'files' / 'link.txt'
    link.symlink_to(root / 'canary.txt')
    resource = Resource.from_descriptor({'name': 'link', 'type': 'file', 'path': 'files/link.txt'}, basepath=str(directories['multi']))
    return {'read': resource.read_bytes().decode(), 'boundary_escape': True}
observe('python-symlink-default', symlink_read)

def inventory(directory):
    return {str(p.relative_to(directory)): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in directory.rglob('*') if p.is_file() and not p.is_symlink()}
before = inventory(directories['single'])
Package(str(directories['single'] / 'datapackage.json')).validate()
assert before == inventory(directories['single'])
results.append({'case': 'python-validation-side-effects', 'result': 'none in snapshot tree'})

# Capture checks are project policy, distinct from candidate metadata validation.
def capture_checks():
    source = root / 'capture-source.txt'
    source.write_bytes(b'original')
    initial = source.read_bytes()
    target = root / 'capture-target.txt'
    target.write_bytes(initial)
    assert target.read_bytes() == initial == source.read_bytes()
    target.write_bytes(initial[:3])
    assert target.read_bytes() != initial
    target.write_bytes(b'changed!')
    assert target.read_bytes() != initial
    target.write_bytes(initial)
    source.write_bytes(b'mutated')
    assert source.read_bytes() != initial
    return ['exact copy accepted', 'truncation detected', 'target edit detected', 'controlled source mutation detected']
observe('project-capture-checks', capture_checks)

def capture_boundary():
    safe_root = directories['single']
    def checked(path):
        relative = Path(path)
        if relative.is_absolute() or '..' in relative.parts:
            raise ValueError('unsafe selection')
        target = safe_root / relative
        for part in [target, *target.parents]:
            if part.is_symlink():
                raise ValueError('symlink rejected')
            if part == safe_root:
                break
        target.resolve().relative_to(safe_root.resolve())
        return target
    (safe_root / 'files' / 'ancestor-link').symlink_to(root, target_is_directory=True)
    rejected = []
    for path in ['../canary.txt', str(root / 'canary.txt'), 'files/ancestor-link/canary.txt']:
        try:
            checked(path)
        except ValueError:
            rejected.append(path)
        else:
            raise AssertionError('Unsafe capture path accepted')
    assert checked('files/PLAN.md').is_file()
    return {'rejected_count': len(rejected), 'safe_relative_file': 'accepted'}
observe('project-capture-boundary', capture_boundary)

def editing_adapted_roundtrip():
    package = Package.from_descriptor(original, basepath=str(directories['multi']))
    removed = package.remove_resource('artifact-2')
    assert len(package.resources) == 2
    package.add_resource(removed)
    package.custom['relations'] = []
    package.get_resource('artifact-0').custom['role'] = 'edited runner'
    descriptor = package.to_descriptor()
    for resource in descriptor['resources']:
        if resource.get('type') in ('file', 'text'):
            del resource['type']
    assert structure(descriptor) == []
    output = root / 'adapted-edited.json'
    output.write_text(json.dumps(descriptor))
    reread = Package(str(output))
    assert len(reread.resources) == 3
    assert reread.custom['relations'] == []
    assert reread.get_resource('artifact-0').custom['role'] == 'edited runner'
    return {'add_remove_edit_relations': True, 'official_schema_errors': [],
            'reexport_adapter': 'omit legacy type=file/text on every export'}
observe('python-adapted-edit-roundtrip', editing_adapted_roundtrip)

completed = subprocess.run([rscript, '--vanilla', rprobe, str(root)], capture_output=True, text=True, timeout=30)
(root / 'r-stdout.txt').write_text(completed.stdout)
(root / 'r-stderr.txt').write_text(completed.stderr)
assert completed.returncode == 0, completed.stderr
if (root / 'r-edited' / 'datapackage.json').exists():
    def reread_r():
        package = Package(str(root / 'r-edited' / 'datapackage.json'))
        return {'paths': [r.path for r in package.resources],
                'relations': package.custom.get('relations'),
                'title': package.title, 'official_errors': structure(json.loads((root / 'r-edited' / 'datapackage.json').read_text()))}
    observe('python-r-python-roundtrip', reread_r)
    def cross_custom_types():
        descriptor = json.loads((root / 'r-edited' / 'datapackage.json').read_text())
        after = descriptor['resources'][0]['evidence']['limits']
        before = original['resources'][0]['evidence']['limits']
        return {'before': before, 'after': after, 'same_type': type(before) is type(after)}
    observe('r-custom-type-preservation', cross_custom_types)

def output_integrity():
    answer = {}
    for directory in ['multi', 'r-edited', 'r-rocrate-multi']:
        for relative in multi:
            target = root / directory / ('files/' + relative if directory != 'r-edited' else Path(relative).name)
            assert target.read_bytes() == (inputs / relative).read_bytes()
        answer[directory] = 'all three original files byte-identical'
    single = root / 'r-rocrate-single/files/PLAN.md'
    assert single.read_bytes() == (inputs / 'PLAN.md').read_bytes()
    return answer
observe('cross-tool-payload-integrity', output_integrity)

(root / 'python-results.json').write_text(json.dumps(results, ensure_ascii=False, indent=2))
print(json.dumps(results, ensure_ascii=False, indent=2))
