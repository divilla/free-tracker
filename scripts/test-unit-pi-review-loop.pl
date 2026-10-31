#!/usr/bin/env perl
use strict;
use warnings;

use Cwd qw(abs_path);
use File::Basename qw(dirname);
use File::Spec;
use File::Temp qw(tempfile);

my $tests = 0;

sub assert_equal {
	my ($got, $want, $message) = @_;
	$tests++;
	return if !defined $got && !defined $want;
	die "$message: got [" . ($got // 'undef') . "], want [" . ($want // 'undef') . "]\n"
		if !defined $got || !defined $want || $got ne $want;
}

my $script = abs_path(File::Spec->catfile(dirname(__FILE__), 'pi-review-loop.pl'));
do $script or die "cannot load $script: " . ($@ || $!);

assert_equal(
	join("\0", parse_review_options()),
	join("\0", 'origin/dev', 'document', '--model', 'gpt-6.1-sol', codex_settings()),
	'LOOP-REVIEW: review remains a default GPT-6.1 Sol Codex review',
);

assert_equal(
	join("\0", parse_review_options('--code')),
	join("\0", 'origin/dev', 'code', '--model', 'gpt-6.1-sol', codex_settings()),
	'LOOP-MODE: code mode changes the Pi fix prompt without changing Codex review',
);

my $session_output = join "\n",
	'not json',
	'{"type":"session","id":"../unsafe"}',
	'{"type":"session","id":"fix-session.01"}',
	'{"type":"session","id":"later-session"}';
assert_equal(pi_session_id_from_output($session_output), 'fix-session.01',
	'LOOP-PI-SESSION: use the first valid Pi session header');
my $missing_session_id = pi_session_id_from_output('{"type":"session"}');
assert_equal($missing_session_id, undef,
	'LOOP-PI-SESSION: reject a missing Pi session ID',
);

my $pi_output = join "\n",
	'{"type":"message_start","message":{"role":"assistant"}}',
	'{"type":"message_end","message":{"role":"user","content":"ignored"}}',
	'{"type":"message_end","message":{"role":"assistant","content":[{"type":"text","text":"first"}]}}',
	'{"type":"message_end","message":{"role":"assistant","content":"last"}}';
assert_equal(final_response_from_pi_output($pi_output), 'last',
	'LOOP-PI-RESULT: use the final assistant response');
assert_equal(final_response_from_pi_output(
	'{"type":"message_end","message":{"role":"assistant","content":[{"type":"text","text":"one"},{"type":"text","text":" two"}]}}'
), 'one two', 'LOOP-PI-RESULT: concatenate assistant text blocks');
assert_equal(final_response_from_pi_output(
	'{"type":"message_end","message":{"role":"assistant","content":[{"type":"tool_call","text":"ignored"}]}}'
), '', 'LOOP-PI-RESULT: non-text assistant blocks contribute no text');

my $rendered = '';
open my $progress_output, '>:raw', \$rendered or die "cannot create progress capture: $!";
my ($log, $output_log) = tempfile();
close $log;
my $progress = mch::Progress->new(terminal => 1, output => $progress_output);
my $status = monitor_command(
	$progress,
	undef,
	$output_log,
	undef,
	$^X,
	'-e',
	'select undef, undef, undef, 0.85',
);
close $progress_output;
unlink $output_log;

assert_equal($status, 0, 'LOOP-PROGRESS: a silent Codex child exits successfully');
my %rendered_frames;
for my $render (split /\r/, $rendered) {
	for my $frame ("\xC2\xB7", "\xE2\x80\xA2", "\xE2\x97\x8F") {
		$rendered_frames{$frame} = 1 if $render =~ /\Q$frame\E\z/;
	}
}
assert_equal(scalar keys %rendered_frames, 3,
	'LOOP-PROGRESS: silent children render distinct animation frames at timed intervals');

print "pi-review-loop unit tests passed ($tests assertions)\n";
