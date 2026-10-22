#!/usr/bin/env python3
"""
Regression test suite for vkeyboard_ctl.py runtime directory and cache reading security.
Verifies that FIFOs, symlinks, loose permissions, and oversized files are strictly rejected
without blocking or exhausting resources.
"""

import json
import os
import stat
import sys
import tempfile
import time
from pathlib import Path

# Add scripts directory to module path
root_dir = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(root_dir / "scripts"))

import vkeyboard_ctl


def run_tests():
    print("RUN // vkeyboard security cache tests")

    # Test 1: get_runtime_dir() enforces strict 0700 and returns valid directory
    run_dir = vkeyboard_ctl.get_runtime_dir()
    st = os.lstat(run_dir)
    assert stat.S_ISDIR(st.st_mode), "Runtime dir must be a directory"
    assert not stat.S_ISLNK(st.st_mode), "Runtime dir must not be a symlink"
    assert st.st_uid == os.getuid(), "Runtime dir must be owned by current user"
    assert (st.st_mode & 0o077) == 0, "Runtime dir must have 0700 permissions"
    print("PASS // get_runtime_dir validation")

    # Isolated temporary testing environment
    with tempfile.TemporaryDirectory() as tmp_test:
        test_dir = Path(tmp_test) / "vkeyboard_test"
        test_dir.mkdir(mode=0o700)
        cache_file = test_dir / "vkeyboard_cache.json"

        # Mock get_runtime_dir to point to our test directory
        orig_get_runtime_dir = vkeyboard_ctl.get_runtime_dir
        vkeyboard_ctl.get_runtime_dir = lambda: test_dir

        try:
            # Test 2: Normal write and read roundtrip
            test_payload = {"code": "EN", "name": "English"}
            vkeyboard_ctl._write_cache(test_payload)
            read_back = vkeyboard_ctl._read_cache()
            assert read_back == test_payload, f"Expected {test_payload}, got {read_back}"
            cache_st = os.lstat(cache_file)
            assert stat.S_ISREG(cache_st.st_mode), "Cache file must be regular file"
            assert (cache_st.st_mode & 0o077) == 0, "Cache file must have 0600 permissions"
            print("PASS // normal cache write and read roundtrip with 0600 permissions")

            # Test 3: FIFO file does not hang or wedge status
            cache_file.unlink(missing_ok=True)
            fifo_path = str(cache_file)
            os.mkfifo(fifo_path, 0o600)
            start_t = time.monotonic()
            fifo_res = vkeyboard_ctl._read_cache()
            elapsed = time.monotonic() - start_t
            assert fifo_res is None, "Reading FIFO must return None"
            assert elapsed < 0.5, f"Reading FIFO must not block (took {elapsed:.3f}s)"
            os.unlink(fifo_path)
            print("PASS // FIFO non-blocking rejection")

            # Test 4: Symlink file is rejected
            target_file = Path(tmp_test) / "real_file.json"
            target_file.write_text(json.dumps({"_timestamp": time.monotonic(), "payload": {"code": "HACK"}}))
            cache_file.symlink_to(target_file)
            symlink_res = vkeyboard_ctl._read_cache()
            assert symlink_res is None, "Reading symlink must be rejected and return None"
            cache_file.unlink()
            print("PASS // symlink rejection")

            # Test 5: Oversized file (> 64 KiB) is rejected
            big_data = {
                "_timestamp": time.monotonic(),
                "payload": "X" * (vkeyboard_ctl.MAX_CACHE_BYTES + 1024)
            }
            cache_file.write_text(json.dumps(big_data))
            os.chmod(cache_file, 0o600)
            oversized_res = vkeyboard_ctl._read_cache()
            assert oversized_res is None, "Reading oversized file must return None"
            cache_file.unlink()
            print("PASS // oversized cache rejection")

        finally:
            vkeyboard_ctl.get_runtime_dir = orig_get_runtime_dir

    print("PASS // all security cache tests completed successfully")


if __name__ == "__main__":
    run_tests()
