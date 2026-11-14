"""Reject incomplete, simulator-only, or incorrectly wrapped iPhone packages."""
import plistlib
import struct
import sys
import zipfile

def validate(path):
    with zipfile.ZipFile(path) as archive:
        names = archive.namelist()
        plists = [n for n in names if n.startswith('Payload/') and n.count('/') == 2 and n.endswith('.app/Info.plist')]
        assert len(plists) == 1, 'IPA must contain one Payload/*.app/Info.plist'
        root = plists[0].rsplit('/', 1)[0] + '/'
        info = plistlib.loads(archive.read(plists[0]))
        executable = archive.read(root + info['CFBundleExecutable'])
        assert executable[:4] == b'\xcf\xfa\xed\xfe', 'Expected 64-bit Mach-O executable'
        assert struct.unpack_from('<I', executable, 4)[0] == 0x0100000C, 'Expected arm64 device architecture'
        assert info['CFBundlePackageType'] == 'APPL'
        assert info.get('CFBundleSupportedPlatforms') == ['iPhoneOS'], 'Simulator apps cannot be sideloaded'
        for asset in ('htdata832.pdb', 'htsfx.pdb'):
            assert archive.getinfo(root + asset).file_size > 100_000, f'Missing/incomplete {asset}'
        assert root + 'OPEN_SOURCE_LICENSE.txt' in names
        print(f'Validated arm64 iPhone IPA: {len(executable):,} executable bytes; full game and audio data included.')

if __name__ == '__main__':
    validate(sys.argv[1])
