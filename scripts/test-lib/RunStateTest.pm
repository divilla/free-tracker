package RunStateTest;
use strict;
use warnings;
use Exporter 'import';
use Cwd qw(abs_path);
use File::Basename qw(dirname);
use File::Copy qw(copy);
use File::Path qw(make_path);
use File::Glob qw(bsd_glob);
use File::Temp qw(tempfile);
use Digest::SHA qw(sha256_hex);
use Fcntl qw(:flock);
use POSIX qw(mkfifo);
use JSON::PP;
use Test::More;
use ReleaseTest;
use mch::WorkflowRun;

our @EXPORT = qw(run_fixture runner start_run invoke state slurp edit commit_all rejects clone_value cases);
my $scripts = abs_path(dirname(__FILE__) . '/..');
my $serial = 0;
sub slurp { open my $f, '<:raw', $_[0] or die "$! $_[0]"; local $/; return <$f> // ''; }
sub clone_value { JSON::PP::decode_json(JSON::PP::encode_json($_[0])) }
sub commit_all { my ($f, $message) = @_; git($f, 'add', '-A'); git($f, 'commit', '-qm', $message // 'fixture'); return git($f, 'rev-parse', 'HEAD'); }
sub edit { my ($f, $path, $transform) = @_; write_file("$f->{repo}/$path", $transform->(slurp("$f->{repo}/$path"))); }
sub run_fixture {
    my (%opt) = @_;
    my $f = fixture();
    $f->{slug} = $opt{slug} // '003-workflow-run-state';
    my ($num) = $f->{slug} =~ /^(\d+)-/;
    make_path("$f->{repo}/agent/changes", "$f->{repo}/scripts/lib/mch");
    for (qw(AGENTS.md agent/PRD.md agent/ARCHITECTURE.md agent/IMPLEMENT.md)) { write_file("$f->{repo}/$_", "# Governing input\n"); }
    copy("$scripts/workflow-run.pl", "$f->{repo}/scripts/workflow-run.pl") or die $!;
    copy("$scripts/lib/mch/WorkflowRun.pm", "$f->{repo}/scripts/lib/mch/WorkflowRun.pm") or die $!;
    write_file("$f->{repo}/agent/PLAN.md", "| Change / path | Slug | Dependencies | Output | Verification |\n| --- | --- | --- | --- | --- |\n| S$num / `changes/$f->{slug}.md` | `$f->{slug}` | — | Preparation | C00 |\n");
    write_file("$f->{repo}/agent/changes/$f->{slug}.md", "# S$num\nSlug $f->{slug}; branch change/$f->{slug}\n");
    write_file("$f->{repo}/.gitignore", "*.private\n");
    $f->{baseline} = commit_all($f);
    git($f, 'branch', '-f', 'dev'); git($f, 'push', '-q', 'origin', 'dev');
    $f->{dest} = dirname($f->{repo}) . '/prepared tree';
    $f->{common} = abs_path("$f->{repo}/.git");
    return $f;
}
sub runner { my ($f, %opt) = @_; my $s = mch::WorkflowRun->new(root => $f->{repo}, %opt); $s->repository; return $s; }
sub invoke {
    my ($f, $mode, $hook, @args) = @_;
    if ($mode eq 'G' && !$hook) {
        return ReleaseTest::execute($f->{cwd} // $f->{repo}, $^X, "$f->{repo}/scripts/workflow-run.pl", @args);
    }
    my ($out, $outpath) = tempfile(); my ($err, $errpath) = tempfile();
    my $rc;
    {
        local *STDOUT = $out; local *STDERR = $err;
        $rc = mch::WorkflowRun->new(root => $f->{repo}, hook => $hook, ($mode eq 'U' ? (clock => sub { '2026-10-30T00:00:00Z' }) : ()))->cli(@args);
    }
    close $out; close $err;
    my @r = ($rc, slurp($outpath), slurp($errpath)); unlink $outpath, $errpath;
    return @r;
}
sub start_run {
    my ($f, $mode, $hook, @extra) = @_;
    @extra = ('--local') unless @extra;
    my @r = invoke($f, $mode, $hook, 'start', $f->{slug}, '--worktree', $f->{dest}, @extra);
    if ($r[1] =~ /"run_id"/) { my $v = eval { decode_json($r[1]) }; $f->{id} = $v->{run_id} if $v; }
    if (!$f->{id}) {
        my @paths = bsd_glob "$f->{common}/codex-workflow-runs/*/state.json";
        $f->{id} = decode_json(slurp($paths[0]))->{run_id} if @paths == 1;
    }
    return @r;
}
sub state { decode_json(slurp("$_[0]{common}/codex-workflow-runs/$_[0]{id}/state.json")) }
sub rejects {
    my ($code, $pattern, $label) = @_;
    my $ok = eval { $code->(); 1 };
    ok(!$ok, $label // 'fails closed'); like($@, $pattern, 'actionable failure');
}
sub snapshot {
    my ($f) = @_;
    return join "\n", map { git($f, @$_) } (['show-ref'], ['status', '--porcelain=v1', '--untracked-files=all', '--ignore-submodules=none'], ['ls-files', '--stage'], ['symbolic-ref', 'HEAD']);
}
sub failure_at {
    my ($event) = @_;
    my $fired = 0;
    return sub { die "injected $event\n" if $_[0] eq $event && !$fired++; };
}
sub prerequisite_fixture {
    my ($f) = @_;
    # Two actual integrated prerequisites with source-bound executable evidence.
    my %deps;
    for my $n (1, 2) {
        my $slug = sprintf('%03d-dependency', $n);
        write_file("$f->{repo}/source$n", "contract $n\n");
        write_file("$f->{repo}/agent/changes/$slug.md", "# S00$n\nchange/$slug\n");
        edit($f, 'agent/PLAN.md', sub { $_[0] . "| S00$n / `changes/$slug.md` | `$slug` | " . ($n == 2 ? 'S001' : '—') . " | source | test |\n" });
        my $commit = commit_all($f, "Implement change $slug");
        $deps{$slug} = { integration => $commit, sources => { "source$n" => sha256_hex("contract $n\n") }, checks => [{ scope => "S003 consumes source$n via checker", revision => $commit,
            artifact => "evidence$n", sha256 => sha256_hex("nonempty observed checker result $n\n"), exit => 0, result => 'passed' }] };
        write_file("$f->{repo}/evidence$n", "nonempty observed checker result $n\n");
    }
    edit($f, 'agent/PLAN.md', sub { my $v = shift; $v =~ s/(\| `\Q$f->{slug}\E` \| )—/${1}S002/; $v });
    make_path("$f->{repo}/agent/progress/prerequisites");
    write_file("$f->{repo}/agent/progress/prerequisites/$f->{slug}.json", JSON::PP->new->canonical->encode({schema => 1, consumer => $f->{slug}, dependencies => \%deps}));
    $f->{baseline} = commit_all($f); git($f, 'branch', '-f', 'dev');
    return \%deps;
}
sub active_child_case {
    my ($signal) = @_;
    my $f = run_fixture();
    my ($realgit) = grep { -x $_ } map { "$_/git" } split /:/, $ENV{PATH};
    $realgit = abs_path($realgit);
    my $ready = "$f->{bin}/ready"; my $go = "$f->{bin}/go";
    mkfifo($ready, 0600) == 0 && mkfifo($go, 0600) == 0 or die $!;
    write_file("$f->{bin}/git", <<'WRAPPER');
#!/usr/bin/env perl
use strict;
use warnings;
if ($ENV{S003_BARRIER} && join(' ', @ARGV) =~ /worktree add/) {
    open my $ready, '>', "$ENV{S003_BARRIER}/ready" or die $!;
    print {$ready} "ready\n";
    close $ready;
    open my $go, '<', "$ENV{S003_BARRIER}/go" or die $!;
    scalar <$go>;
    close $go;
}

exec {$ENV{S003_REAL_GIT}} $ENV{S003_REAL_GIT}, @ARGV;
die $!;
WRAPPER
    chmod 0755, "$f->{bin}/git" or die $!;
    my $pid = fork(); die $! unless defined $pid;
    if (!$pid) {
        $ENV{PATH} = "$f->{bin}:$ENV{PATH}";
        $ENV{S003_BARRIER} = $f->{bin}; $ENV{S003_REAL_GIT} = $realgit;
        open STDOUT, '>', "$f->{bin}/cli.out" or die $!;
        open STDERR, '>', "$f->{bin}/cli.err" or die $!;
        exec $^X, "$f->{repo}/scripts/workflow-run.pl", 'start', $f->{slug}, '--worktree', $f->{dest}, '--local' or POSIX::_exit(99);
    }
    # FIFO handshake proves the Git child is actively owned, not a timed guess.
    local $SIG{ALRM} = sub { kill 'KILL', $pid; die "active-child barrier timeout\n"; };
    alarm 20;
    open my $r, '<', $ready or die $!; is(scalar <$r>, "ready\n", 'actual Git child reached barrier'); close $r;
    kill $signal, $pid or die $!;
    waitpid($pid, 0); my $status = $?;
    if ($signal eq 'KILL') {
        is($status & 127, 9, 'launcher hard killed while child active');
        my ($rc, $out, $err) = start_run($f, 'G'); ok($rc, 'surviving child keeps exclusion'); like($err, qr/active owner/, 'kernel lock held, no stealing');
        open my $g, '>', $go or die $!; print {$g} "continue\n"; close $g;
        # Blocking lock is an event barrier: wait until supervisor AND worker
        # have exited, even though neither is this process's direct child.
        open my $lock, '<', "$f->{common}/codex-workflow-locks/$f->{slug}.lock" or die $!;
        flock($lock, LOCK_EX) or die $!; close $lock;
    } else {
        is($status >> 8, $signal eq 'INT' ? 130 : 143, 'signal stops active process group and waits');
        ok(!-e $f->{dest}, 'blocked Git child did not later create worktree');
    }
    alarm 0;
    my @paths = bsd_glob "$f->{common}/codex-workflow-runs/*/state.json";
    is(scalar @paths, 1, 'one retained durable intent'); $f->{id} = decode_json(slurp($paths[0]))->{run_id};
    my ($rc, $out, $err) = invoke($f, 'G', undef, 'resume', '--run', $f->{id}); is($rc, 0, 'actual active-child termination reconciles') or diag $err;
}
sub documentation_errors {
    my ($doc) = @_;
    my @tokens = ('workflow-run.pl start', 'workflow-run.pl status', 'workflow-run.pl preflight', 'workflow-run.pl resume', 'codex-workflow-runs', 'codex-workflow-locks', 'agent/progress/runs', 'prerequisites', '130', '143', 'S004', 'GW', 'manual bootstrap');
    my @errors = ((grep { index($doc, $_) < 0 } @tokens), ($doc =~ /S003 (?:passes GW|completes delivery)/ ? 'false GW/delivery claim' : ()));
    return @errors;
}
sub cases {
    my ($mode) = @_;
    subtest "$mode :: S003_T01_exact_identity" => sub {
        for my $slug ('003-workflow-run-state', '1000-fix_step-count') {
            my $f = run_fixture(slug => $slug); my $s = runner($f); my $e = $s->inventory($slug);
            is($e->{slug}, $slug, 'complete slug preserved'); is($e->{path}, "agent/changes/$slug.md", 'exact path');
            my ($rc, $out, $err) = start_run($f, $mode); is($rc, 0, 'valid preparation') or diag $err;
            is(state($f)->{branch}, "change/$slug", 'exact branch');
        }
    };
    subtest "$mode :: S003_T02_invalid_identity" => sub {
        my $f = run_fixture();
        for my $bad ('3-short', '../003-escape', '003-UPPER', 'change/003-name', '') {
            my ($rc) = invoke($f, $mode, undef, 'start', $bad, '--worktree', $f->{dest}, '--local'); ok($rc, "invalid slug $bad");
        }
        git($f, 'checkout', '--detach', '-q'); my ($rc) = start_run($f, $mode); ok($rc, 'detached context rejected'); ok(!-e $f->{dest}, 'no setup');
        my $s = mch::WorkflowRun->new(root => dirname($f->{repo})); rejects(sub { $s->repository }, qr/Git operation failed/, 'nonrepository');
    };
    subtest "$mode :: S003_T03_inventory_fail_closed" => sub {
        for my $variant (qw(missing unreadable empty zero duplicate id path)) {
            my $f = run_fixture();
            if ($variant eq 'missing') { unlink "$f->{repo}/agent/PLAN.md"; }
            elsif ($variant eq 'unreadable') { chmod 0000, "$f->{repo}/agent/PLAN.md" or die $!; }
            else { edit($f, 'agent/PLAN.md', sub { my $v = shift; return '' if $variant eq 'empty'; $v =~ s/003-workflow-run-state/004-other/g if $variant eq 'zero'; $v .= $v if $variant eq 'duplicate'; $v =~ s/S003/S004/g if $variant eq 'id'; $v =~ s{changes/003-workflow-run-state.md}{changes/003-other.md} if $variant eq 'path'; $v }); }
            rejects(sub { runner($f)->inventory($f->{slug}) }, qr/(?:PLAN|cannot read)/, $variant);
            chmod 0600, "$f->{repo}/agent/PLAN.md" if $variant eq 'unreadable';
            ok(!-e $f->{dest}, 'no Git mutation');
        }
    };
    subtest "$mode :: S003_T04_readiness_inputs" => sub {
        for my $path ('AGENTS.md', 'agent/PRD.md', 'agent/ARCHITECTURE.md', 'agent/IMPLEMENT.md', 'agent/changes/003-workflow-run-state.md') {
            for my $kind ('missing', 'unreadable') {
                my $f = run_fixture();
                if ($kind eq 'missing') { unlink "$f->{repo}/$path"; } else { chmod 0000, "$f->{repo}/$path" or die $!; }
                rejects(sub { runner($f)->inventory($f->{slug}) }, qr/\Q$path\E/, "$kind $path");
                chmod 0600, "$f->{repo}/$path" if $kind eq 'unreadable';
            }
        }
        my $f = run_fixture(); edit($f, 'agent/changes/003-workflow-run-state.md', sub { $_[0] . "\nTODO author this" });
        rejects(sub { runner($f)->inventory($f->{slug}) }, qr/placeholder/, 'unfinished authored document');
    };
    subtest "$mode :: S003_T05_configuration_validation" => sub {
        my $f = run_fixture();
        for my $args ([], ['wat'], ['status', '--run', '../../x'], ['start', $f->{slug}], ['start', $f->{slug}, '--worktree', $f->{dest}], ['start', $f->{slug}, '--worktree', $f->{dest}, '--local', '--remote', 'origin'], ['start', $f->{slug}, '--wat']) {
            my ($rc) = invoke($f, $mode, undef, @$args); is($rc, 2, 'usage error is 2');
        }
        my ($rc) = start_run($f, $mode, undef, '--remote', 'unknown'); ok($rc, 'unknown remote');
        my $link = dirname($f->{repo}) . '/link'; symlink dirname($f->{repo}), $link or die $!;
        $f->{dest} = "$link/escape"; ($rc) = start_run($f, $mode); ok($rc, 'symlink destination');
        $f->{dest} = "$f->{repo}/../escape"; ($rc) = start_run($f, $mode); ok($rc, 'traversal destination');
    };
    subtest "$mode :: S003_T06_missing_prerequisites" => sub {
        for my $variant (qw(manifest dependency scope revision result transitive source artifact)) {
            my $f = run_fixture(); prerequisite_fixture($f);
            my $path = "agent/progress/prerequisites/$f->{slug}.json";
            if ($variant eq 'manifest') { unlink "$f->{repo}/$path"; }
            else {
                my $v = decode_json(slurp("$f->{repo}/$path")); my $e = $v->{dependencies}{'002-dependency'};
                delete $v->{dependencies}{'002-dependency'} if $variant eq 'dependency';
                delete $v->{dependencies}{'001-dependency'} if $variant eq 'transitive';
                delete $e->{checks}[0]{$variant} if $variant =~ /^(?:scope|revision|result)$/;
                $e->{sources}{source2} = '0' x 64 if $variant eq 'source';
                $e->{checks}[0]{sha256} = '0' x 64 if $variant eq 'artifact';
                write_file("$f->{repo}/$path", encode_json($v));
            }
            my $s = runner($f); rejects(sub { $s->prerequisites($s->inventory($f->{slug}), $f->{baseline}) }, qr/(?:evidence|source|cannot read|prerequisite)/, $variant);
        }
        for my $tool (qw(git perl bash python3)) {
            my $f = run_fixture(); my $s = runner($f); my $real = $s->can('command');
            $s->{command} = sub { my @args = @_; return (127, '') if $args[0] eq $tool; local $s->{command}; return $real->($s, @args); };
            rejects(sub { $s->prerequisites({deps => []}, $f->{baseline}) }, qr/tool \Q$tool\E/, "missing executable $tool");
        }
    };
    subtest "$mode :: S003_T07_evidence_not_prose" => sub {
        my $f = run_fixture(); prerequisite_fixture($f); my $s = runner($f);
        is(scalar @{$s->prerequisites($s->inventory($f->{slug}), $f->{baseline})}, 2, 'scoped source-bound prerequisite evidence accepted');
        # Later physical/account facts are not injected into this consumer gate.
        write_file("$f->{repo}/agent/later.private", 'phones UNKNOWN; accounts UNKNOWN; legacy review absent');
        is(scalar @{$s->prerequisites($s->inventory($f->{slug}), $f->{baseline})}, 2, 'later obligations remain deferred');
        my $manifest = "$f->{repo}/agent/progress/prerequisites/$f->{slug}.json";
        my $v = decode_json(slurp($manifest)); $v->{dependencies}{'002-dependency'}{checks} = [];
        write_file($manifest, encode_json($v)); rejects(sub { $s->prerequisites($s->inventory($f->{slug}), $f->{baseline}) }, qr/evidence/, 'commit/document alone insufficient');
    };
    subtest "$mode :: S003_T08_local_preflight" => sub {
        for my $cwd ('root', 'sub', 'outside') {
            my $f = run_fixture(); make_path("$f->{repo}/sub"); $f->{cwd} = $cwd eq 'root' ? $f->{repo} : $cwd eq 'sub' ? "$f->{repo}/sub" : '/tmp';
            my ($rc, $out, $err) = start_run($f, $mode); is($rc, 0, "from $cwd") or diag $err;
            my $v = state($f); is($v->{baseline}, $f->{baseline}, 'full local SHA');
            is($v->{repository}{common}, $f->{common}, 'same canonical identity');
            like(slurp("$f->{dest}/$v->{projection}{path}"), qr/not checked/, 'remote freshness explicitly unchecked');
        }
    };
    subtest "$mode :: S003_T09_remote_baseline" => sub {
        my $f = run_fixture();
        my $new = commit_file($f, 'remote advanced'); git($f, 'push', '-q', 'origin', 'HEAD:dev');
        git($f, 'config', '--unset-all', 'remote.origin.fetch'); git($f, 'config', 'remote.origin.fetch', '+refs/heads/master:refs/remotes/origin/master');
        my $caller = git($f, 'rev-parse', 'HEAD'); my ($rc, $out, $err) = start_run($f, $mode, undef, '--remote', 'origin');
        is($rc, 0, 'explicit restricted-fetch refresh') or diag $err;
        is(state($f)->{baseline}, $new, 'select exact refreshed remote'); is(git($f, 'rev-parse', 'dev'), $f->{baseline}, 'local dev untouched'); is(git($f, 'rev-parse', 'HEAD'), $caller, 'caller unchanged');
    };
    subtest "$mode :: S003_T10_failed_refresh" => sub {
        my $f = run_fixture(); git($f, 'remote', 'set-url', 'origin', dirname($f->{repo}) . '/missing.git');
        my ($rc, $out, $err) = start_run($f, $mode, undef, '--remote', 'origin'); ok($rc, 'failed refresh nonzero'); like($err, qr/refresh failed/, 'no stale fallback'); ok(!-e $f->{dest}, 'no setup');
        my $s = runner($f); my $real = $s->can('command');
        $s->{command} = sub { return (0, 'not-a-commit') if $_[3] && $_[3] eq 'rev-parse'; return $real->($s, @_); };
        rejects(sub { $s->commit('dev') }, qr/commit/, 'invalid observation');
        for my $failure ('authentication', 'fetch', 'observation') {
            my $fixture = run_fixture(); my $r = runner($fixture); my $actual = $r->can('command');
            $r->{command} = sub {
                my @a = @_;
                return (128, 'credential SECRET must not escape') if $failure ne 'observation' && grep { $_ eq 'fetch' } @a;
                return (128, '') if $failure eq 'observation' && grep { $_ eq 'refs/remotes/origin/dev^{commit}' } @a;
                local $r->{command}; return $actual->($r, @a);
            };
            rejects(sub { $r->target({mode => 'remote', remote => 'origin'}) }, qr/(?:refresh failed|Git operation failed)/, "$failure failure independently blocks");
            unlike($@, qr/SECRET/, 'raw child diagnostics not exposed'); ok(!-e $fixture->{dest}, 'no setup');
        }
    };
    subtest "$mode :: S003_T11_missing_baseline" => sub {
        for my $ref ('missing', 'HEAD:content', '0' x 40) {
            my $f = run_fixture(); rejects(sub { runner($f)->commit($ref) }, qr/(?:Git operation failed|commit)/, 'noncommit/missing ref');
        }
        my $f = run_fixture(); git($f, 'branch', '-D', 'dev'); my ($rc) = start_run($f, $mode); ok($rc, 'missing dev fails'); ok(!-e $f->{dest}, 'no initialization');
        $f = run_fixture(); git($f->{remote}, 'update-ref', '-d', 'refs/heads/dev'); ($rc) = start_run($f, $mode, undef, '--remote', 'origin'); ok($rc, 'remote dev missing fails despite cached ref');
    };
    subtest "$mode :: S003_T12_isolated_setup" => sub {
        my $f = run_fixture(); write_file("$f->{repo}/secret.private", 'SECRET sentinel'); my $before = snapshot($f); my $remote = git($f->{remote}, 'show-ref');
        my ($rc, $out, $err) = start_run($f, $mode); is($rc, 0, 'fresh setup') or diag $err;
        is(git($f, 'branch', '--show-current'), 'master', 'caller checkout stays'); is(git($f, 'status', '--porcelain=v1'), '', 'caller index/files clean');
        is(git($f->{dest}, 'rev-parse', 'HEAD'), $f->{baseline}, 'worktree exact SHA'); is(git($f->{remote}, 'show-ref'), $remote, 'remote refs untouched');
        is(slurp("$f->{repo}/secret.private"), 'SECRET sentinel', 'ignored user file untouched'); unlike($out, qr/SECRET sentinel/, 'not echoed');
    };
    subtest "$mode :: S003_T13_dirty_input_preserved" => sub {
        for my $kind (qw(staged unstaged deleted hidden submodule)) {
            my $f = run_fixture();
            if ($kind eq 'deleted') { unlink "$f->{repo}/content"; }
            elsif ($kind eq 'hidden') { write_file("$f->{repo}/.hidden", 'protected'); }
            elsif ($kind eq 'submodule') {
                my $sub = fixture(); git($f, '-c', 'protocol.file.allow=always', 'submodule', 'add', '-q', $sub->{repo}, 'nested'); commit_all($f);
                write_file("$f->{repo}/nested/content", 'dirty nested'); git($f, 'config', 'submodule.nested.ignore', 'all');
            } else { write_file("$f->{repo}/content", 'protected'); git($f, 'add', 'content') if $kind eq 'staged'; }
            git($f, 'config', 'status.showUntrackedFiles', 'no'); my $before = snapshot($f);
            my ($rc) = start_run($f, $mode, undef, '--remote', 'origin'); ok($rc, "$kind rejected"); is(snapshot($f), $before, 'refs/index/status untouched'); ok(!-e $f->{dest}, 'no setup');
        }
    };
    subtest "$mode :: S003_T14_existing_setup_rejected" => sub {
        for my $kind (qw(local remote empty occupied run)) {
            my $f = run_fixture();
            git($f, 'branch', "change/$f->{slug}") if $kind eq 'local';
            git($f, 'update-ref', "refs/remotes/origin/change/$f->{slug}", $f->{baseline}) if $kind eq 'remote';
            if ($kind eq 'empty' || $kind eq 'occupied') { mkdir $f->{dest}; write_file("$f->{dest}/keep", 'keep') if $kind eq 'occupied'; }
            if ($kind eq 'run') { start_run($f, $mode); }
            my $before = snapshot($f); my ($rc) = start_run($f, $mode); ok($rc, "$kind existing rejects"); is(snapshot($f), $before, 'existing state preserved');
        }
    };
    subtest "$mode :: S003_T15_setup_races" => sub {
        for my $kind (qw(path branch dirty)) {
            my $f = run_fixture(); my $hook = sub { return unless $_[0] eq 'after-refresh'; if ($kind eq 'path') { mkdir $f->{dest}; write_file("$f->{dest}/keep", 'race'); } elsif ($kind eq 'branch') { git($f, 'branch', "change/$f->{slug}"); } else { write_file("$f->{repo}/.race", 'race'); } };
            my ($rc) = start_run($f, $mode, $hook); ok($rc, "$kind race rejects nonforcing");
            is(slurp("$f->{dest}/keep"), 'race', 'concurrent user file retained') if $kind eq 'path';
            is(git($f, 'rev-parse', "change/$f->{slug}"), $f->{baseline}, 'concurrent branch retained') if $kind eq 'branch';
            is(slurp("$f->{repo}/.race"), 'race', 'dirty race retained') if $kind eq 'dirty';
        }
    };
    subtest "$mode :: S003_T16_state_round_trip" => sub {
        my $f = run_fixture(); my ($rc) = start_run($f, $mode); is($rc, 0, 'start'); my $v = state($f);
        is_deeply(runner($f)->read_state($f->{id}), $v, 'full exact roundtrip'); ok($v->{generation} >= 2, 'generation advances'); like($v->{updated_utc}, qr/^\d{4}-\d\d-\d\dT.*Z$/, 'UTC'); is($v->{updated_utc}, '2026-10-30T00:00:00Z', 'injected deterministic unit clock') if $mode eq 'U';
        is_deeply($v->{checks}, [], 'no invented check'); is_deeply($v->{reviews}, [], 'no invented review'); ok(!defined $v->{merge} && !$v->{run_complete}, 'no merge/completion');
        is($v->{intent}, $v->{baseline}, 'intent SHA'); is($v->{source}, $v->{baseline}, 'source SHA');
    };
    subtest "$mode :: S003_T17_invalid_state" => sub {
        my $f = run_fixture(); start_run($f, $mode); my $s = runner($f); my $v = state($f);
        for my $kind (qw(missing schema phase artifact complete)) {
            my $bad = clone_value($v); delete $bad->{baseline} if $kind eq 'missing'; $bad->{schema} = 99 if $kind eq 'schema'; $bad->{phase} = 'merged' if $kind eq 'phase'; $bad->{artifacts} = [{path => '../secret', sha256 => 'a' x 64}] if $kind eq 'artifact'; $bad->{run_complete} = JSON::PP::true if $kind eq 'complete';
            rejects(sub { $s->validate_state($bad) }, qr/(?:missing|unsupported|unsafe)/, $kind);
        }
        for my $json ('{"schema":1,"schema":1}', '{"x":{"a":1,"\u0061":2}}', '{', '{"x":') { rejects(sub { $s->decode($json) }, qr/(?:duplicate|malformed)/, 'invalid JSON fails closed'); }
        $s->lock($f->{slug}); my $bad = clone_value($v); $bad->{phase} = 'preparing'; rejects(sub { $s->save_state($bad, $v->{generation}) }, qr/transition/, 'backward transition');
        is_deeply(state($f), $v, 'original bytes unchanged');
        for my $kind (qw(timestamp next_action gates projection blocker configuration)) {
            my $bad = clone_value($v);
            $bad->{updated_utc} = 'yesterday' if $kind eq 'timestamp';
            $bad->{next_action} = '' if $kind eq 'next_action';
            delete $bad->{gates}{review} if $kind eq 'gates';
            $bad->{projection}{sha256} = 'tampered' if $kind eq 'projection';
            $bad->{blockers} = [{reason => 'missing owner/action'}] if $kind eq 'blocker';
            $bad->{config}{target} = 'master' if $kind eq 'configuration';
            rejects(sub { $s->validate_state($bad) }, qr/invalid/, "semantic state validation: $kind");
        }
    };
    subtest "$mode :: S003_T18_atomic_write_failures" => sub {
        my $f = run_fixture(); my $path = "$f->{common}/atomic.json"; my $s = runner($f); $s->atomic($path, 'previous');
        for my $event (qw(create write short-write flush file-sync rename)) {
            $s->{hook} = failure_at($event); rejects(sub { $s->atomic($path, 'replacement') }, qr/injected/, "fault $event"); is(slurp($path), 'previous', 'last durable bytes retained');
        }
        my @temps = bsd_glob "$f->{common}/.workflow-*"; is(scalar @temps, 0, 'temporary file never promoted');
    };
    subtest "$mode :: S003_T19_post_rename_failure" => sub {
        my $f = run_fixture(); my $path = "$f->{common}/atomic.json"; my $s = runner($f); $s->atomic($path, 'previous'); $s->{hook} = failure_at('directory-sync');
        rejects(sub { $s->atomic($path, 'new valid bytes') }, qr/injected/, 'directory sync failure'); is(slurp($path), 'new valid bytes', 'do not assume rename rolled back');
        ($s->{hook}) = (); my ($rc) = start_run($f, $mode, sub { my ($event, $r) = @_; die "post-rename fault\n" if $event eq 'directory-sync' && $r->{state} && -e $r->state_path($r->{state}{run_id}); });
        ok($rc, 'post-rename run failure'); ok($f->{id}, 'intent on disk remains discoverable');
        ($rc) = invoke($f, $mode, undef, 'resume', '--run', $f->{id}); is($rc, 0, 'reread generation and resume');
    };
    subtest "$mode :: S003_T20_generation_guard" => sub {
        my $f = run_fixture(); start_run($f, $mode); my $s = runner($f); $s->lock($f->{slug}); my $old = state($f); my $new = clone_value($old); $new->{extra_extension} = {keep => 1};
        $s->save_state($new, $old->{generation}); rejects(sub { $s->save_state($old, $old->{generation}) }, qr/stale generation/, 'obsolete writer'); is_deeply(state($f)->{extra_extension}, {keep => 1}, 'newer extension retained');
    };
    subtest "$mode :: S003_T21_portable_projection" => sub {
        my $f = run_fixture(); start_run($f, $mode); my $v = state($f); my $bytes = slurp("$f->{dest}/$v->{projection}{path}"); my $p = decode_json($bytes);
        is($p->{generation}, $v->{generation}, 'matching generations'); is(sha256_hex($bytes), $v->{projection}{sha256}, 'runtime hashes exact projection'); unlike($bytes, qr{(?:/tmp/|://|SECRET|raw.output)}, 'sanitized'); is(git($f->{dest}, 'diff', '--cached', '--name-only'), '', 'nothing staged');
    };
    subtest "$mode :: S003_T22_projection_reconciliation" => sub {
        for my $kind (qw(absent stale tampered failure)) {
            my $f = run_fixture(); my ($rc) = start_run($f, $mode, $kind eq 'failure' ? failure_at('before-projection') : undef); my $v = state($f); my $path = "$f->{dest}/$v->{projection}{path}";
            if ($kind eq 'absent') { unlink $path; }
            elsif ($kind eq 'tampered') { write_file($path, 'user tampered'); }
            elsif ($kind eq 'stale') { my $s = runner($f); $s->lock($f->{slug}); push @{$v->{observations}}, {projection_sha256 => $v->{projection}{sha256}}; $s->save_state($v, $v->{generation}); }
            ($rc) = invoke($f, $mode, undef, 'preflight', '--run', $f->{id}); ok($rc, "$kind is not prepared success");
            ($rc) = invoke($f, $mode, undef, 'resume', '--run', $f->{id}); is($rc == 0 ? 0 : 1, $kind eq 'tampered' ? 1 : 0, 'repair only provably owned projection');
            is(slurp($path), 'user tampered', 'user edit untouched') if $kind eq 'tampered';
        }
    };
    subtest "$mode :: S003_T23_legacy_and_private_artifacts" => sub {
        my $f = run_fixture(); make_path("$f->{common}/codex-plan-runs"); write_file("$f->{common}/codex-plan-runs/old.tsv", 'success SECRET'); write_file("$f->{repo}/raw.private", 'SECRET');
        make_path("$f->{common}/mch-workflow-evidence/$f->{slug}/observation");
        write_file("$f->{common}/mch-workflow-evidence/$f->{slug}/observation/receipt.json", '{"phase":"review","outcome":"clean","raw":"SECRET"}');
        my ($rc, $out) = start_run($f, $mode); is($rc, 0, 'legacy artifacts do not set gates'); unlike($out, qr/SECRET/, 'no secret output'); is(slurp("$f->{common}/codex-plan-runs/old.tsv"), 'success SECRET', 'preserved TSV');
        is_deeply(state($f)->{reviews}, [], 'legacy success not imported');
        is(scalar @{state($f)->{artifacts}}, 1, 'immutable diagnostic retained by digest reference');
        my $v = state($f); unlike(slurp("$f->{dest}/$v->{projection}{path}"), qr/SECRET/, 'diagnostic raw content not projected');
    };
    subtest "$mode :: S003_T24_precise_bookkeeping_dirt" => sub {
        my $f = run_fixture(); start_run($f, $mode); my ($rc) = invoke($f, $mode, undef, 'preflight', '--run', $f->{id}); is($rc, 0, 'exact projection accepted');
        write_file("$f->{dest}/agent/progress/unrelated.json", 'user data');
        ($rc) = invoke($f, $mode, undef, 'resume', '--run', $f->{id}); ok($rc, 'unrelated progress file blocks'); is(slurp("$f->{dest}/agent/progress/unrelated.json"), 'user data', 'preserved');
    };
    subtest "$mode :: S003_T25_single_owner" => sub {
        my $f = run_fixture(); my $s = runner($f); $s->lock($f->{slug}); $s->diagnostic('r-' . 'a' x 32); my $bytes = slurp("$f->{common}/codex-workflow-locks/$f->{slug}.lock");
        my ($rc) = start_run($f, $mode); ok($rc, 'same repository contender excluded');
        my $linked = dirname($f->{repo}) . '/linked'; git($f, 'worktree', 'add', '-qb', 'other', $linked);
        my $other = mch::WorkflowRun->new(root => $linked); $other->repository; rejects(sub { $other->lock($f->{slug}) }, qr/active owner/, 'linked contender excluded'); is(slurp("$f->{common}/codex-workflow-locks/$f->{slug}.lock"), $bytes, 'diagnostics unchanged');
    };
    subtest "$mode :: S003_T26_lock_lifetime" => sub {
        my $f = run_fixture(); my $s = runner($f); $s->lock($f->{slug}); $s->diagnostic('r-' . 'b' x 32);
        write_file("$f->{common}/codex-workflow-locks/$f->{slug}.lock", '{"pid":999999,"age":"ancient"}');
        rejects(sub { runner($f)->lock($f->{slug}) }, qr/active owner/, 'misleading metadata cannot steal'); delete $s->{lock}; my $next = runner($f); $next->lock($f->{slug}); pass('kernel unlock, not PID/age, enables reconciliation');
        active_child_case('KILL') if $mode eq 'G';
    };
    subtest "$mode :: S003_T27_lock_domains" => sub {
        my $f = run_fixture(); open my $outer, '>', "$f->{common}/codex-plan-run.lock" or die $!; flock($outer, 2) or die $!;
        my $a = runner($f); $a->lock($f->{slug}); my $b = runner($f); $b->lock('004-other'); pass('outer plan and different slug locks independent'); rejects(sub { runner($f)->lock($f->{slug}) }, qr/active owner/, 'same slug excluded');
    };
    subtest "$mode :: S003_T28_idempotent_resume" => sub {
        my $f = run_fixture(); start_run($f, $mode); my $v = state($f);
        for (1..2) { my ($rc, $out, $err) = invoke($f, $mode, undef, 'resume', '--run', $f->{id}); is($rc, 0, 'explicit repeat resume') or diag $err; }
        my $last = state($f); for (qw(run_id branch worktree baseline source intent)) { is($last->{$_}, $v->{$_}, "immutable $_"); }
        is(scalar(runner($f)->worktrees), 2, 'no duplicate worktree');
    };
    subtest "$mode :: S003_T29_resume_before_creation" => sub {
        my $f = run_fixture(); my ($rc) = start_run($f, $mode, failure_at('after-intent')); ok($rc, 'intent interrupted'); ok(!-e $f->{dest}, 'no Git creation');
        ($rc) = invoke($f, $mode, undef, 'resume', '--run', $f->{id}); is($rc, 0, 'intent resumed'); is(git($f->{dest}, 'rev-parse', 'HEAD'), $f->{baseline}, 'original baseline');
    };
    subtest "$mode :: S003_T30_resume_after_creation" => sub {
        my $f = run_fixture(); my ($rc) = start_run($f, $mode, failure_at('after-git')); ok($rc, 'post-Git interruption'); ok(-d $f->{dest}, 'created worktree retained'); my $head = git($f->{dest}, 'rev-parse', 'HEAD');
        ($rc) = invoke($f, $mode, undef, 'resume', '--run', $f->{id}); is($rc, 0, 'owned Git outcome reconciled'); is(git($f->{dest}, 'rev-parse', 'HEAD'), $head, 'no reset');
    };
    subtest "$mode :: S003_T31_source_drift" => sub {
        for my $equal (0, 1) {
            my $f = run_fixture(); start_run($f, $mode); git($f->{dest}, 'config', 'user.name', 'Test'); git($f->{dest}, 'config', 'user.email', 'test@example.invalid');
            write_file("$f->{dest}/content", 'changed') unless $equal; git($f->{dest}, 'add', 'content') unless $equal; git($f->{dest}, 'commit', '--allow-empty', '-qm', 'changed source');
            my $head = git($f->{dest}, 'rev-parse', 'HEAD'); my ($rc, $out, $err) = invoke($f, $mode, undef, 'resume', '--run', $f->{id}); ok($rc, 'changed commit blocked including equal tree'); like($err, qr/source drift/, 'drift diagnosis'); is(state($f)->{baseline}, $f->{baseline}, 'baseline preserved'); is(git($f->{dest}, 'rev-parse', 'HEAD'), $head, 'no reset');
            ok(grep({ ($_->{source_new} // '') eq $head && !$_->{evidence_usable} } @{state($f)->{observations}}), 'old/new source observation retained');
        }
    };
    subtest "$mode :: S003_T32_target_drift" => sub {
        for my $remote (0, 1) {
            my $f = run_fixture(); start_run($f, $mode, undef, $remote ? ('--remote', 'origin') : ('--local'));
            my $new = commit_file($f, 'advanced target');
            if ($remote) { git($f, 'push', '-q', 'origin', 'HEAD:dev'); } else { git($f, 'branch', '-f', 'dev'); }
            my ($rc, $out, $err) = invoke($f, $mode, undef, 'resume', '--run', $f->{id}); ok($rc, 'target drift blocked'); like($err, qr/target drift/, 'S004 required'); is(state($f)->{baseline}, $f->{baseline}, 'immutable baseline'); ok(grep({ ($_->{target_new} // '') eq $new } @{state($f)->{observations}}), 'new target recorded');
        }
    };
    subtest "$mode :: S003_T33_resume_identity_conflicts" => sub {
        for my $kind (qw(branch missing path repository config partial owner owner-missing)) {
            my $f = run_fixture(); start_run($f, $mode); my $v = state($f);
            if ($kind eq 'branch') { git($f->{dest}, 'checkout', '-qb', 'wrong'); }
            elsif ($kind eq 'missing') { rename $f->{dest}, "$f->{dest}-moved" or die $!; }
            elsif ($kind eq 'path') { $v->{worktree} .= '-wrong'; }
            elsif ($kind eq 'repository') { $v->{repository}{id} = 'wrong'; }
            elsif ($kind eq 'config') { $v->{config}{target} = 'master'; }
            elsif ($kind eq 'owner' || $kind eq 'owner-missing') {
                my $path = runner($f)->owner_path($v);
                if ($kind eq 'owner') { write_file($path, 'different run owner'); } else { unlink $path or die $!; }
            }
            else { git($f, 'worktree', 'remove', '--force', $f->{dest}); }
            write_file("$f->{common}/codex-workflow-runs/$f->{id}/state.json", encode_json($v)) if $kind =~ /^(path|repository|config)$/;
            my ($rc) = invoke($f, $mode, undef, 'resume', '--run', $f->{id}); ok($rc, "$kind not adopted");
        }
        my $f = run_fixture(); start_run($f, $mode, undef, '--remote', 'origin');
        git($f, 'remote', 'set-url', 'origin', dirname($f->{repo}) . '/changed.git');
        my ($rc, $out, $err) = invoke($f, $mode, undef, 'resume', '--run', $f->{id}); ok($rc, 'remote URL configuration cannot silently change'); like($err, qr/remote identity changed/, 'reject before fetch');
        $f = run_fixture(); prerequisite_fixture($f); start_run($f, $mode);
        edit($f, "agent/progress/prerequisites/$f->{slug}.json", sub { my $v = decode_json(shift); $v->{dependencies}{'002-dependency'}{checks}[0]{scope} .= ' changed'; encode_json($v) }); commit_all($f, 'changed effective evidence');
        ($rc, $out, $err) = invoke($f, $mode, undef, 'resume', '--run', $f->{id}); ok($rc, 'effective evidence snapshot cannot silently change'); like($err, qr/prerequisite configuration changed/, 'requires explicit reconciliation');
    };
    subtest "$mode :: S003_T34_no_inferred_resume" => sub {
        my $f = run_fixture(); my ($rc) = invoke($f, $mode, undef, 'resume', '--run', 'r-' . 'a' x 32); ok($rc, 'no runtime cannot resume');
        make_path("$f->{common}/codex-plan-runs"); write_file("$f->{common}/codex-plan-runs/old.tsv", 'merged'); ($rc) = invoke($f, $mode, undef, 'resume', '--run', 'r-' . 'a' x 32); ok($rc, 'legacy success not imported');
        start_run($f, $mode); my $v = state($f); $v->{phase} = 'merged'; write_file("$f->{common}/codex-workflow-runs/$f->{id}/state.json", encode_json($v)); ($rc) = invoke($f, $mode, undef, 'resume', '--run', $f->{id}); ok($rc, 'later phase rejected');
    };
    # Real process signal/kill tests are installed separately below. Keeping
    # constructor signal hooks here also exercises interruption bookkeeping.
    subtest "$mode :: S003_T35_signal_recovery" => sub {
        for my $sig ('INT', 'TERM') {
            for my $boundary ('after-intent', 'after-git', 'before-projection') {
                my $f = run_fixture(); my ($rc) = start_run($f, $mode, sub { kill $sig, $$ if $_[0] eq $boundary; }); is($rc, $sig eq 'INT' ? 130 : 143, "$sig at $boundary"); is(state($f)->{phase}, 'interrupted', 'durable interrupted state');
                ($rc) = invoke($f, $mode, undef, 'resume', '--run', $f->{id}); is($rc, 0, 'explicit resume recovers');
            }
        }
        if ($mode eq 'G') { active_child_case('INT'); active_child_case('TERM'); }
    };
    subtest "$mode :: S003_T36_hard_kill_recovery" => sub {
        for my $boundary ('before-intent', 'after-intent', 'after-git', 'before-projection', 'after-projection') {
            my $f = run_fixture(); my $pid = fork(); die $! unless defined $pid;
            if (!$pid) { open STDOUT, '>', '/dev/null'; open STDERR, '>', '/dev/null'; start_run($f, $mode, sub { kill 'KILL', $$ if $_[0] eq $boundary; }); POSIX::_exit(99); }
            waitpid($pid, 0); is($? & 127, 9, "actual SIGKILL $boundary");
            my @states = bsd_glob "$f->{common}/codex-workflow-runs/*/state.json";
            if ($boundary eq 'before-intent') { is(scalar @states, 0, 'no partial intent accepted'); ok(!-e $f->{dest}, 'no Git effect'); next; }
            is(scalar @states, 1, 'one durable run'); $f->{id} = decode_json(slurp($states[0]))->{run_id};
            my ($rc, $out, $err) = invoke($f, $mode, undef, 'resume', '--run', $f->{id}); is($rc, 0, 'resume reconciles real killed owner') or diag $err;
            is(scalar(runner($f)->worktrees), 2, 'never duplicates Git setup');
        }
    };
    subtest "$mode :: S003_T37_git_and_storage_failure" => sub {
        my $f = run_fixture(); my ($rc) = start_run($f, $mode, sub { if ($_[0] eq 'before-git') { mkdir $f->{dest}; write_file("$f->{dest}/user", 'protected'); } }); ok($rc, 'real worktree-add failure nonzero'); is(slurp("$f->{dest}/user"), 'protected', 'partial user data preserved'); is(state($f)->{phase}, 'blocked', 'intent retained');
        my $s = runner($f); rejects(sub { $s->atomic('/proc/self/workflow-no-write.json', 'bytes') }, qr/(?:create|replace|read|owned)/, 'real unwritable filesystem');
        for my $kind ('runtime', 'projection') {
            my $fixture = run_fixture(); my $directory = $kind eq 'runtime' ? "$fixture->{common}/codex-workflow-runs" : "$fixture->{dest}/agent/progress/runs";
            if ($kind eq 'runtime') { make_path($directory); chmod 0500, $directory or die $!; }
            my $hook = $kind eq 'projection' ? sub { return unless $_[0] eq 'before-projection'; make_path($directory); chmod 0500, $directory or die $!; } : undef;
            my ($status) = start_run($fixture, $mode, $hook); ok($status, "actual unwritable $kind directory fails");
            chmod 0700, $directory or die $!;
            ok(!-e $fixture->{dest}, 'runtime allocation failure precedes Git setup') if $kind eq 'runtime';
            if ($kind eq 'projection') { is(state($fixture)->{phase_result}, 'failed', 'no prepared acknowledgement'); ($status) = invoke($fixture, $mode, undef, 'resume', '--run', $fixture->{id}); is($status, 0, 'restore storage and reconcile owned intent'); }
        }
    };
    subtest "$mode :: S003_T38_status_is_inspection" => sub {
        my $f = run_fixture(); start_run($f, $mode); my $path = "$f->{common}/codex-workflow-runs/$f->{id}/state.json"; my $before = slurp($path); my $refs = git($f, 'show-ref');
        my ($rc, $out, $err) = invoke($f, $mode, undef, 'status', '--run', $f->{id}); is($rc, 0, 'valid read'); my $o = decode_json($out); ok(!$o->{run_complete}, 'not approval'); ok(!$o->{inspection}{reconciliation_required}, 'consistent snapshot'); is(slurp($path), $before, 'state bytes unchanged'); is(git($f, 'show-ref'), $refs, 'refs unchanged');
        my $owner = runner($f); $owner->lock($f->{slug}); ($rc, $out) = invoke($f, $mode, undef, 'status', '--run', $f->{id}); is($rc, 0, 'inspection works while owner active'); ok(decode_json($out)->{inspection}{active_writer}, 'active owner reported');
        write_file($path, '{'); ($rc) = invoke($f, $mode, undef, 'status', '--run', $f->{id}); ok($rc, 'malformed read fails'); is(slurp($path), '{', 'corrupt file not repaired by status');
    };
    subtest "$mode :: S003_T39_preparation_only" => sub {
        my $f = run_fixture(); my @commands;
        my $observe = sub { my ($event, $s) = @_; return unless $event eq 'after-refresh'; my $actual = $s->can('command'); $s->{command} = sub { my @a = @_; push @commands, \@a; local $s->{command}; return $actual->($s, @a); }; };
        my ($rc, $out) = start_run($f, $mode, $observe); is($rc, 0, 'phase passed'); my $v = decode_json($out); ok(!$v->{run_complete}, 'entire run incomplete');
        for my $op ('preflight', 'resume') { ($rc, $out) = invoke($f, $mode, undef, $op, '--run', $f->{id}); is($rc, 0, "$op phase only"); ok(!decode_json($out)->{run_complete}, 'no delivery claim'); }
        is(git($f, 'rev-parse', 'dev'), $f->{baseline}, 'no merge'); is(git($f, 'rev-parse', 'HEAD'), $f->{baseline}, 'no commit'); is_deeply(state($f)->{checks}, [], 'no check/model dispatch');
        ok(@commands > 0, 'command observer exercised');
        ok(!grep({ grep { /\A(?:codex|make|push|commit|merge|reset|stash|gh)\z/ } @$_ } @commands), 'recording command stub proves no later dispatch');
    };
    subtest "$mode :: S003_T40_usage_and_bootstrap_contract" => sub {
        my $doc = slurp("$scripts/README.md");
        my @errors = documentation_errors($doc); is_deeply(\@errors, [], 'README contract validator passes actual documentation');
        for my $token ('workflow-run.pl start', 'workflow-run.pl status', 'workflow-run.pl preflight', 'workflow-run.pl resume', 'codex-workflow-runs', 'codex-workflow-locks', 'agent/progress/runs', 'prerequisites', '130', '143', 'S004', 'GW', 'manual bootstrap') {
            my $bad = $doc; $bad =~ s/\Q$token\E//g; ok(scalar(documentation_errors($bad)), "missing contract $token fails validator");
        }
        ok(scalar(documentation_errors($doc . '\nS003 passes GW')), 'false GW claim fails validator');
    };
}
1;
