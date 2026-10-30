"""S002: complete checker command against source-linked on-disk records."""
from support import ScaffoldSystemCase


class SetupE2E(ScaffoldSystemCase):
    def test_S002_T01_e2e(self):
        self.valid()

    def test_S002_T02_e2e(self):
        for key in ('Application ID', 'Public name'):
            for value in ('', 'com.example.app', 'wrong'):
                self.row(key, 1, value)

    def test_S002_T03_e2e(self):
        for key in ('Maps', 'Indoor', 'Duration'):
            # Locate settled field names from the actual identity section.
            section=(self.root/'agent/setup-decisions.md').read_text().split('## Identity and constraints')[1].split('## ')[0]
            rows=[line for line in section.splitlines() if line.startswith('| ') and key.lower() in line.lower()]
            self.assertTrue(rows, key)
            for row in rows:
                name=row.split('|')[1].strip()
                self.row(name, 1, 'contradicts settled scope')

    def test_S002_T04_e2e(self):
        self.valid()
        self.assertIn('minSdk = 24', (self.root/'android/app/build.gradle.kts').read_text())

    def test_S002_T05_e2e(self):
        for field, value in (('minSdk',24), ('compileSdk',36), ('targetSdk',36)):
            self.mutate('android/app/build.gradle.kts', lambda t:t.replace(f'{field} = {value}',f'{field} = 37'))
        self.mutate('pubspec.lock', lambda t:t.replace('version: "10.2.2"','version: "0.0.0"'))

    def test_S002_T06_e2e(self):
        self.valid()
        self.row('Physical phones', 1, 'available')

    def test_S002_T07_e2e(self):
        self.valid()
        self.assertIn('| Physical phones | unknown |', (self.root/'agent/setup-decisions.md').read_text())

    def test_S002_T08_e2e(self):
        for key in ('Host/toolchain','Configured emulator','Physical phones','Reference course/observed steps','Map-account access'):
            for column in range(1,5): self.row(key,column,'')

    def test_S002_T09_e2e(self):
        self.valid()
        self.row('D05',1,'resolved; SQLite selected')

    def test_S002_T10_e2e(self):
        for key in ('D01','D03','D05','D12'):
            self.row(key,3,'S999; before gate')

    def test_S002_T11_e2e(self):
        self.valid()
        self.assertIn('| Account/project suitability | unknown |',(self.root/'agent/setup-decisions.md').read_text())

    def test_S002_T12_e2e(self):
        section=(self.root/'agent/setup-decisions.md').read_text().split('## Maps')[1].split('### Inventory')[0]
        for line in section.splitlines():
            if line.startswith('| ') and not line.startswith('| Field '):
                name=line.split('|')[1].strip()
                if name not in ('Authorization','---'): self.row(name,1,'incomplete')
        for column in range(1,5): self.row('Account/project suitability',column,'')

    def test_S002_T13_e2e(self):
        self.valid()
        self.assertIn('no keys, passwords, tokens',(self.root/'agent/setup-decisions.md').read_text())

    def test_S002_T14_e2e(self):
        for key in ('Custody procedure','Certificate distinction','Artifact distinction'):
            self.row(key,1,'')

    def test_S002_T15_e2e(self):
        self.valid()
        self.row('Stack/support',1,'partial',ok=True)

    def test_S002_T16_e2e(self):
        for key in ('Stack/support','Android service/permissions','Maps/terms/usage','Release/account obligations'):
            self.row(key,1,'verified')
            self.row(key,2,'2026-02-30; scope: invalid')
            self.row(key,5,'S999; before gate')

    def test_S002_T17_e2e(self):
        self.valid()
        self.row('Stack/support',4,'Unavailable without reason or next action')

    def test_S002_T18_e2e(self):
        self.mutate('agent/setup-decisions.md',lambda t:t.replace('## Maps','## Absent maps'))
        self.mutate('agent/setup-decisions.md',lambda t:t+'\n[broken](../absent.dart)\n')

    def test_S002_T19_e2e(self):
        self.row('S001 baseline',1,'executed in S002')
        self.row('Review/merge',1,'executed in S002')
        self.row('Unit + coverage',5,'unknown revision and scope')

    def test_S002_T20_e2e(self):
        self.valid()
        self.row('Application ID',1,'wrong')
        self.runner_tools()
        result=self.runner()
        self.assertIn('"status": "passed"',result.stdout)
