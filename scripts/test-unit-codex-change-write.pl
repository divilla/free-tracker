#!/usr/bin/env perl
use strict;
use warnings;

use FindBin;
use Test::More ();

my $script = "$FindBin::Bin/codex-change-write.pl";
do $script or die "cannot load $script: " . ($@ || $!);

my $id = '0199a213-81c0-7800-8aa1-bbab2a035a53';
Test::More::is(
	session_id_from_output("diagnostic\nnull\n[]\ninvalid JSON\n"
		. '{"type":"thread.started","thread_id":"' . $id . '"}' . "\n"),
	$id,
	'session extraction tolerates diagnostic lines and non-object JSON',
);
for my $event (
	'',
	'{"type":"item.completed","thread_id":"wrong"}',
	'{"type":"thread.started"}',
	'{"type":"thread.started","thread_id":null}',
	'{"type":"thread.started","thread_id":[]}',
	'{"type":"thread.started","thread_id":""}',
	'{"type":"thread.started","thread_id":"--last"}',
) {
	Test::More::ok(!defined session_id_from_output($event), "reject missing/invalid session: $event");
}

Test::More::done_testing();
