#!/usr/bin/env perl
# Test-only external CLI adapter. Production has no fault-disabling env flags.
use strict;
use warnings;
use lib "$ENV{WORKFLOW_E2E_ROOT}/scripts/lib";
use mch::WorkflowRun;
use JSON::PP;
use IO::Handle;
STDOUT->autoflush(1);
my $fired = 0;
my $hook = sub {
    my ($event, $s) = @_;
    my ($action, $boundary) = split /:/, $ENV{WORKFLOW_E2E_FAULT} // '', 2;
    return unless defined $boundary && $event eq $boundary && !$fired++;
    if ($action eq 'fail') { die "injected $boundary\n"; }
    if ($action eq 'kill') { kill 'KILL', $$; }
    if ($action eq 'dirty') { open my $f,'>',"$ENV{WORKFLOW_E2E_ROOT}/user-file" or die $!; print {$f} 'protected'; close $f; }
    if ($action eq 'stale') {
        my $file = $s->state_path($s->{state}{run_id});
        open my $in,'<',$file or die $!; local $/; my $v=decode_json(<$in>); close $in;
        $v->{generation}++;
        open my $out,'>',$file or die $!; print {$out} encode_json($v); close $out;
    }
    if ($action eq 'pause') {
        open my $ready,'>',"$ENV{WORKFLOW_E2E_ROOT}/.git/e2e-ready" or die $!; close $ready;
        while (!-e "$ENV{WORKFLOW_E2E_ROOT}/.git/e2e-release") { select undef,undef,undef,0.01; }
    }
};
exit mch::WorkflowRun->new(root=>$ENV{WORKFLOW_E2E_ROOT}, hook=>$hook)->cli(@ARGV);
