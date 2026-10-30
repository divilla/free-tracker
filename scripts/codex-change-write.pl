#!/usr/bin/env perl
use strict;
use warnings;

use Cwd qw(abs_path getcwd);
use Errno qw(EINTR);
use File::Basename qw(dirname);
use File::Spec;
use File::Temp qw(tempdir);
use FindBin;
use IO::Handle;
use IO::Select;
use POSIX qw(WIFEXITED WIFSIGNALED WEXITSTATUS WTERMSIG setpgid);
use lib "$FindBin::Bin/lib";
use mch::Progress;
use mch::CodexSession qw(session_id_from_output report_session_id);
use mch::GitAuth qw(require_git_auth);

STDOUT->autoflush(1);
STDERR->autoflush(1);

my $active_codex_pid;
my $temporary_dir;
my $active_output_log;
my $result_file;
my $codex_session_id;
my $requested_exit_code = 0;

sub fail {
	my ($message) = @_;
	print STDERR "codex-change-write: $message\n";
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
	if (defined $active_codex_pid) {
		kill 'TERM', -$active_codex_pid;
		return;
	}
	print STDERR "codex-change-write: interrupted\n";
	exit $requested_exit_code;
}

sub start_command {
	my (@command) = @_;
	pipe my $reader, my $writer or fail("cannot create Codex output pipe: $!");
	my $pid = fork();
	defined $pid or fail("cannot fork Codex command: $!");
	if ($pid == 0) {
		setpgid(0, 0) or exit 127;
		close $reader;
		open STDOUT, '>&', $writer or exit 127;
		open STDERR, '>&', $writer or exit 127;
		close $writer;
		exec { $command[0] } @command;
		exit 127;
	}
	close $writer;
	setpgid($pid, $pid);
	return ($pid, $reader);
}

sub monitor_command {
	my ($progress, $output_log, @command) = @_;
	my ($pid, $reader) = start_command(@command);
	$active_codex_pid = $pid;
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
			fail("cannot read Codex output: $!");
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
	$active_codex_pid = undef;
	return $exit_code;
}

sub run_codex {
	my (@command) = @_;
	print_command(@command);
	my $progress = mch::Progress->new(terminal => -t STDOUT, output => \*STDOUT);
	$active_output_log = File::Spec->catfile($temporary_dir, 'codex-output.log');
	my $exit_code = monitor_command($progress, $active_output_log, @command);
	$progress->finish($exit_code == 0 && $requested_exit_code == 0);
	$codex_session_id = report_session_id(read_file($active_output_log));
	if ($requested_exit_code != 0) {
		unlink $active_output_log;
		$active_output_log = undef;
		print STDERR "codex-change-write: interrupted\n";
		exit $requested_exit_code;
	}

	if ($exit_code != 0) {
		print STDERR "codex-change-write: Codex command failed with exit code $exit_code\n";
		if (-s $active_output_log) {
			my $output = read_file($active_output_log);
			$output =~ s/^/  /mg;
			print STDERR "codex-change-write: Codex command output:\n$output";
		}
	}
	unlink $active_output_log;
	$active_output_log = undef;
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
	unlink $result_file if defined $result_file && -e $result_file;
	rmdir $temporary_dir if defined $temporary_dir && -d $temporary_dir;
}

sub main {
	my (@arguments) = @_;
	@arguments == 0 or fail('usage: codex-change-write.pl');
	command_exists('git') or fail('git is not installed or is not on PATH');

	my $script_dir = abs_path(dirname($0));
	my ($repo_root, $repo_status) = capture_command(1, 'git', '-C', $script_dir, 'rev-parse', '--show-toplevel');
	$repo_status == 0 or fail('scripts directory is not inside a git repository');
	$repo_root =~ s/\s+\z//;
	chdir $repo_root or fail("cannot enter repository $repo_root: $!");
	my $repo_root_physical = abs_path(getcwd());
	ensure_clean_worktree();
	command_exists('codex') or fail('codex is not installed or is not on PATH');

	my ($branch, $branch_status) = capture_command(1, 'git', 'symbolic-ref', '--quiet', '--short', 'HEAD');
	$branch =~ s/\s+\z//;
	my ($change_name) = $branch =~ m{^change/([0-9][0-9][0-9]+-[a-z0-9-_]+)$};
	$branch_status == 0 && defined $change_name
		or fail('current branch must match ^change/([0-9][0-9][0-9]+-[a-z0-9-_]+)$');
	my $specification = "agent/changes/$change_name.md";
	require_git_auth();

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
	my $prompt = '$mch-change-write';
	my $status = run_codex(
		'codex', 'exec', '--json', '--model', 'gpt-6.1-sol',
		'-c', 'model_reasoning_effort="high"', '-c', 'service_tier="default"',
		'-o', $result_file, $prompt,
	);
	exit $status if $status != 0;
	my $done = 0;
	if (-f $result_file) {
		my $response = read_file($result_file);
		print_file_block($result_file);
		# A single final line ending is transport formatting, not response text.
		$done = $response =~ /\ADone\.(?:\r?\n)?\z/;
	}
	if (!$done) {
		defined $codex_session_id or fail('cannot resume Codex: no session ID found in Codex output');
		print_command('codex', 'resume', $codex_session_id);
		# Inherit the terminal directly and ignore the interactive exit code.
		run_command('codex', 'resume', $codex_session_id);
	}

	my ($changes, $changes_status) = capture_command(0, 'git', 'status', '--porcelain=v1', '--untracked-files=all', '--ignore-submodules=none');
	exit $changes_status if $changes_status != 0;
	return 0 if $changes eq '';

	my $commit_message = "Write change $change_name";
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
