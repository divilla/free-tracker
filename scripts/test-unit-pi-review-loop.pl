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
	'{"type":"message_end","message":{"role":"assistant","content":[{"type":"text","text":"first"}],"stopReason":"toolUse"}}',
	'{"type":"message_end","message":{"role":"assistant","content":"last","stopReason":"stop"}}';
my ($final_response, $final_stop_reason) = final_response_from_pi_output($pi_output);
assert_equal($final_response, 'last',
	'LOOP-PI-RESULT: use the final assistant response');
assert_equal($final_stop_reason, 'stop',
	'LOOP-PI-RESULT: report the final assistant stop reason');
my ($joined_response, $joined_stop_reason) = final_response_from_pi_output(
	'{"type":"message_end","message":{"role":"assistant","content":[{"type":"text","text":"one"},{"type":"text","text":" two"}],"stopReason":"stop"}}'
);
assert_equal($joined_response, 'one two', 'LOOP-PI-RESULT: concatenate assistant text blocks');
assert_equal($joined_stop_reason, 'stop', 'LOOP-PI-RESULT: completed responses report stop');
my ($blocks_response, $blocks_stop_reason) = final_response_from_pi_output(
	'{"type":"message_end","message":{"role":"assistant","content":[{"type":"tool_call","text":"ignored"}],"stopReason":"stop"}}'
);
assert_equal($blocks_response, '', 'LOOP-PI-RESULT: non-text assistant blocks contribute no text');
assert_equal($blocks_stop_reason, 'stop', 'LOOP-PI-RESULT: completed responses report stop');
my ($error_response, $error_stop_reason) = final_response_from_pi_output(
	'{"type":"message_end","message":{"role":"assistant","content":[{"type":"text","text":"fixed one file"}],"stopReason":"error"}}'
);
assert_equal($error_response, 'fixed one file',
	'LOOP-PI-RESULT: an error response still yields its text for reporting');
assert_equal($error_stop_reason, 'error',
	'LOOP-PI-RESULT: an error stop reason must be surfaced for rejection');
my ($aborted_response, $aborted_stop_reason) = final_response_from_pi_output(
	join("\n",
		'{"type":"message_end","message":{"role":"assistant","content":"interrupted work","stopReason":"aborted"}}',
		'{"type":"message_end","message":{"role":"assistant","content":"recovered afterwards","stopReason":"stop"}}')
);
assert_equal($aborted_response, 'recovered afterwards',
	'LOOP-PI-RESULT: an earlier aborted turn does not hide a later completion');
assert_equal($aborted_stop_reason, 'stop',
	'LOOP-PI-RESULT: only the final stop reason decides acceptance');
my ($length_response, $length_stop_reason) = final_response_from_pi_output(
	'{"type":"message_end","message":{"role":"assistant","content":"truncated","stopReason":"length"}}'
);
assert_equal($length_response, 'truncated',
	'LOOP-PI-RESULT: a length response still yields its text for reporting');
assert_equal($length_stop_reason, 'length',
	'LOOP-PI-RESULT: a length stop reason must be surfaced for rejection');
my ($unlabelled_response, $unlabelled_stop_reason) = final_response_from_pi_output(
	'{"type":"message_end","message":{"role":"assistant","content":"unlabelled"}}'
);
assert_equal($unlabelled_response, 'unlabelled',
	'LOOP-PI-RESULT: an unlabelled response still yields its text for reporting');
assert_equal($unlabelled_stop_reason, '(missing)',
	'LOOP-PI-RESULT: a missing stop reason must be surfaced for rejection');

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
