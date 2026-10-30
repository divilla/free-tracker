#!/usr/bin/env perl
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/lib";
use mch::CodexSession qw(session_id_from_output report_session_id);
use Test::More;

my $id = '0199a213-81c0-7800-8aa1-bbab2a035a53';
my $event = qq({"type":"thread.started","thread_id":"$id"});
my @invalid = (
	'', 'diagnostic', 'null', '[]', '{bad json}',
	'{"type":"item.completed","thread_id":"wrong"}',
	'{"type":"thread.started"}',
	'{"type":"thread.started","thread_id":null}',
	'{"type":"thread.started","thread_id":[]}',
	'{"type":"thread.started","thread_id":true}',
	'{"type":"thread.started","thread_id":""}',
	'{"type":"thread.started","thread_id":"--last"}',
	'{"type":"thread.started","thread_id":"bad\\nID"}',
	'{"type":"thread.started","thread_id":"$(command)"}',
);
for my $invalid (@invalid) {
	ok(!defined session_id_from_output($invalid), "reject invalid/missing ID: $invalid");
}
is(session_id_from_output(join("\n", @invalid, $event)), $id, 'diagnostics do not hide the session event');
is(session_id_from_output("$event\r\n"), $id, 'accept CRLF events');
is(session_id_from_output($event), $id, 'accept final event without newline');
is(session_id_from_output("$event\n$event\n{\"type\":\"thread.started\",\"thread_id\":\"other\"}"),
	$id, 'first valid session is authoritative');

for my $case ([$event, $id], ['', undef]) {
	my $printed = '';
	open my $capture, '>', \$printed or die $!;
	my $captured_id;
	{
		local *STDOUT = $capture;
		$captured_id = report_session_id($case->[0]);
	}
	close $capture;
	is($captured_id, $case->[1], 'report returns captured ID for caller reuse');
	is($printed, 'Codex session ID: ' . ($case->[1] // 'unavailable (no valid thread.started event)') . "\n",
		'report prints exactly one labeled line, including missing-session case');
}
done_testing();
