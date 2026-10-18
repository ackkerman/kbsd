"""Verify signing selection and fail-closed behavior without touching the user's keychain."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[2] / "scripts/sign-app.sh"
FIXED = 'designated => identifier "com.ackkerman.kbsd" and certificate leaf = H"0123456789ABCDEF"'


class SigningTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.app = self.root / "kbsd.app"
        self.app.mkdir()
        shim = self.root / "codesign"
        shim.write_text("""#!/usr/bin/env python3
import json, os, pathlib, sys
args=sys.argv[1:]
with open(os.environ['SIGN_LOG'],'a') as out: out.write(json.dumps(args)+'\\n')
marker=pathlib.Path(os.environ['SIGN_MARKER'])
if '--sign' in args:
    if os.environ.get('SIGN_FAIL'): sys.exit(17)
    marker.touch()
elif '-d' in args:
    result=os.environ.get('RESULT_DR','') if marker.exists() else os.environ.get('PREVIOUS_DR','')
    if not result: sys.exit(1)
    print(result,file=sys.stderr)
""")
        shim.chmod(0o755)
        self.env = dict(os.environ)
        self.env.pop("KBSD_SIGN_IDENTITY", None)
        self.env.update(
            PATH=str(self.root) + os.pathsep + self.env["PATH"],
            KBSD_SIGNING_PROFILE=str(self.root / "identity"),
            SIGN_LOG=str(self.root / "calls.jsonl"),
            SIGN_MARKER=str(self.root / "signed"),
            RESULT_DR=FIXED,
        )

    def run_sign(self, **values):
        return subprocess.run(["bash", str(SCRIPT), str(self.app)], env={**self.env, **values}, capture_output=True, text=True)

    def sign_calls(self):
        path = self.root / "calls.jsonl"
        if not path.exists(): return []
        return [args for args in map(json.loads, path.read_text().splitlines()) if "--sign" in args]

    def test_explicit_identity_is_used(self):
        result = self.run_sign(KBSD_SIGN_IDENTITY="fixed-identity")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.sign_calls()[0][2], "fixed-identity")

    def test_persisted_identity_is_reused(self):
        (self.root / "identity").write_text("saved-identity\n")
        result = self.run_sign()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.sign_calls()[0][2], "saved-identity")

    def test_empty_profile_fails_before_signing(self):
        (self.root / "identity").write_text("\n")
        self.assertNotEqual(self.run_sign().returncode, 0)
        self.assertEqual(self.sign_calls(), [])

    def test_signing_failure_never_falls_back_to_ad_hoc(self):
        result = self.run_sign(KBSD_SIGN_IDENTITY="fixed-identity", SIGN_FAIL="1")
        self.assertEqual(result.returncode, 17)
        self.assertEqual(len(self.sign_calls()), 1)
        self.assertNotIn("-", self.sign_calls()[0])

    def test_cdhash_only_result_is_rejected(self):
        result = self.run_sign(KBSD_SIGN_IDENTITY="fixed-identity", RESULT_DR='designated => cdhash H"ABCD"')
        self.assertNotEqual(result.returncode, 0)

    def test_identifier_without_signer_constraint_is_rejected(self):
        result = self.run_sign(KBSD_SIGN_IDENTITY="fixed-identity", RESULT_DR='designated => identifier "com.ackkerman.kbsd"')
        self.assertNotEqual(result.returncode, 0)

    def test_unconfigured_first_build_keeps_existing_ci_behavior(self):
        result = self.run_sign()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.sign_calls()[0][2], "-")
        self.assertIn("privacy permissions", result.stderr)

    def test_existing_certificate_build_cannot_be_downgraded(self):
        result = self.run_sign(PREVIOUS_DR=FIXED)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.sign_calls(), [])

    def test_explicit_ad_hoc_cannot_downgrade_existing_certificate(self):
        result = self.run_sign(KBSD_SIGN_IDENTITY="-", PREVIOUS_DR=FIXED)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.sign_calls(), [])

    def test_profile_prevents_explicit_ad_hoc_override(self):
        (self.root / "identity").write_text("saved-identity\n")
        result = self.run_sign(KBSD_SIGN_IDENTITY="-")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.sign_calls(), [])


if __name__ == "__main__":
    unittest.main()
