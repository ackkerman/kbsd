#!/bin/bash
# This file guarantees configured signing identity continuity without silently falling back to ad-hoc.
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
profile="${KBSD_SIGNING_PROFILE:-$repo_root/.local/signing/identity}"
app_path="${1:?Usage: sign-app.sh APP_PATH [--preflight]}"
identity="${KBSD_SIGN_IDENTITY:-}"
if [[ -z "$identity" && -f "$profile" ]]; then
  identity="$(cat "$profile")"
  if [[ -z "$identity" || "$identity" == '-' || "$identity" == *$'\n'* ]]; then
    echo 'Invalid fixed signing profile. Restore the configured identity; ad-hoc fallback is refused.' >&2
    exit 1
  fi
fi
if [[ -z "$identity" || "$identity" == '-' ]]; then
  # A signed installed build must never be replaced by an unsigned identity accidentally.
  previous="$(codesign -d -r- "$app_path" 2>&1 || true)"
  if [[ "$previous" == *'designated =>'* && "$previous" != *'cdhash '* ]]; then
    echo 'This app already uses certificate signing. Set KBSD_SIGN_IDENTITY or restore the local profile before updating it.' >&2
    exit 1
  fi
  identity='-'
  echo 'Using ad-hoc signing: privacy permissions may need reapproval after rebuilding.' >&2
fi
if [[ "$identity" == '-' && -f "$profile" ]]; then
  echo 'A fixed identity is configured; explicitly downgrading it to ad-hoc is refused.' >&2
  exit 1
fi
if [[ "${2:-}" == '--preflight' ]]; then exit 0; fi
codesign --force --sign "$identity" --identifier com.ackkerman.kbsd "$app_path"
codesign --verify --deep --strict "$app_path"
if [[ "$identity" != '-' ]]; then
  requirement="$(codesign -d -r- "$app_path" 2>&1)"
  if [[ "$requirement" == *'cdhash '* || "$requirement" != *'identifier "com.ackkerman.kbsd"'* || ( "$requirement" != *'certificate '* && "$requirement" != *'anchor '* ) ]]; then
    echo 'Fixed signing did not produce an identity-bound designated requirement; refusing this build.' >&2
    exit 1
  fi
  printf '%s\n' "$requirement" >&2
fi
