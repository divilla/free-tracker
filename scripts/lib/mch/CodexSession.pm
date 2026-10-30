package mch::CodexSession;

use strict;
use warnings;
use Exporter qw(import);
use JSON::PP qw(decode_json);

our @EXPORT_OK = qw(session_id_from_output report_session_id);

sub session_id_from_output {
	my ($output) = @_;
	for my $line (split /\n/, $output) {
		my $event = eval { decode_json($line) };
		next if ref($event) ne 'HASH' || ($event->{type} // '') ne 'thread.started';
		my $id = $event->{thread_id};
		return $id if defined $id && !ref($id) && $id =~ /\A[a-zA-Z0-9][a-zA-Z0-9_-]*\z/;
	}
	return;
}

sub report_session_id {
	my ($output) = @_;
	my $id = session_id_from_output($output);
	print 'Codex session ID: ', $id // 'unavailable (no valid thread.started event)', "\n";
	return $id;
}

1;
