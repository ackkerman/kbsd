"""Ensure an isolated certificate-signed build is the app actually put in the release archive."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

SOURCE = Path(__file__).resolve().parents[3] / "scripts/package-release.sh"


class ReleasePathTests(unittest.TestCase):
    def test_archive_uses_the_selected_app_path(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "scripts").mkdir()
            (root / "native/scripts").mkdir(parents=True)
            (root / "bin").mkdir()
            shutil.copy2(SOURCE, root / "scripts/package-release.sh")
            (root / "native/scripts/package-app.sh").write_text("#!/bin/bash\nset -eu\nmkdir -p \"$KBSD_APP_PATH\"\n")
            shim = root / "bin/ditto"
            shim.write_text("""#!/usr/bin/env python3
import json,os,pathlib,sys
pathlib.Path(os.environ['DITTO_LOG']).write_text(json.dumps(sys.argv[1:]))
pathlib.Path(sys.argv[-1]).write_bytes(b'test archive')
""")
            shim.chmod(0o755)
            selected = root / "separate build/kbsd.app"
            env = {**os.environ, "PATH": str(root / "bin") + os.pathsep + os.environ["PATH"], "KBSD_APP_PATH": str(selected), "DITTO_LOG": str(root / "ditto.json")}
            result = subprocess.run(["bash", str(root / "scripts/package-release.sh")], env=env, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            args = json.loads((root / "ditto.json").read_text())
            self.assertEqual(args[-2], str(selected))
            self.assertTrue((root / "dist/release/SHA256SUMS.txt").is_file())


if __name__ == "__main__":
    unittest.main()
