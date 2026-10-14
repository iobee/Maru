import importlib.util
import json
from pathlib import Path
from tempfile import TemporaryDirectory
from types import SimpleNamespace
import unittest
from unittest.mock import patch
spec=importlib.util.spec_from_file_location('release', Path(__file__).with_name('macos-release.py'))
r=importlib.util.module_from_spec(spec);spec.loader.exec_module(r)
class ReleaseTests(unittest.TestCase):
 def test_wrong_team_is_rejected(self):
  with patch.object(r,'run',return_value=SimpleNamespace(stderr='Authority=Developer ID Application: A\nTeamIdentifier=OTHER\nTimestamp=now\n',stdout='')):
   with self.assertRaisesRegex(RuntimeError,'Wrong Developer ID'):r.signature(Path('A.app'),'TEAM')
 def test_missing_timestamp_is_rejected(self):
  with patch.object(r,'run',return_value=SimpleNamespace(stderr='Authority=Developer ID Application: A\nTeamIdentifier=TEAM\n',stdout='')):
   with self.assertRaisesRegex(RuntimeError,'timestamp'):r.signature(Path('A.app'),'TEAM')
 def test_missing_hardened_runtime_is_rejected(self):
  with patch.object(r,'run',return_value=SimpleNamespace(stderr='Authority=Developer ID Application: A\nTeamIdentifier=TEAM\nTimestamp=now\n',stdout='')):
   with self.assertRaisesRegex(RuntimeError,'hardened'):r.signature(Path('A.app'),'TEAM',True)
 def test_pending_submission_is_resumed_without_duplicate_upload(self):
  with TemporaryDirectory() as tmp:
   app=Path(tmp)/'A.app';app.mkdir();state=app.parent/'.notary'/app.name;state.mkdir(parents=True)
   (state/'submission.json').write_text(json.dumps({'id':'request-1','fingerprint':'abc'}))
   calls=[]
   def fake(*args,**kw):
    calls.append(args);return SimpleNamespace(stdout=json.dumps({'id':'request-1','status':'In Progress'}),stderr='',returncode=0)
   with patch.object(r,'verify',return_value='CDHash=abc\n'),patch.object(r,'run',side_effect=fake):
    self.assertEqual(r.notarize(app,'TEAM','profile',True),75)
   self.assertEqual([c[2] for c in calls],['info'])
 def test_invalid_submission_does_not_staple(self):
  with TemporaryDirectory() as tmp:
   app=Path(tmp)/'A.app';app.mkdir();state=app.parent/'.notary'/app.name;state.mkdir(parents=True)
   (state/'submission.json').write_text(json.dumps({'id':'request-1','fingerprint':'abc'}));calls=[]
   def fake(*args,**kw):
    calls.append(args);return SimpleNamespace(stdout=json.dumps({'id':'request-1','status':'Invalid'}),stderr='',returncode=0)
   with patch.object(r,'verify',return_value='CDHash=abc\n'),patch.object(r,'run',side_effect=fake):
    with self.assertRaisesRegex(RuntimeError,'rejected'):r.notarize(app,'TEAM','profile',True)
   self.assertFalse(any('stapler' in c for c in calls))
if __name__=='__main__':unittest.main()
