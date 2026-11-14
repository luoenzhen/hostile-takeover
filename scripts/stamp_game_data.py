"""Apply the upstream release-version stamp without rebuilding the asset database."""
from pathlib import Path

path = Path(__file__).resolve().parents[1] / 'game' / 'htdata832.pdb'
data = path.read_bytes()
marker = b'+++VERSION+++'
assert data.count(marker) == 1, 'Expected exactly one upstream version placeholder'
offset = data.index(marker)
# The version record is uncompressed; keep all PDB record offsets unchanged.
assert data[offset-6:offset] == b'\x00\x00\x00\x0e\x00\x0e', 'Unexpected version record encoding'
stamped = data[:offset] + b'1.6'.ljust(len(marker), b'\x00') + data[offset+len(marker):]
assert len(stamped) == len(data)
path.write_bytes(stamped)
print('Stamped original game-data version 1.6; asset payload and record offsets preserved.')
