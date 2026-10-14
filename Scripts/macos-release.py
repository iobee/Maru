#!/usr/bin/env python3
"""Verify and notarize Developer ID artifacts; credentials stay in Keychain.

A pending submission exits 75 and is recorded for a later retry. Re-running the
same command resumes that submission instead of uploading duplicate artifacts.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import subprocess
import sys


def run(*args, check=True):
    result = subprocess.run([str(a) for a in args], capture_output=True, text=True)
    if check and result.returncode:
        raise RuntimeError(f'{args[0]} failed ({result.returncode}):\n{result.stdout}{result.stderr}')
    return result


def digest(path):
    h = hashlib.sha256()
    with path.open('rb') as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b''):
            h.update(chunk)
    return h.hexdigest()


def signature(path, team, runtime=False):
    detail = run('codesign', '-d', '--verbose=4', path).stderr
    if 'Authority=Developer ID Application:' not in detail or f'TeamIdentifier={team}\n' not in detail:
        raise RuntimeError(f'Wrong Developer ID/team for {path}')
    if 'Timestamp=' not in detail:
        raise RuntimeError(f'Missing secure timestamp: {path}')
    if runtime and '(runtime)' not in detail:
        raise RuntimeError(f'Missing hardened runtime: {path}')
    entitlements = run('codesign', '-d', '--entitlements', ':-', path).stdout.strip()
    if entitlements and plistlib.loads(entitlements.encode()).get('com.apple.security.get-task-allow'):
        raise RuntimeError(f'Debug entitlement in release: {path}')
    return detail


def verify(path, team, notarized=False):
    run('codesign', '--verify', '--deep', '--strict', '--verbose=2', path)
    detail = signature(path, team, path.suffix == '.app')
    if path.suffix == '.app':
        # Verify every embedded Mach-O, including Native Messaging hosts,
        # Electron native modules, Sparkle helpers, and all framework versions.
        magic = {b'\xcf\xfa\xed\xfe', b'\xce\xfa\xed\xfe', b'\xfe\xed\xfa\xcf', b'\xfe\xed\xfa\xce', b'\xca\xfe\xba\xbe', b'\xbe\xba\xfe\xca', b'\xca\xfe\xba\xbf'}
        for child in path.rglob('*'):
            if child.is_symlink() or not child.is_file():
                continue
            with child.open('rb') as stream:
                is_macho = stream.read(4) in magic
            if is_macho:
                signature(child, team)
    else:
        run('hdiutil', 'verify', path)
    if notarized:
        run('xcrun', 'stapler', 'validate', path)
        args = ['spctl', '--assess', '--verbose=2', '--type', 'execute' if path.suffix == '.app' else 'open']
        if path.suffix == '.dmg':
            args += ['--context', 'context:primary-signature']
        run(*args, path)
    return detail


def notarize(path, team, profile, submit_only):
    detail = verify(path, team)
    fingerprint = re.search(r'^CDHash=(.+)$', detail, re.M).group(1) if path.suffix == '.app' else digest(path)
    state_dir = path.parent / '.notary' / path.name
    state_dir.mkdir(parents=True, exist_ok=True)
    state_path = state_dir / 'submission.json'
    record = json.loads(state_path.read_text()) if state_path.exists() else {}
    if record.get('fingerprint') != fingerprint:
        record = {}
    auth = ['--keychain-profile', profile]
    # notarytool otherwise searches the data-protection keychain, even when a
    # file-based CI keychain was added to the signing certificate search list.
    if os.environ.get('MACOS_NOTARY_KEYCHAIN'):
        auth += ['--keychain', os.environ['MACOS_NOTARY_KEYCHAIN']]
    if not record.get('id'):
        upload = path
        if path.suffix == '.app':
            upload = state_dir / f'{path.stem}.zip'
            # ditto would append to an existing ZIP; always create a fresh one.
            if upload.exists():
                upload.unlink()
            run('ditto', '-c', '-k', '--sequesterRsrc', '--keepParent', path, upload)
        print(f'Submitting {path.name} to Apple', flush=True)
        submission = json.loads(run('xcrun', 'notarytool', 'submit', upload, *auth, '--output-format', 'json').stdout)
        record = {**submission, 'fingerprint': fingerprint, 'artifact': str(path), 'team': team}
        state_path.write_text(json.dumps(record, indent=2) + '\n')
    info = json.loads(run('xcrun', 'notarytool', 'info', record['id'], *auth, '--output-format', 'json').stdout)
    if info['status'] == 'In Progress' and not submit_only:
        print(f"Waiting for Apple: {record['id']}", flush=True)
        run('xcrun', 'notarytool', 'wait', record['id'], *auth, '--timeout', os.environ.get('MACOS_NOTARY_TIMEOUT', '20m'), '--output-format', 'json', check=False)
        info = json.loads(run('xcrun', 'notarytool', 'info', record['id'], *auth, '--output-format', 'json').stdout)
    record.update(info)
    state_path.write_text(json.dumps(record, indent=2) + '\n')
    print(f"{path.name}: {info['status']} ({record['id']})", flush=True)
    if info['status'] == 'In Progress':
        print(f'Resume with the same command. Record: {state_path}', flush=True)
        return 75
    log = run('xcrun', 'notarytool', 'log', record['id'], *auth)
    (state_dir / 'notary-log.json').write_text(log.stdout)
    if info['status'] != 'Accepted':
        raise RuntimeError(f'Apple rejected {path.name}; see {state_dir / "notary-log.json"}')
    run('xcrun', 'stapler', 'staple', path)
    verify(path, team, notarized=True)
    if path.suffix == '.dmg':
        record['fingerprint'] = digest(path)
    record['verified'] = True
    state_path.write_text(json.dumps(record, indent=2) + '\n')
    print(f'Accepted, stapled, and Gatekeeper verified: {path}', flush=True)
    return 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['verify', 'notarize'])
    parser.add_argument('artifact', type=Path)
    parser.add_argument('--team', default=os.environ.get('MACOS_TEAM_ID'))
    parser.add_argument('--profile', default=os.environ.get('MACOS_NOTARY_PROFILE'))
    parser.add_argument('--submit-only', action='store_true')
    parser.add_argument('--notarized', action='store_true')
    args = parser.parse_args()
    path = args.artifact.resolve()
    if path.suffix not in {'.app', '.dmg'} or not path.exists():
        parser.error('artifact must be an existing .app or .dmg')
    if not args.team or (args.action == 'notarize' and not args.profile):
        parser.error('MACOS_TEAM_ID and (for notarization) MACOS_NOTARY_PROFILE are required')
    if args.action == 'verify':
        verify(path, args.team, args.notarized)
        print(f'Verified: {path}')
        return 0
    return notarize(path, args.team, args.profile, args.submit_only)


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (RuntimeError, ValueError, KeyError) as error:
        print(f'error: {error}', file=sys.stderr)
        sys.exit(1)
