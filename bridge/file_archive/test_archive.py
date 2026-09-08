"""Exercise the real native ABI with disposable, non-game archive fixtures."""
import argparse
import ctypes
import io
import os
from pathlib import Path
import subprocess
import tarfile
import tempfile
import time
import unittest
import zipfile


class Status(ctypes.Structure):
    _fields_ = [('state', ctypes.c_int32), ('files', ctypes.c_uint32),
                ('completed', ctypes.c_uint64), ('total', ctypes.c_uint64),
                ('current', ctypes.c_char * 1024), ('error', ctypes.c_char * 1024)]


parser = argparse.ArgumentParser()
parser.add_argument('--library', required=True)
parser.add_argument('--sevenzip')
args = parser.parse_args()
lib = ctypes.CDLL(args.library)
lib.krkr_archive_start.argtypes = [ctypes.c_char_p] * 4 + [ctypes.c_uint32]
lib.krkr_archive_start.restype = ctypes.c_void_p
lib.krkr_archive_poll.argtypes = [ctypes.c_void_p, ctypes.POINTER(Status)]
lib.krkr_archive_cancel.argtypes = [ctypes.c_void_p]
lib.krkr_archive_destroy.argtypes = [ctypes.c_void_p]


class ArchiveTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='krkr-archive-test-')
        self.root = Path(self.temporary.name).resolve()
        self.output = self.root / 'output'
        self.output.mkdir()

    def tearDown(self):
        self.temporary.cleanup()

    def extract(self, source, password='', codepage=65001, cancel=False):
        handle = lib.krkr_archive_start(str(self.root).encode(), str(source).encode(),
                                        str(self.output).encode(), password.encode(), codepage)
        self.assertTrue(handle)
        try:
            if cancel:
                lib.krkr_archive_cancel(handle)
            status = Status()
            deadline = time.monotonic() + 30
            while time.monotonic() < deadline:
                lib.krkr_archive_poll(handle, ctypes.byref(status))
                if status.state != 1:
                    return status
                time.sleep(.01)
            self.fail('native archive task did not finish within 30 seconds')
        finally:
            lib.krkr_archive_destroy(handle)

    def zip(self, entries):
        path = self.root / '压缩包 🐈.zip'
        with zipfile.ZipFile(path, 'w', zipfile.ZIP_DEFLATED) as archive:
            for name, data in entries:
                archive.writestr(name, data)
        return path

    def pack(self, extension, *options):
        if not args.sevenzip:
            self.skipTest('--sevenzip is needed for encrypted/7z fixtures')
        source = self.root / 'input'
        source.mkdir(exist_ok=True)
        (source / '中文 日本語 🐈.txt').write_text('内容\nUTF-8\n🐈', encoding='utf-8')
        path = self.root / ('archive.' + extension)
        subprocess.run([args.sevenzip, 'a', str(path), '.', *options], cwd=source,
                       stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, check=True)
        return path

    def test_utf8_zip(self):
        path = self.zip([('中文 日本語 🐈/first.ks', '脚本 UTF-8'), ('空目录/', '')])
        original = path.read_bytes()
        status = self.extract(path)
        self.assertEqual((status.state, status.error), (2, b''))
        self.assertEqual((self.output / '中文 日本語 🐈/first.ks').read_text(), '脚本 UTF-8')
        self.assertTrue((self.output / '空目录').is_dir())
        self.assertEqual(path.read_bytes(), original)

    def test_traversal_is_rejected_before_any_write(self):
        status = self.extract(self.zip([('safe.txt', 'safe'), ('../escaped.txt', 'no')]))
        self.assertEqual(status.error, b'unsafe_archive_path')
        self.assertFalse((self.root / 'escaped.txt').exists())
        self.assertEqual(list(self.output.iterdir()), [])

    def test_absolute_path_is_rejected(self):
        status = self.extract(self.zip([('/absolute.txt', 'no')]))
        self.assertEqual(status.error, b'unsafe_archive_path')

    def test_case_conflicts_are_rejected(self):
        status = self.extract(self.zip([('A.txt', 'a'), ('a.txt', 'b')]))
        self.assertEqual(status.error, b'conflict')

    def test_links_are_rejected(self):
        info = zipfile.ZipInfo('link')
        info.create_system = 3
        info.external_attr = (0o120777 << 16)
        status = self.extract(self.zip([(info, '../outside')]))
        self.assertEqual(status.error, b'unsupported_link')

    def test_existing_files_are_never_overwritten(self):
        sentinel = self.output / 'keep.txt'
        sentinel.write_text('original')
        status = self.extract(self.zip([('keep.txt', 'replacement')]))
        self.assertEqual(status.error, b'conflict')
        self.assertEqual(sentinel.read_text(), 'original')

    def test_linked_destination_component_is_rejected(self):
        outside = self.root / 'outside'
        outside.mkdir()
        (self.output / 'link').symlink_to(outside, target_is_directory=True)
        status = self.extract(self.zip([('link/file.txt', 'no')]))
        self.assertEqual(status.state, 3)
        self.assertEqual(list(outside.iterdir()), [])

    def test_cancel(self):
        status = self.extract(self.zip([('data.bin', b'x' * 5000000)]), cancel=True)
        self.assertEqual(status.state, 4)

    def test_unknown_format(self):
        path = self.root / 'not-an-archive.zip'
        path.write_bytes(b'not an archive')
        status = self.extract(path)
        self.assertEqual(status.state, 3)
        self.assertEqual(status.error, b'unsupported_format')

    def test_utf8_tar(self):
        path = self.root / '日本語.tar'
        with tarfile.open(path, 'w', format=tarfile.PAX_FORMAT) as archive:
            data = '文本 🐈'.encode()
            info = tarfile.TarInfo('文件 日本語 🐈.txt')
            info.size = len(data)
            archive.addfile(info, io.BytesIO(data))
        status = self.extract(path)
        self.assertEqual((status.state, status.error), (2, b''))
        self.assertEqual((self.output / '文件 日本語 🐈.txt').read_text(), '文本 🐈')

    def test_utf8_7z_encrypted_headers_and_password(self):
        path = self.pack('7z', '-p密码🐈', '-mhe=on')
        status = self.extract(path, '密码🐈')
        self.assertEqual((status.state, status.error), (2, b''))
        self.assertEqual((self.output / '中文 日本語 🐈.txt').read_text(), '内容\nUTF-8\n🐈')

    def test_7z_wrong_password(self):
        path = self.pack('7z', '-p正确', '-mhe=on')
        self.assertEqual(self.extract(path, '错误').error, b'wrong_password')

    def test_7z_missing_password(self):
        path = self.pack('7z', '-psecret', '-mhe=on')
        self.assertEqual(self.extract(path).error, b'password_required')

    def test_utf8_zip_aes(self):
        # The upstream 7zz writer restricts ZIP passwords to ASCII; Unicode
        # passwords are independently covered by the encrypted 7z fixture.
        path = self.pack('zip', '-psecret', '-mem=AES256')
        status = self.extract(path, 'secret')
        self.assertEqual((status.state, status.error), (2, b''))
        self.assertEqual((self.output / '中文 日本語 🐈.txt').read_text(), '内容\nUTF-8\n🐈')

    def test_zip_missing_password(self):
        path = self.pack('zip', '-psecret', '-mem=AES256')
        self.assertEqual(self.extract(path).error, b'password_required')

    def test_byte_split_7z(self):
        path = self.pack('7z', '-psecret', '-mhe=on', '-v100b')
        self.assertFalse(path.exists())
        status = self.extract(Path(str(path) + '.001'), 'secret')
        self.assertEqual((status.state, status.error), (2, b''))
        self.assertEqual((self.output / '中文 日本語 🐈.txt').read_text(), '内容\nUTF-8\n🐈')

    def test_byte_split_missing_middle_volume(self):
        path = self.pack('7z', '-v50b')
        parts = sorted(self.root.glob('archive.7z.*'))
        self.assertGreaterEqual(len(parts), 3)
        parts[1].unlink()
        status = self.extract(parts[0])
        self.assertEqual(status.error, b'missing_volume')


unittest.main(argv=['test_archive'], verbosity=2)
