"""S003 system acceptance: external CLI, actual Git/files/locks and processes."""
import copy
import fcntl
import hashlib
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import time
from support import REPO, SystemCase


class WorkflowE2E(SystemCase):
    def setUp(self):
        super().setUp()
        self.slug='003-workflow-run-state'
        self.dest=self.base/'prepared worktree'
        self.git('init','-q','-b','dev')
        self.git('config','user.name','System test')
        self.git('config','user.email','system@example.invalid')
        self.git('config','commit.gpgsign','false')
        self.command(['git','init','--bare','-q',self.base/'origin.git'])
        self.git('remote','add','origin',str(self.base/'origin.git'))
        for name in ('AGENTS.md','agent/PRD.md','agent/ARCHITECTURE.md','agent/IMPLEMENT.md'):
            self.write(name,'# Fixture governing input\n')
        self.write('agent/PLAN.md','| Change / path | Slug | Dependencies | Output | Verification |\n| --- | --- | --- | --- | --- |\n| S003 / `changes/003-workflow-run-state.md` | `003-workflow-run-state` | — | Preparation | C00 |\n')
        self.write('agent/changes/'+self.slug+'.md','# S003\nSlug '+self.slug+'; branch change/'+self.slug+'\n')
        for name in ('scripts/workflow-run.pl','scripts/lib/mch/WorkflowRun.pm','scripts/README.md'):
            self.write(name,(REPO/name).read_text())
        self.baseline=self.commit('fixture')
        self.git('push','-q','origin','dev')
        self.env.update(WORKFLOW_E2E_ROOT=str(self.root),WORKFLOW_E2E_DEST=str(self.dest))

    def git(self,*args,cwd=None,ok=True):
        return self.command(['git',*args],cwd=cwd,ok=ok).stdout.strip()

    def commit(self,message):
        self.git('add','-A'); self.git('commit','-qm',message)
        return self.git('rev-parse','HEAD')

    def cli(self,*args,ok=True,fault='',cwd=None):
        command=['perl', REPO/'end_to_end/workflow_driver.pl'] if fault else ['perl', self.root/'scripts/workflow-run.pl']
        result=self.command([*command,*args],ok,cwd,
            {**self.env,'WORKFLOW_E2E_FAULT':fault})
        states=list((self.root/'.git/codex-workflow-runs').glob('*/state.json'))
        if len(states)==1: self.state_file=states[0]; self.run_id=states[0].parent.name
        return result

    def start(self,ok=True,fault='',remote=False):
        return self.cli('start',self.slug,'--worktree',str(self.dest),
                        *(['--remote','origin'] if remote else ['--local']),ok=ok,fault=fault)

    def state(self): return json.loads(self.state_file.read_text())
    def resume(self,ok=True,fault=''): return self.cli('resume','--run',self.run_id,ok=ok,fault=fault)
    def projection(self): return self.dest/self.state()['projection']['path']

    def dependencies(self):
        deps={}
        for number in (1,2):
            slug=f'{number:03}-dependency'
            content=f'contract {number}\n'
            self.write(f'source{number}',content)
            self.write('agent/changes/'+slug+'.md',f'# S{number:03}\nchange/{slug}\n')
            plan=self.root/'agent/PLAN.md'
            plan.write_text(plan.read_text()+f'| S{number:03} / `changes/{slug}.md` | `{slug}` | '+('S001' if number==2 else '—')+' | source | test |\n')
            revision=self.commit('Implement change '+slug)
            artifact=f'checked source {number}\n'
            self.write(f'evidence{number}',artifact)
            deps[slug]={'integration':revision,'sources':{f'source{number}':hashlib.sha256(content.encode()).hexdigest()},
                'checks':[{'scope':'S003 required source checker','revision':revision,'artifact':f'evidence{number}',
                'sha256':hashlib.sha256(artifact.encode()).hexdigest(),'exit':0,'result':'passed'}]}
        plan.write_text(plan.read_text().replace('| `003-workflow-run-state` | —','| `003-workflow-run-state` | S002'))
        self.manifest=self.write('agent/progress/prerequisites/'+self.slug+'.json',json.dumps({'schema':1,'consumer':self.slug,'dependencies':deps}))
        self.baseline=self.commit('record scoped evidence')
        return deps

    def test_S003_T01_e2e(self):
        self.start()
        self.assertEqual(self.state()['branch'],'change/'+self.slug)
        self.assertEqual(self.git('rev-parse','HEAD',cwd=self.dest),self.baseline)

    def test_S003_T02_e2e(self):
        for slug in ('3-short','../003-escape','003-UPPER',''):
            self.cli('start',slug,'--worktree',str(self.dest),'--local',ok=False)
        self.git('checkout','--detach','-q')
        self.start(ok=False); self.assertFalse(self.dest.exists())

    def test_S003_T03_e2e(self):
        plan=self.root/'agent/PLAN.md'; original=plan.read_text()
        for invalid in ('',original+original,original.replace('S003 /','S004 /')):
            plan.write_text(invalid); self.start(ok=False); self.assertFalse(self.dest.exists())
        plan.write_text(original)

    def test_S003_T04_e2e(self):
        for name in ('AGENTS.md','agent/PRD.md','agent/ARCHITECTURE.md','agent/IMPLEMENT.md','agent/changes/'+self.slug+'.md'):
            file=self.root/name; original=file.read_text(); file.unlink()
            self.start(ok=False); self.assertFalse(self.dest.exists()); file.write_text(original)

    def test_S003_T05_e2e(self):
        for args in ([],['wat'],['status','--run','../escape'],['start',self.slug],
                     ['start',self.slug,'--worktree',str(self.dest),'--local','--remote','origin']):
            self.assertEqual(self.cli(*args,ok=False).returncode,2)

    def test_S003_T06_e2e(self):
        self.dependencies(); value=json.loads(self.manifest.read_text())
        for field in ('scope','revision','result'):
            invalid=copy.deepcopy(value); del invalid['dependencies']['002-dependency']['checks'][0][field]
            self.manifest.write_text(json.dumps(invalid)); self.commit('invalid required evidence')
            self.start(ok=False); self.assertFalse(self.dest.exists())

    def test_S003_T07_e2e(self):
        self.dependencies()
        self.write('later.private','phones and historical review UNKNOWN')
        self.commit('retain later obligations')
        self.start(); self.assertEqual(len(self.state()['prerequisites']),2)

    def test_S003_T08_e2e(self):
        self.cli('start',self.slug,'--worktree',str(self.dest),'--local',cwd=self.base)
        self.assertEqual(self.state()['baseline'],self.baseline)
        self.assertIn('not checked',self.state()['observations'][0]['operation'])

    def test_S003_T09_e2e(self):
        self.write('advanced','new baseline'); advanced=self.commit('advance remote')
        self.git('push','-q','origin','dev')
        self.git('reset','--hard',self.baseline)
        self.start(remote=True)
        self.assertEqual(self.state()['baseline'],advanced)
        self.assertEqual(self.git('rev-parse','dev'),self.baseline)

    def test_S003_T10_e2e(self):
        self.git('remote','set-url','origin',str(self.base/'absent-origin'))
        self.start(ok=False,remote=True)
        self.assertFalse(self.dest.exists())
        self.assertEqual(self.git('rev-parse','dev'),self.baseline)

    def test_S003_T11_e2e(self):
        self.git('branch','-m','not-dev')
        self.start(ok=False); self.assertFalse(self.dest.exists())

    def test_S003_T12_e2e(self):
        refs=self.git('show-ref'); self.start()
        self.assertEqual(self.git('branch','--show-current'),'dev')
        self.assertEqual(self.git('rev-parse','HEAD'),self.baseline)
        self.assertEqual(self.git('diff','--cached','--name-only'),'')
        self.assertIn(refs.splitlines()[0],self.git('show-ref'))
        self.assertEqual(len(self.git('worktree','list','--porcelain').split('worktree '))-1,2)

    def test_S003_T13_e2e(self):
        self.write('.hidden','protected')
        before=self.git('status','--porcelain'); self.start(ok=False,remote=True)
        self.assertEqual(self.git('status','--porcelain'),before)
        self.assertEqual((self.root/'.hidden').read_text(),'protected')

    def test_S003_T14_e2e(self):
        self.dest.mkdir(); (self.dest/'user').write_text('preserved')
        self.start(ok=False); self.assertEqual((self.dest/'user').read_text(),'preserved')

    def test_S003_T15_e2e(self):
        self.start(ok=False,fault='path:after-refresh')
        self.assertTrue(self.dest.exists())
        self.assertEqual(self.git('branch','--list','change/'+self.slug),'')

    def test_S003_T16_e2e(self):
        self.start(); state=self.state()
        self.assertEqual(state['baseline'],self.baseline)
        self.assertEqual(state['checks'],[]); self.assertEqual(state['reviews'],[])
        self.assertIsNone(state['merge']); self.assertFalse(state['run_complete'])

    def test_S003_T17_e2e(self):
        self.start(); original=self.state_file.read_text(); value=self.state()
        bad=copy.deepcopy(value); bad['schema']=99
        variants=['{',json.dumps(bad)]
        for field in ('baseline','generation'):
            bad=copy.deepcopy(value); del bad[field]; variants.append(json.dumps(bad))
        for invalid in variants:
            self.state_file.write_text(invalid)
            self.cli('status','--run',self.run_id,ok=False)
            self.assertEqual(self.state_file.read_text(),invalid)

    def test_S003_T18_e2e(self):
        self.start()
        for boundary in ('create','write','short-write','flush','file-sync','rename'):
            self.resume(ok=False,fault='fail:'+boundary)
            self.assertEqual(self.state()['baseline'],self.baseline)
            self.assertFalse(self.state()['run_complete'])
            self.resume()

    def test_S003_T19_e2e(self):
        self.start(); generation=self.state()['generation']
        self.resume(ok=False,fault='fail:directory-sync')
        self.assertGreaterEqual(self.state()['generation'],generation)
        self.resume(); self.assertEqual(self.state()['phase'],'prepared')

    def test_S003_T20_e2e(self):
        result=self.start(ok=False,fault='stale:after-git')
        self.assertIn('generation',result.stderr)
        self.assertEqual(self.state()['baseline'],self.baseline)
        self.assertFalse(self.state()['run_complete'])

    def test_S003_T21_e2e(self):
        self.start(); raw=self.projection().read_bytes(); value=json.loads(raw)
        self.assertEqual(hashlib.sha256(raw).hexdigest(),self.state()['projection']['sha256'])
        self.assertEqual(value['generation'],self.state()['generation'])
        self.assertNotIn(str(self.base),raw.decode())
        self.assertEqual(self.git('diff','--cached','--name-only',cwd=self.dest),'')

    def test_S003_T22_e2e(self):
        self.start(); self.projection().unlink()
        self.cli('preflight','--run',self.run_id,ok=False)
        self.resume(); self.assertTrue(self.projection().is_file())
        self.projection().write_text('user edit')
        self.resume(ok=False); self.assertEqual(self.projection().read_text(),'user edit')

    def test_S003_T23_e2e(self):
        self.write('.git/codex-plan-runs/legacy.tsv','success SECRET')
        self.start()
        self.assertNotIn('SECRET',self.projection().read_text())
        self.assertEqual((self.root/'.git/codex-plan-runs/legacy.tsv').read_text(),'success SECRET')

    def test_S003_T24_e2e(self):
        self.start(); self.cli('preflight','--run',self.run_id)
        file=self.dest/'agent/progress/unrelated.json'; file.write_text('protected')
        self.resume(ok=False); self.assertEqual(file.read_text(),'protected')

    def lock(self,filename):
        path=self.root/'.git'/filename; path.parent.mkdir(parents=True,exist_ok=True)
        handle=path.open('w'); fcntl.flock(handle,fcntl.LOCK_EX|fcntl.LOCK_NB)
        self.addCleanup(handle.close)
        return handle

    def test_S003_T25_e2e(self):
        self.lock('codex-workflow-locks/'+self.slug+'.lock')
        self.start(ok=False); self.assertFalse(self.dest.exists())
        linked=self.base/'linked'
        self.git('worktree','add','-q','-b','other',str(linked))
        self.cli('start',self.slug,'--worktree',str(self.dest),'--local',cwd=linked,ok=False)

    def test_S003_T26_e2e(self):
        handle=self.lock('codex-workflow-locks/'+self.slug+'.lock')
        handle.write('{"pid":999999,"age":"ancient"}'); handle.flush()
        self.start(ok=False); handle.close()
        self.start(); self.assertEqual(self.state()['phase'],'prepared')

    def test_S003_T27_e2e(self):
        self.lock('codex-plan-run.lock')
        self.lock('codex-workflow-locks/004-other.lock')
        self.start(); self.assertEqual(self.state()['phase'],'prepared')

    def test_S003_T28_e2e(self):
        self.start(); before=self.state()
        self.resume(); self.resume()
        for key in ('run_id','branch','baseline','worktree','intent'):
            self.assertEqual(self.state()[key],before[key])
        self.assertEqual(len(list((self.root/'.git/codex-workflow-runs').glob('*/state.json'))),1)

    def test_S003_T29_e2e(self):
        self.start(ok=False,fault='fail:after-intent')
        self.assertFalse(self.dest.exists()); self.resume()
        self.assertEqual(self.git('rev-parse','HEAD',cwd=self.dest),self.baseline)

    def test_S003_T30_e2e(self):
        self.start(ok=False,fault='fail:after-git')
        self.assertTrue(self.dest.exists()); self.resume()
        self.assertEqual(self.state()['phase'],'prepared')
        self.assertEqual(len(self.git('worktree','list','--porcelain').split('worktree '))-1,2)

    def test_S003_T31_e2e(self):
        self.start()
        self.git('commit','--allow-empty','-qm','equal-tree source drift',cwd=self.dest)
        self.resume(ok=False)
        self.assertEqual(self.state()['baseline'],self.baseline)

    def test_S003_T32_e2e(self):
        self.start(remote=True)
        self.write('target','advanced'); self.commit('advance target'); self.git('push','-q','origin','dev')
        self.resume(ok=False); self.assertEqual(self.state()['baseline'],self.baseline)

    def test_S003_T33_e2e(self):
        self.start(); self.git('checkout','-qb','wrong-branch',cwd=self.dest)
        self.resume(ok=False)
        self.assertEqual(self.git('branch','--show-current',cwd=self.dest),'wrong-branch')

    def test_S003_T34_e2e(self):
        self.cli('resume','--run','r-'+'a'*32,ok=False)
        self.start(); value=self.state(); value['phase']='merged'
        self.state_file.write_text(json.dumps(value)); self.resume(ok=False)

    def paused(self):
        env={**self.env,'WORKFLOW_E2E_FAULT':'pause:after-intent'}
        process=subprocess.Popen(['perl',str(REPO/'end_to_end/workflow_driver.pl'),'start',self.slug,
            '--worktree',str(self.dest),'--local'],cwd=self.root,env=env,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
        self.addCleanup(lambda: process.poll() is None and process.kill())
        deadline=time.monotonic()+20
        while not (self.root/'.git/e2e-ready').exists():
            self.assertIsNone(process.poll(),'workflow exited before synchronization boundary')
            self.assertLess(time.monotonic(),deadline,'workflow readiness timeout')
            time.sleep(0.01)
        return process

    def test_S003_T35_e2e(self):
        process=self.paused(); process.send_signal(signal.SIGTERM)
        out,err=process.communicate(timeout=20)
        self.assertEqual(process.returncode,143,out+err)
        states=list((self.root/'.git/codex-workflow-runs').glob('*/state.json'))
        self.state_file=states[0]; self.run_id=states[0].parent.name
        self.assertEqual(self.state()['phase'],'interrupted'); self.resume()

    def test_S003_T36_e2e(self):
        process=self.paused(); process.kill(); process.communicate(timeout=20)
        self.assertEqual(process.returncode,-signal.SIGKILL)
        states=list((self.root/'.git/codex-workflow-runs').glob('*/state.json'))
        self.state_file=states[0]; self.run_id=states[0].parent.name
        self.resume(); self.assertEqual(self.state()['phase'],'prepared')

    def test_S003_T37_e2e(self):
        directory=self.root/'.git/codex-workflow-runs'; directory.mkdir(); directory.chmod(0o500)
        try: self.start(ok=False); self.assertFalse(self.dest.exists())
        finally: directory.chmod(0o700)

    def test_S003_T38_e2e(self):
        self.start(); before=self.state_file.read_bytes(); refs=self.git('show-ref')
        result=json.loads(self.cli('status','--run',self.run_id).stdout)
        self.assertFalse(result['run_complete'])
        self.assertEqual(before,self.state_file.read_bytes()); self.assertEqual(refs,self.git('show-ref'))

    def test_S003_T39_e2e(self):
        self.start(); self.resume(); self.cli('preflight','--run',self.run_id)
        self.assertEqual(self.git('rev-parse','dev'),self.baseline)
        self.assertEqual(self.state()['checks'],[]); self.assertEqual(self.state()['reviews'],[])
        self.assertFalse(self.state()['run_complete'])

    def test_S003_T40_e2e(self):
        readme=(self.root/'scripts/README.md').read_text()
        for operation in ('start','status','preflight','resume'):
            self.assertIn('workflow-run.pl '+operation,readme)
        self.start()
        for operation in ('status','preflight','resume'):
            self.cli(operation,'--run',self.run_id)
        self.assertIn('manual bootstrap',readme)
        self.assertIn('S004',readme)
