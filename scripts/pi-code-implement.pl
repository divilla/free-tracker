#!/usr/bin/env perl
use strict;
use warnings;

use Cwd qw(abs_path getcwd);
use Encode qw(encode_utf8);
use Errno qw(EINTR);
use File::Basename qw(dirname);
use File::Spec;
use File::Temp qw(tempdir);
use FindBin;
use IO::Handle;
use IO::Select;
use JSON::PP qw(decode_json);
use POSIX qw(WIFEXITED WIFSIGNALED WEXITSTATUS WTERMSIG setpgid);
use lib "$FindBin::Bin/lib";
use mch::Progress;
use mch::GitAuth qw(require_git_auth);

STDOUT->autoflush(1);
STDERR->autoflush(1);

my $active_agent_pid;
my $temporary_dir;
my $active_output_log;
my $active_error_log;
my $result_file;
my $requested_exit_code = 0;

sub fail {
	my ($message) = @_;
	print STDERR "pi-code-implement: $message\n";
	exit 1;
}

sub read_file {
	my ($path) = @_;
	open my $handle, '<:raw', $path or fail("cannot read $path: $!");
	local $/;
	my $contents = <$handle>;
	close $handle or fail("cannot close $path: $!");
	return defined $contents ? $contents : '';
}

sub write_file {
	my ($path, $contents) = @_;
	open my $handle, '>:raw', $path or fail("cannot create $path: $!");
	print {$handle} $contents or fail("cannot write $path: $!");
	close $handle or fail("cannot close $path: $!");
	return;
}

sub pi_session_id_from_output {
	my ($output) = @_;
	for my $line (split /\n/, $output) {
		my $event = eval { decode_json($line) };
		next if ref($event) ne 'HASH' || ($event->{type} // '') ne 'session';
		my $id = $event->{id};
		return $id if defined $id && !ref($id) && $id =~ /\A[A-Za-z0-9][A-Za-z0-9._-]*\z/;
	}
	return;
}

sub report_pi_session_id {
	my ($output) = @_;
	my $id = pi_session_id_from_output($output);
	print 'Pi session ID: ', $id // 'unavailable (no valid session header)', "\n";
	return $id;
}

sub assistant_text_from_message {
	my ($message) = @_;
	return if ref($message) ne 'HASH' || ($message->{role} // '') ne 'assistant';
	my $content = $message->{content};
	return $content if defined $content && !ref($content);
	return if ref($content) ne 'ARRAY';
	my $text = '';
	for my $block (@{$content}) {
		$text .= $block->{text}
			if ref($block) eq 'HASH' && ($block->{type} // '') eq 'text'
			&& defined $block->{text} && !ref($block->{text});
	}
	return $text;
}

# Returns the final assistant response together with its stop reason and, when
# the provider reported one, the assistant message's structured errorMessage.
# JSON mode can exit zero after an assistant message that stopped with "error",
# "aborted", "length" or another non-success reason; only "stop" is a
# completed response.
sub final_response_from_pi_output {
	my ($output) = @_;
	my ($response, $stop_reason, $error_message);
	for my $line (split /\n/, $output) {
		my $event = eval { decode_json($line) };
		next if ref($event) ne 'HASH' || ($event->{type} // '') ne 'message_end';
		next if ref($event->{message}) ne 'HASH' || ($event->{message}{role} // '') ne 'assistant';
		my $reason = $event->{message}{stopReason};
		$stop_reason = defined $reason && !ref($reason) ? $reason : '(missing)';
		my $error = $event->{message}{errorMessage};
		$error_message = defined $error && !ref($error) ? $error : undef;
		$response = assistant_text_from_message($event->{message});
	}
	return ($response, $stop_reason, $error_message);
}

sub shell_quote {
	my ($argument) = @_;
	return $argument if $argument =~ m{\A[a-zA-Z0-9_\@%+=:,./-]+\z};
	$argument =~ s/'/'\\''/g;
	return "'$argument'";
}

sub shell_join {
	return join ' ', map { shell_quote($_) } @_;
}

sub command_exit_code {
	my ($status) = @_;
	return WEXITSTATUS($status) if WIFEXITED($status);
	return 128 + WTERMSIG($status) if WIFSIGNALED($status);
	return 1;
}

sub capture_command {
	my ($quiet_stderr, @command) = @_;
	pipe my $reader, my $writer or fail("cannot create command pipe: $!");
	my $pid = fork();
	defined $pid or fail("cannot fork @command: $!");
	if ($pid == 0) {
		close $reader;
		open STDOUT, '>&', $writer or exit 127;
		if ($quiet_stderr) {
			open STDERR, '>', File::Spec->devnull() or exit 127;
		}
		close $writer;
		exec { $command[0] } @command;
		exit 127;
	}
	close $writer;
	local $/;
	my $output = <$reader>;
	close $reader;
	waitpid $pid, 0;
	return (defined $output ? $output : '', command_exit_code($?));
}

sub run_command {
	my (@command) = @_;
	system { $command[0] } @command;
	return command_exit_code($?);
}

sub run_checked {
	my (@command) = @_;
	my $status = run_command(@command);
	exit $status if $status != 0;
}

sub command_exists {
	my ($command) = @_;
	for my $directory (File::Spec->path()) {
		my $candidate = File::Spec->catfile($directory, $command);
		return 1 if -f $candidate && -x $candidate;
	}
	return 0;
}

sub print_rendered_command {
	my ($command) = @_;
	my $separator_width = 1;
	for my $line (split /\n/, $command, -1) {
		$separator_width = length($line) if length($line) > $separator_width;
	}
	my $separator = '-' x $separator_width;
	print "$separator\n$command\n$separator\n";
}

sub print_command {
	print_rendered_command(shell_join(@_));
}

sub print_file_block {
	my ($path) = @_;
	my $contents = read_file($path);
	print "\n$contents";
	print "\n" if $contents !~ /\n\z/;
	print "\n";
}

sub print_initial_context {
	my ($context, $terminal, $output) = @_;
	$terminal //= -t STDOUT;
	$output //= \*STDOUT;
	my ($label_color, $repository_color, $specification_color, $branch_color, $reset) = ('') x 5;
	if ($terminal && !exists $ENV{NO_COLOR}) {
		$label_color = "\033[37m";
		$repository_color = "\033[34m";
		$specification_color = "\033[35m";
		$branch_color = "\033[32m";
		$reset = "\033[0m";
	}

	print {$output} "\n";
	print {$output} $label_color, 'Repository:', $reset, ' ', $repository_color, $context->{repo_root}, $reset, "\n";
	print {$output} $label_color, 'Specification:', $reset, ' ', $specification_color, $context->{specification}, $reset, "\n";
	print {$output} $label_color, 'Branch:', $reset, ' ', $branch_color, $context->{branch}, $reset, "\n";
}

sub stop {
	my ($exit_code) = @_;
	$requested_exit_code = $exit_code;
	$SIG{INT} = 'DEFAULT';
	$SIG{TERM} = 'DEFAULT';
	if (defined $active_agent_pid) {
		kill 'TERM', -$active_agent_pid;
		return;
	}
	print STDERR "pi-code-implement: interrupted\n";
	exit $requested_exit_code;
}

sub start_command {
	my ($error_log, @command) = @_;
	pipe my $reader, my $writer or fail("cannot create Pi output pipe: $!");
	my $pid = fork();
	defined $pid or fail("cannot fork Pi command: $!");
	if ($pid == 0) {
		setpgid(0, 0) or exit 127;
		close $reader;
		open STDOUT, '>&', $writer or exit 127;
		open STDERR, '>', $error_log or exit 127;
		close $writer;
		exec { $command[0] } @command;
		exit 127;
	}
	close $writer;
	setpgid($pid, $pid);
	return ($pid, $reader);
}

sub monitor_command {
	my ($progress, $output_log, $error_log, @command) = @_;
	my ($pid, $reader) = start_command($error_log, @command);
	$active_agent_pid = $pid;
	my $selector = IO::Select->new($reader);
	my $next_render_at = $progress->started_at();
	$progress->render($next_render_at);

	open my $log, '>:raw', $output_log or fail("cannot create $output_log: $!");
	while ($selector->count) {
		my $now = $progress->now();
		if ($now >= $next_render_at) {
			$progress->render($now);
			$next_render_at += $progress->render_interval() while $next_render_at <= $now;
		}
		my $timeout = $next_render_at - $progress->now();
		$timeout = 0 if $timeout < 0;
		my @ready = $selector->can_read($timeout);
		next if !@ready;

		my $buffer = '';
		my $bytes = sysread $reader, $buffer, 64 * 1024;
		if (!defined $bytes) {
			next if $! == EINTR;
			close $log;
			fail("cannot read Pi output: $!");
		}
		if ($bytes == 0) {
			$selector->remove($reader);
			close $reader;
			next;
		}
		print {$log} $buffer or fail("cannot write $output_log: $!");
		$progress->record_output();
	}
	close $log or fail("cannot close $output_log: $!");

	waitpid $pid, 0;
	my $exit_code = command_exit_code($?);
	$active_agent_pid = undef;
	return $exit_code;
}

sub run_pi {
	my (@command) = @_;
	print_command(@command);
	my $progress = mch::Progress->new(terminal => -t STDOUT, output => \*STDOUT);
	$active_output_log = File::Spec->catfile($temporary_dir, 'pi-output.jsonl');
	$active_error_log = File::Spec->catfile($temporary_dir, 'pi-output.stderr.log');
	my $exit_code = monitor_command($progress, $active_output_log, $active_error_log, @command);
	$progress->finish($exit_code == 0 && $requested_exit_code == 0);
	my $output = read_file($active_output_log);
	report_pi_session_id($output);
	if ($requested_exit_code != 0) {
		unlink $active_output_log;
		unlink $active_error_log;
		$active_output_log = undef;
		$active_error_log = undef;
		print STDERR "pi-code-implement: interrupted\n";
		exit $requested_exit_code;
	}

	if ($exit_code != 0) {
		print STDERR "pi-code-implement: Pi command failed with exit code $exit_code\n";
		if ($output ne '') {
			$output =~ s/^/  /mg;
			print STDERR "pi-code-implement: Pi command output:\n$output";
		}
		if (-s $active_error_log) {
			my $errors = read_file($active_error_log);
			$errors =~ s/^/  /mg;
			print STDERR "pi-code-implement: Pi command diagnostics:\n$errors";
		}
	}
	else {
		my ($response, $stop_reason, $error_message) = final_response_from_pi_output($output);
		fail('Pi did not emit a final assistant response') if !defined $response;
		if ($stop_reason ne 'stop') {
			print STDERR "pi-code-implement: Pi final assistant response ended with stopReason '$stop_reason', not 'stop'\n";
			if (defined $error_message) {
				$error_message =~ s/^/  /mg;
				print STDERR "pi-code-implement: Pi assistant error message:\n$error_message\n";
			}
			if (-s $active_error_log) {
				my $errors = read_file($active_error_log);
				$errors =~ s/^/  /mg;
				print STDERR "pi-code-implement: Pi command diagnostics:\n$errors";
			}
			exit 1;
		}
		write_file($result_file, encode_utf8($response));
	}
	unlink $active_output_log;
	unlink $active_error_log;
	$active_output_log = undef;
	$active_error_log = undef;
	return $exit_code;
}

sub path_is_inside {
	my ($path, $parent) = @_;
	return 1 if $path eq $parent;
	return index($path, $parent . '/') == 0;
}

sub select_temp_root {
	my ($repo_root_physical) = @_;
	for my $candidate ($ENV{TMPDIR}, $ENV{TMP}, $ENV{TEMP}, '/tmp') {
		next if !defined $candidate || $candidate eq '' || !-d $candidate || !-w $candidate;
		my $resolved = abs_path($candidate);
		next if !defined $resolved || path_is_inside($resolved, $repo_root_physical);
		return $resolved;
	}
	return;
}

sub ensure_clean_worktree {
	my ($changes, $status) = capture_command(0, 'git', 'status', '--porcelain=v1', '--untracked-files=all', '--ignore-submodules=none');
	$status == 0 or exit $status;
	if ($changes ne '') {
		print STDERR "error: Uncommitted work detected. Commit or stash your changes, then retry.\n";
		exit 1;
	}
}

sub cleanup {
	unlink $active_output_log if defined $active_output_log && -e $active_output_log;
	unlink $active_error_log if defined $active_error_log && -e $active_error_log;
	unlink $result_file if defined $result_file && -e $result_file;
	rmdir $temporary_dir if defined $temporary_dir && -d $temporary_dir;
}

sub main {
	my (@arguments) = @_;
	@arguments == 0 or fail('usage: pi-code-implement.pl');
	command_exists('git') or fail('git is not installed or is not on PATH');

	my $script_dir = abs_path(dirname($0));
	my ($repo_root, $repo_status) = capture_command(1, 'git', '-C', $script_dir, 'rev-parse', '--show-toplevel');
	$repo_status == 0 or fail('scripts directory is not inside a git repository');
	$repo_root =~ s/\s+\z//;
	chdir $repo_root or fail("cannot enter repository $repo_root: $!");
	my $repo_root_physical = abs_path(getcwd());
	ensure_clean_worktree();
	command_exists('pi') or fail('pi is not installed or is not on PATH');

	my ($branch, $branch_status) = capture_command(1, 'git', 'symbolic-ref', '--quiet', '--short', 'HEAD');
	$branch =~ s/\s+\z//;
	my ($change_name) = $branch =~ m{^change/([0-9][0-9][0-9]+-[a-z0-9-_]+)$};
	$branch_status == 0 && defined $change_name
		or fail('current branch must match ^change/([0-9][0-9][0-9]+-[a-z0-9-_]+)$');
	my $specification = "agent/changes/$change_name.md";
	-f $specification && -r $specification
		or fail("change file not found or unreadable: $specification");
	require_git_auth();

	my ($before_implementation, $head_status) = capture_command(0, 'git', 'rev-parse', 'HEAD');
	$head_status == 0 or exit $head_status;
	$before_implementation =~ s/\s+\z//;

	my $temp_root = select_temp_root($repo_root_physical);
	defined $temp_root or fail('cannot find a writable temporary directory outside the repository');
	$temporary_dir = tempdir('apih-implement.XXXXXXXXXX', DIR => $temp_root, CLEANUP => 0);
	defined $temporary_dir or fail("cannot create private implementation directory under $temp_root");
	$result_file = File::Spec->catfile($temporary_dir, 'implementation-result.md');

	print_initial_context({
		branch        => $branch,
		repo_root     => $repo_root,
		specification => $specification,
	});
	print "\n=== Implementation ===\n";
	my $prompt = '$mch-code-implement';
	my $status = run_pi(
		'pi', '-p', '--mode', 'json', '--thinking', 'high', '--approve', $prompt,
	);
	exit $status if $status != 0;
	-f $result_file or fail('implementation did not write a final response');
	print_file_block($result_file);

	my ($after_implementation, $after_status) = capture_command(0, 'git', 'rev-parse', 'HEAD');
	$after_status == 0 or exit $after_status;
	$after_implementation =~ s/\s+\z//;
	$after_implementation eq $before_implementation
		or fail('Pi created a commit; expected this script to commit the implementation');

	my ($current_branch, $current_branch_status) = capture_command(0, 'git', 'branch', '--show-current');
	$current_branch_status == 0 or exit $current_branch_status;
	$current_branch =~ s/\s+\z//;
	$current_branch eq $branch or fail('Pi changed branches; refusing to commit');

	my ($changed_files, $changed_status) = capture_command(0, 'git', 'status', '--short', '--untracked-files=all', '--', '.');
	$changed_status == 0 or exit $changed_status;
	print "Changed files:\n";
	if ($changed_files eq '') {
		print "  (none)\n";
		fail('Pi made no repository changes; see the implementation result above');
	}
	print $changed_files;

	my $commit_message = "Implement code $change_name";
	print "Commit: $commit_message\n";
	run_checked('git', 'add', '-A');
	run_checked('git', 'commit', '-m', $commit_message);
	run_checked('git', 'push', '-u', 'origin', $branch);
	ensure_clean_worktree();
	return 0;
}

$SIG{INT} = sub { stop(130) };
$SIG{TERM} = sub { stop(143) };

END {
	cleanup();
}

exit main(@ARGV) unless caller;

1;
