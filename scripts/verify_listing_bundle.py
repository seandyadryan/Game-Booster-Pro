import hashlib
import json
import sys
from pathlib import Path
from zipfile import ZipFile


archive = Path(sys.argv[1])
with ZipFile(archive) as bundle:
    prefix = 'latest/'
    report = json.loads(bundle.read(prefix + 'asset-validation.json'))
    assert len(report['locales']) == 29
    assert report['consoleApplied'] is False
    provenance = json.loads(bundle.read(prefix + 'capture-provenance.json'))
    assert provenance['runtime']['sha256'] == report['runtimeSha256']
    assert provenance['androidDeviceVerified'] is False
    assert provenance['consoleApplied'] is False
    release = json.loads(bundle.read(prefix + 'release-verification.json'))
    assert release['appPackage'] == report['appPackage']
    assert release['label'] == 'Game Tools'
    assert release['versionCode'].isdigit()
    assert release['runtimeSha256'] == report['runtimeSha256']
    assert release['signatureVerified'] is True
    assert release['debugCertificate'] is False
    assert release['consoleSubmitted'] is False
    assert release['androidDeviceVerified'] is False
    combined = bundle.read(prefix + 'ALL_LANGUAGES.md').decode('utf-8')
    for locale, entry in report['locales'].items():
        assert '<' + locale + '>' in combined
        assert '</' + locale + '>' in combined
        for field, limit in [('title', 30), ('short_description', 80), ('full_description', 4000)]:
            data = bundle.read(prefix + entry['metadataDirectory'] + '/' + field + '.txt')
            assert len(data.decode('utf-8').rstrip()) <= limit
    for asset in report['assets']:
        data = bundle.read(prefix + asset['file'])
        assert hashlib.sha256(data).hexdigest() == asset['sha256']
        assert len(data) == asset['bytes']
        if '/phone/' in asset['file'] or '/desktop/' in asset['file']:
            relative = asset['file'].removeprefix('assets/')
            assert provenance['screenshots'][relative] == asset['sha256']
    custom = json.loads(bundle.read(prefix + 'custom-store-listings/apply-to-existing-listings.json'))
    assert custom['status'] == 'prepared_locally_not_applied_to_play_console'
    images = [name for name in bundle.namelist() if name.endswith('.png')]
    assert len(images) == 12
    assert all('ai-network' not in name and 'gfx-tools' not in name and 'fps' not in name for name in images)
    assert bundle.testzip() is None
print('ZIP verified: 29 locales, all language tags, 12 images, capture provenance and explicit local-only status.')
