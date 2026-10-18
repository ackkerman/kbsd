#!/bin/bash
# This file creates one reusable local code-signing identity only after an explicit setup invocation.
# The private key is imported as non-extractable and its temporary source is removed on exit.
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
profile="$repo_root/.local/signing/identity"
if [[ "${1:-}" != '--create' ]]; then
  cat <<'HELP'
This setup creates a local code-signing certificate and private key in the user's login keychain.
Trust is restricted to the codeSign policy, and only /usr/bin/codesign is granted access to the key.
It does not grant Accessibility access, modify TCC, disable Gatekeeper, or provide Developer ID notarization.
Run with --create only after approving this keychain change. Do not recreate an existing identity.
HELP
  exit 0
fi
if [[ -e "$profile" ]]; then
  echo 'A signing profile already exists. It will not be replaced; keeping the same key preserves identity.' >&2
  exit 1
fi
existing="$(security find-certificate -c 'kbsd Local Code Signing' -Z 2>/dev/null || true)"
if [[ -n "$existing" ]]; then
  echo 'A kbsd signing certificate already exists. Recover its identity instead of creating another key.' >&2
  exit 1
fi
keychain="$(security default-keychain -d user | sed 's/^[[:space:]]*"//; s/"[[:space:]]*$//')"
if [[ -z "$keychain" || ! -f "$keychain" ]]; then
  echo 'The user default keychain is unavailable. Unlock it before setting up signing.' >&2
  exit 1
fi
umask 077
workspace="$(mktemp -d "${TMPDIR:-/tmp}/kbsd-signing.XXXXXXXX")"
trap 'rm -rf "$workspace"' EXIT HUP INT TERM
cat > "$workspace/certificate.cnf" <<'CONFIG'
[req]
distinguished_name = subject
x509_extensions = extensions
prompt = no
[subject]
CN = kbsd Local Code Signing
[extensions]
basicConstraints = critical, CA:FALSE
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always
CONFIG
openssl req -new -x509 -newkey rsa:3072 -nodes -sha256 -days 3650 \
  -config "$workspace/certificate.cnf" -keyout "$workspace/private.key" \
  -out "$workspace/certificate.pem" 2> "$workspace/openssl.log"
cat "$workspace/private.key" "$workspace/certificate.pem" > "$workspace/identity.pem"
# No password is passed on the command line and the imported key cannot be exported.
security import "$workspace/identity.pem" -k "$keychain" -f pemseq -t agg -x -T /usr/bin/codesign
# User-domain trust applies only to code signing, never TLS or other trust policies.
security add-trusted-cert -r trustRoot -p codeSign -k "$keychain" "$workspace/certificate.pem"
fingerprint="$(openssl x509 -in "$workspace/certificate.pem" -noout -fingerprint -sha1 | cut -d= -f2 | tr -d ':')"
if ! security find-identity -v -p codesigning "$keychain" | grep -Fq "$fingerprint"; then
  echo 'The certificate was imported but is not yet a valid code-signing identity. Review its trust in Keychain Access; do not generate a second key.' >&2
  exit 1
fi
mkdir -p "$(dirname "$profile")"
printf '%s\n' "$fingerprint" > "$profile"
chmod 600 "$profile"
printf 'Fixed signing identity configured. Keep this key in the login keychain for future kbsd builds.\n'
