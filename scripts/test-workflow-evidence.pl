#!/usr/bin/env perl
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/lib", "$FindBin::Bin/test-lib";
use Cwd qw(getcwd);
use File::Path qw(make_path);
use JSON::PP qw(decode_json);
use Test::More;
use ReleaseTest;
use mch::WorkflowEvidence qw(save_receipt delivery_status implementation_outcome);

sub load_json {
    open my $fh, '<:raw', $_[0] or die $!;
    local $/;
    return decode_json(<$fh>);
}

my $cwd = getcwd();
my $f = fixture();
chdir $f->{repo} or die $!;
my $slug = '123-evidence';
my $base = git($f, 'rev-parse', 'dev');
git($f, 'checkout', '-q', '-b', "change/$slug", 'dev');
make_path('agent');
write_file('agent/handoff.md', 'Review/commit/merge: not run');
git($f, 'add', 'agent');
git($f, 'commit', '-q', '-m', 'historical implementation snapshot');
my $source = commit_file($f, 'implemented behavior');
my $tree = git($f, 'rev-parse', 'HEAD^{tree}');

subtest 'WF-EVIDENCE-R01 missing receipts do not invent completion or mutate Git' => sub {
    my $before = git($f, 'status', '--porcelain');
    my $state = delivery_status($slug, $base);
    is($state->{integration}, 'unverified', 'no receipt is not integration evidence');
    is($state->{review}, 'unverified', 'no receipt is not review evidence');
    is($state->{checks}, 'inspect-required-checks', 'checks need independent inspection');
    is(git($f, 'status', '--porcelain'), $before, 'read-only inspection preserves files');
};

my $squash = git($f, 'commit-tree', $tree, '-p', $base, '-m', "Implement change $slug");
git($f, 'update-ref', 'refs/heads/dev', $squash);
subtest 'WF-EVIDENCE-R01 integrated dependencies do not need predecessor review receipts' => sub {
    my $state = delivery_status($slug, 'dev');
    is($state->{integration}, 'verified', 'Git alone establishes integration');
    is($state->{merge_commit}, $squash, 'exact integrated commit recorded');
    is($state->{review}, 'unverified', 'missing history remains unknown, not a dependency veto');
    is(scalar @{$state->{receipts}}, 0, 'no replacement handoff or receipt created');
};

my $review = { phase => 'review', mode => 'code', source => $source, tree => $tree,
    baseline => $base, outcome => 'clean', response => 'No issues found.' };
my $path = save_receipt($slug, $review);
subtest 'WF-EVIDENCE-R02 immutable observations retain results outside working tree' => sub {
    like($path, qr{\.git/mch-workflow-evidence/123-evidence/[^/]+/receipt\.json$}, 'private Git-metadata location');
    is(load_json($path)->{response}, 'No issues found.', 'review text survives temp cleanup');
    is(git($f, 'status', '--porcelain'), '', 'evidence never becomes staging dirt');
    my $other = save_receipt($slug, $review);
    isnt($path, $other, 'each observation has its own identity');
    ok(-f $path, 'earlier review is not overwritten');
};

my $merge = { phase => 'merge', source => $source, tree => $tree, baseline => $base,
    outcome => 'verified', merge_commit => $squash };
save_receipt($slug, $merge);
git($f, 'update-ref', 'refs/heads/dev', $squash);
subtest 'WF-EVIDENCE-R01 stale handoff cannot veto actual review and integration' => sub {
    my $state = delivery_status($slug, 'dev');
    is($state->{integration}, 'verified', 'squash is on selected dev');
    is($state->{review}, 'verified', 'review is bound to exact tree and baseline');
    is($state->{reviewed_source}, $source, 'original reviewed source retained despite squash');
    is($state->{checks}, 'inspect-required-checks', 'review and merge cannot fabricate checks');
    is(load_json($path)->{source}, $source, 'original commit binding survives');
    open my $fh, '<', 'agent/handoff.md' or die $!;
    is(<$fh>, 'Review/commit/merge: not run', 'historical note need not be synchronized');
    is(delivery_status($slug, $base)->{integration}, 'unverified', 'receipt cannot approve another baseline');
};

subtest 'WF-EVIDENCE-R04 stale failed interrupted or document reviews never pass' => sub {
    for my $change (
        { outcome => 'failed' }, { outcome => 'started' }, { outcome => 'findings' },
        { tree => git($f, 'rev-parse', "$base\^{tree}") }, { baseline => $source }
    ) {
        save_receipt($slug, { %$review, %$change });
        save_receipt($slug, $merge);
        my $state = delivery_status($slug, 'dev');
        is($state->{review}, 'unverified', 'latest invalid code review cannot reuse old clean result');
        is($state->{integration}, 'verified', 'review diagnostics are not a downstream integration gate');
    }
    save_receipt('124-document-only', { %$review, mode => 'document' });
    save_receipt('124-document-only', $merge);
    is(delivery_status('124-document-only', 'dev')->{review}, 'unverified', 'document review is not code review');
    save_receipt($slug, { %$merge, outcome => 'started' });
    is(delivery_status($slug, 'dev')->{integration}, 'verified', 'interrupted new attempt does not undo existing Git integration');
};

subtest 'WF-EVIDENCE-R02 shared worktrees see same receipts' => sub {
    my $linked = "$f->{repo}-linked";
    git($f, 'worktree', 'add', '--detach', $linked, 'dev');
    chdir $linked or die $!;
    my $state = delivery_status($slug, 'dev');
    ok(@{$state->{receipts}} > 0, 'shared common Git directory retains evidence across worktrees');
    chdir $f->{repo} or die $!;
};

subtest 'WF-EVIDENCE-R04 malformed and incomplete observations do not become success' => sub {
    my $bad = save_receipt('125-bad', $merge);
    write_file($bad, '{bad json');
    my $bad_state = delivery_status('125-bad', 'dev');
    like($bad_state->{diagnostic_errors}[0], qr/invalid/, 'corrupt record is explicitly reported');
    is($bad_state->{review}, 'unverified', 'corrupt record is not passing review');
    write_file($bad, '{"schema":2,"slug":"125-bad"}');
    like(delivery_status('125-bad', 'dev')->{diagnostic_errors}[0], qr/unsupported/, 'unknown version is reported');
    unlink $bad or die $!;
    my $state = delivery_status('125-bad', 'dev');
    is($state->{integration}, 'unverified', 'interrupted publication cannot pass');
    is(scalar @{$state->{incomplete_observations}}, 1, 'partial write is visible');
    my $conflict = save_receipt($slug, { %$merge, tree => '0' x 40 });
    my $conflicting = delivery_status($slug, 'dev');
    like($conflicting->{diagnostic_errors}[0], qr/conflicts with Git/, 'Git rejects conflicting merge observation');
    is($conflicting->{integration}, 'verified', 'broken diagnostic data cannot undo Git integration');
    is($conflicting->{review}, 'unverified', 'broken diagnostics do not claim a passing review');
    unlink $conflict or die $!;
    eval { save_receipt('../escape', $merge) };
    like($@, qr/invalid evidence slug/, 'path traversal rejected');
    my $root = git($f, 'rev-parse', '--git-common-dir') . '/mch-workflow-evidence';
    write_file("$root/127-unwritable", 'not a directory');
    eval { save_receipt('127-unwritable', $merge) };
    ok($@, 'filesystem failure cannot report publication success');
};

subtest 'WF-EVIDENCE-R03 implementation outcomes are explicit not inferred from prose' => sub {
    my $file = "$f->{bin}/outcome.json";
    is(implementation_outcome($file), 'invalid', 'missing outcome rejected');
    for my $outcome ('complete', 'blocked', 'failed') {
        write_file($file, '{"schema":1,"outcome":"' . $outcome . '"}');
        is(implementation_outcome($file), $outcome, "explicit $outcome is preserved");
    }
    for my $invalid ('{}', '{"schema":1,"outcome":"success"}', '[]', 'Done.',
        '{"schema":2,"outcome":"complete"}', '{"schema":1,"outcome":{}}') {
        write_file($file, $invalid);
        is(implementation_outcome($file), 'invalid', 'malformed or unsupported outcome rejected');
    }
};

subtest 'WF-EVIDENCE-R01 ambiguous commit identity cannot choose the first match' => sub {
    my $duplicate = git($f, 'commit-tree', $tree, '-p', $squash, '-m', "Implement change $slug");
    git($f, 'update-ref', 'refs/heads/dev', $duplicate);
    my $state = delivery_status($slug, 'dev');
    is($state->{integration}, 'ambiguous', 'duplicate exact markers need identity resolution');
    is(scalar @{$state->{integration_candidates}}, 2, 'both commit identities are reported');
    git($f, 'update-ref', 'refs/heads/dev', $squash);
};

chdir $cwd or die $!;
done_testing();
