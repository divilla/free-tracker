package mch::WorkflowRun;
use strict;
use warnings;
use Cwd qw(abs_path);
use File::Basename qw(dirname);
use File::Glob qw(bsd_glob);
use File::Spec;
use File::Temp qw(tempfile);
use Fcntl qw(:DEFAULT :flock F_GETFD F_SETFD FD_CLOEXEC);
use IO::Handle;
use JSON::PP;
use Digest::SHA qw(sha256_hex);
use POSIX qw(strftime setpgid sigprocmask SIG_BLOCK SIG_SETMASK SIGINT SIGTERM);
use Errno qw(EINTR);
use Sys::Hostname qw(hostname);

# Injection is constructor-only: production commands cannot disable gates via
# environment variables. Hooks surround actual durability/Git boundaries.
sub new {
    my ($class, %args) = @_;
    return bless { %args, root => abs_path($args{root}) }, $class;
}
sub json { JSON::PP->new->canonical->utf8->pretty }
sub now { my ($s) = @_; return $s->{clock}->() if $s->{clock}; return strftime('%Y-%m-%dT%H:%M:%SZ', gmtime); }
sub hook { my ($s, $name) = @_; $s->{hook}->($name, $s) if $s->{hook}; }
sub fail { die "$_[1]; owner: workflow operator; next action: reconcile the named prerequisite and explicitly resume/retry\n" }
sub slug_ok { defined $_[0] && $_[0] =~ /\A[0-9][0-9][0-9]+-[a-z0-9-_]+\z/ }
sub run_ok { defined $_[0] && $_[0] =~ /\Ar-[a-f0-9]{32}\z/ }
sub relative_ok { defined $_[0] && $_[0] =~ /\A[a-zA-Z0-9_.-]+(?:\/[a-zA-Z0-9_.-]+)*\z/ && $_[0] !~ m{(?:\A|/)\.\.?(?:/|\z)} }
sub oid_ok { defined $_[0] && $_[0] =~ /\A(?:[a-f0-9]{40}|[a-f0-9]{64})\z/ }
sub bytes {
    my ($s, $path) = @_;
    $s->safe_path($path);
    sysopen my $fh, $path, O_RDONLY | O_NOFOLLOW or $s->fail("cannot read $path");
    binmode $fh;
    local $/; my $bytes = <$fh> // '';
    close $fh or $s->fail("cannot close $path");
    return $bytes;
}
sub safe_path {
    my ($s, $path) = @_;
    my $absolute = File::Spec->rel2abs($path);
    $s->fail('unsafe path traversal') if $absolute =~ m{(?:\A|/)\.\.?(?:/|\z)};
    my $part = '';
    for (split m{/}, $absolute) {
        next if !length;
        $part .= "/$_";
        $s->fail("symlink path is not owned: $part") if -l $part;
    }
    return $absolute;
}

# Reject duplicate keys at every nesting level before JSON::PP can discard them.
# JSON::PP remains responsible for grammar, Unicode, values and trailing bytes.
sub decode {
    my ($s, $bytes) = @_;
    my $v = eval { json()->decode($bytes) };
    $s->fail('malformed JSON object') if $@ || ref $v ne 'HASH';
    my @stack;
    while ($bytes =~ /("(?:[^"\\]|\\.)*"|[{}\[\]:,])/gs) {
        my $token = $1;
        if ($token eq '{') { push @stack, { keys => {}, key => 1 }; }
        elsif ($token eq '[') { push @stack, { array => 1 }; }
        elsif ($token eq '}' || $token eq ']') { pop @stack; }
        elsif (@stack && !$stack[-1]{array}) {
            if ($token eq ',') { $stack[-1]{key} = 1; }
            elsif ($token =~ /^"/ && $stack[-1]{key}) {
                my $key = json()->decode($token);
                $s->fail('duplicate JSON field') if $stack[-1]{keys}{$key}++;
                $stack[-1]{key} = 0;
            }
        }
    }
    return $v;
}

# The supervisor retains inherited lock descriptors until its command exits,
# including if the parent is SIGKILLed. It never execs away lock ownership.
sub command {
    my ($s, @args) = @_;
    return $s->{command}->(@args) if $s->{command};
    pipe my $read, my $write or $s->fail('cannot create command pipe');
    my $mask = POSIX::SigSet->new(SIGINT, SIGTERM);
    my $oldmask = POSIX::SigSet->new;
    sigprocmask(SIG_BLOCK, $mask, $oldmask) or $s->fail('cannot protect child registration');
    my $pid = fork(); defined $pid or $s->fail('cannot fork command');
    if (!$pid) {
        close $read;
        setpgid(0, 0) == 0 or POSIX::_exit(125);
        POSIX::dup2(fileno($write), 1) >= 0 or POSIX::_exit(125);
        open my $null, '>', File::Spec->devnull or POSIX::_exit(125);
        POSIX::dup2(fileno($null), 2) >= 0 or POSIX::_exit(125);
        close $write;
        # Supervisor must not abandon a surviving mutator on TERM/INT. The
        # worker gets the group signal too; wait until it really exits.
        $SIG{INT} = $SIG{TERM} = sub {};
        $SIG{PIPE} = 'IGNORE';
        pipe my $worker_read, my $worker_write or POSIX::_exit(125);
        my $worker = fork(); defined $worker or POSIX::_exit(125);
        if (!$worker) {
            $SIG{INT} = $SIG{TERM} = 'DEFAULT';
            $SIG{PIPE} = 'DEFAULT';
            close $worker_read;
            POSIX::dup2(fileno($worker_write), 1) >= 0 or POSIX::_exit(125);
            close $worker_write;
            sigprocmask(SIG_SETMASK, $oldmask);
            exec { $args[0] } @args or POSIX::_exit(127);
        }
        close $worker_write;
        sigprocmask(SIG_SETMASK, $oldmask);
        # Drain worker output even when the launcher has died. Otherwise its
        # closed pipe could SIGPIPE Git into a partially created branch.
        my $forward = 1;
        while (1) {
            my $count = sysread($worker_read, my $buffer, 8192);
            next if !defined $count && $! == EINTR;
            last unless $count;
            my $offset = 0;
            while ($forward && $offset < $count) {
                my $sent = POSIX::write(1, substr($buffer, $offset), $count - $offset);
                next if !defined $sent && $! == EINTR;
                if (!defined $sent || $sent <= 0) { $forward = 0; last; }
                $offset += $sent;
            }
        }
        close $worker_read;
        while (waitpid($worker, 0) < 0) { POSIX::_exit(125) unless $! == EINTR; }
        POSIX::_exit(($? & 127) ? 128 + ($? & 127) : $? >> 8);
    }
    close $write; $s->{child} = $pid;
    setpgid($pid, $pid); # Child may already have set it; either outcome is safe.
    sigprocmask(SIG_SETMASK, $oldmask);
    local $/; my $output = <$read> // '';
    close $read; waitpid($pid, 0); my $rc = ($? & 127) ? 128 + ($? & 127) : $? >> 8;
    delete $s->{child};
    return ($rc, $output);
}
sub git {
    my ($s, @args) = @_;
    my ($rc, $out) = $s->command('git', '-C', $s->{root}, @args);
    $s->fail('Git operation failed: ' . $args[0]) if $rc;
    $out =~ s/\n\z//; return $out;
}
sub commit {
    my ($s, $ref) = @_;
    my $oid = $s->git('rev-parse', '--verify', '--end-of-options', "$ref\^{commit}");
    $s->fail('unresolvable commit') unless oid_ok($oid);
    return $oid;
}
sub repository {
    my ($s) = @_;
    $s->fail('repository path unavailable') unless $s->{root};
    $s->{root} = abs_path($s->git('rev-parse', '--show-toplevel'));
    $s->{common} = abs_path($s->git('rev-parse', '--absolute-git-dir'));
    $s->fail('missing repository identity') unless $s->{common};
    $s->{repo_id} = sha256_hex($s->{common});
    $s->git('symbolic-ref', '--quiet', '--short', 'HEAD');
}
sub inventory {
    my ($s, $slug, $root) = @_;
    $root //= $s->{root};
    $s->fail('invalid complete numbered slug') unless slug_ok($slug);
    my $plan = $s->bytes("$root/agent/PLAN.md");
    my @rows;
    for (split /\n/, $plan) {
        next unless /^\|/;
        my @c = split /\|/; shift @c;
        @c = map { s/^\s+|\s+$//gr } @c;
        next unless @c >= 5;
        $c[1] =~ s/`//g;
        push @rows, \@c if $c[1] eq $slug;
    }
    $s->fail('PLAN inventory requires exactly one exact slug row') unless @rows == 1;
    my ($number) = $slug =~ /^(\d+)-/;
    my $id = "S$number";
    $s->fail('PLAN ID/path conflict') unless $rows[0][0] eq "$id / `changes/$slug.md`";
    my $change = $s->bytes("$root/agent/changes/$slug.md");
    $s->fail('change identity conflict') unless $change =~ /\A#\s+\Q$id\E\b/ && $change =~ /\Qchange\/$slug\E/;
    for my $path ('AGENTS.md', map { "agent/$_.md" } qw(PRD ARCHITECTURE IMPLEMENT)) {
        my $text = $s->bytes("$root/$path");
        $s->fail("empty governing document $path") unless $text =~ /\S/;
    }
    $s->fail('unresolved authoring placeholder') if $change =~ /(?:\bTBD\b|\bTODO\b|\[INSERT\b|<slug>\s*\/\s*change\/<slug>)/;
    my @deps = $rows[0][2] =~ /\b(S\d{3,})\b/g;
    return { id => $id, slug => $slug, path => "agent/changes/$slug.md", deps => \@deps };
}
sub dependency_slugs {
    my ($s, $entry, $seen) = @_; $seen //= {};
    my $plan = $s->bytes("$s->{root}/agent/PLAN.md");
    my @result;
    for my $id (@{$entry->{deps}}) {
        $s->fail('dependency cycle') if $seen->{$id} && $seen->{$id} eq 'active';
        next if $seen->{$id};
        my @slugs = $plan =~ /^\| \Q$id\E \/ `changes\/([^`]+)\.md` \|/mg;
        $s->fail("missing/duplicate dependency $id") unless @slugs == 1;
        $seen->{$id} = 'active';
        my $dep = $s->inventory($slugs[0]);
        push @result, $s->dependency_slugs($dep, $seen), $slugs[0];
        $seen->{$id} = 'done';
    }
    return @result;
}
sub tools {
    my ($s) = @_;
    for my $tool (qw(git perl bash python3)) {
        my ($rc) = $s->command($tool, $tool eq 'perl' ? '-v' : '--version');
        $s->fail("missing required tool $tool") if $rc;
    }
}
sub prerequisites {
    my ($s, $entry, $baseline) = @_;
    $s->tools;
    my @deps = $s->dependency_slugs($entry);
    return [] unless @deps;
    my $path = "agent/progress/prerequisites/$entry->{slug}.json";
    my $manifest = $s->decode($s->bytes("$s->{root}/$path"));
    $s->fail('invalid prerequisite manifest') unless ($manifest->{schema} // 0) == 1
        && ($manifest->{consumer} // '') eq $entry->{slug} && ref $manifest->{dependencies} eq 'HASH';
    my @verified;
    for my $slug (@deps) {
        my @commits = map { (split /\t/, $_, 2)[0] } grep { /\t\QImplement change $slug\E\z/ }
            split /\n/, $s->git('log', '--format=%H%x09%s', $baseline, '--');
        $s->fail("dependency integration absent/ambiguous: $slug") unless @commits == 1;
        my $e = $manifest->{dependencies}{$slug};
        $s->fail("missing scoped executable prerequisite evidence: $slug") unless ref $e eq 'HASH'
            && ($e->{integration} // '') eq $commits[0] && ref $e->{sources} eq 'HASH' && keys %{$e->{sources}}
            && ref $e->{checks} eq 'ARRAY' && @{$e->{checks}};
        for my $file (keys %{$e->{sources}}) {
            $s->fail('unsafe prerequisite source path') unless relative_ok($file);
            # Source digest is of exact Git blob bytes, including final newline.
            my ($rc, $blob) = $s->command('git', '-C', $s->{root}, 'show', "$baseline:$file");
            $s->fail("dependency source identity mismatch: $file") if $rc || sha256_hex($blob) ne $e->{sources}{$file};
        }
        for my $check (@{$e->{checks}}) {
            $s->fail("missing evidence scope/revision/result: $slug") unless ref $check eq 'HASH'
                && ($check->{scope} // '') =~ /\S/ && oid_ok($check->{revision})
                && defined $check->{exit} && $check->{exit} eq '0' && ($check->{result} // '') eq 'passed'
                && relative_ok($check->{artifact}) && ($check->{sha256} // '') =~ /^[a-f0-9]{64}$/;
            $s->commit($check->{revision});
            for my $file (keys %{$e->{sources}}) {
                my ($rc, $blob) = $s->command('git', '-C', $s->{root}, 'show', "$check->{revision}:$file");
                $s->fail("tested source differs: $slug/$file") if $rc || sha256_hex($blob) ne $e->{sources}{$file};
            }
            my $artifact = $s->bytes("$s->{root}/$check->{artifact}");
            $s->fail("evidence content mismatch: $slug") unless sha256_hex($artifact) eq $check->{sha256};
        }
        push @verified, { slug => $slug, integration => $commits[0], evidence => $e };
    }
    return \@verified;
}
sub directories {
    my ($s, $path) = @_;
    $s->safe_path($path);
    if (!-d $path) {
        $s->directories(dirname($path));
        mkdir $path, 0700 or $s->fail('cannot create owned directory');
        $s->sync_directory(dirname($path));
    }
    $s->fail('cannot create owned directory') unless -d $path;
}
sub sync_directory {
    my ($s, $path) = @_;
    sysopen my $dir, $path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW or $s->fail('cannot open state directory');
    $dir->sync or $s->fail('cannot sync state directory');
    close $dir or $s->fail('cannot close state directory');
}
sub lock {
    my ($s, $slug) = @_;
    $s->directories("$s->{common}/codex-workflow-locks");
    my $path = "$s->{common}/codex-workflow-locks/checkout.lock";
    $s->safe_path($path);
    sysopen my $fh, $path, O_RDWR | O_CREAT | O_NOFOLLOW, 0600 or $s->fail('cannot open ownership lock');
    flock($fh, LOCK_EX | LOCK_NB) or $s->fail('checkout already has an active owner');
    fcntl($fh, F_SETFD, fcntl($fh, F_GETFD, 0) & ~FD_CLOEXEC) or $s->fail('cannot retain child ownership');
    $s->{lock} = $fh;
}
sub diagnostic {
    my ($s, $run) = @_;
    my $fh = $s->{lock};
    seek($fh, 0, 0) && truncate($fh, 0) or $s->fail('cannot write lock diagnostic');
    print {$fh} json()->encode({run_id => $run, host => hostname(), pid => $$, observed_utc => $s->now})
        or $s->fail('cannot write lock diagnostic');
    $fh->flush or $s->fail('cannot flush lock diagnostic');
}
sub state_path { "$_[0]{common}/codex-workflow-runs/$_[1]/state.json" }
sub projection_path { "agent/progress/runs/$_[1].json" }
sub validate_state {
    my ($s, $v) = @_;
    for my $key (qw(schema generation run_id change_id slug branch change_path repository checkout initial_branch initial_source config baseline source target intent phase previous_phase phase_result blockers next_action updated_utc created_utc checks reviews merge gates run_complete artifacts projection prerequisites observations)) {
        $s->fail("missing state field $key") unless exists $v->{$key};
    }
    $s->fail('unsupported state schema/generation') unless $v->{schema} eq '1' && $v->{generation} =~ /^[1-9][0-9]*$/;
    $s->fail('invalid state identity') unless run_ok($v->{run_id}) && slug_ok($v->{slug})
        && $v->{branch} eq "change/$v->{slug}" && $v->{change_path} eq "agent/changes/$v->{slug}.md"
        && $v->{change_id} eq 'S' . (split /-/, $v->{slug})[0];
    $s->fail('repository identity conflict') unless ref $v->{repository} eq 'HASH'
        && ($v->{repository}{common} // '') eq $s->{common} && ($v->{repository}{id} // '') eq $s->{repo_id};
    $s->fail('checkout identity conflict') unless $v->{checkout} eq $s->{root};
    $s->fail('invalid initial branch') unless $v->{initial_branch} =~ /\S/;
    $s->fail('invalid initial source') unless oid_ok($v->{initial_source});
    $s->fail('invalid state commits') if grep { !oid_ok($v->{$_}) } qw(baseline source target intent);
    $s->fail('invalid UTC timestamp') if grep { !defined $v->{$_} || $v->{$_} !~ /\A\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ\z/ } qw(updated_utc created_utc);
    $s->fail('invalid next action') unless defined $v->{next_action} && !ref $v->{next_action} && $v->{next_action} =~ /\S/;
    $s->fail('unsupported later phase: use S004/manual reconciliation') unless $v->{phase} =~ /\A(?:preparing|prepared|blocked|interrupted)\z/
        && $v->{previous_phase} =~ /\A(?:preparing|prepared)\z/;
    $s->fail('invalid phase result') unless $v->{phase_result} =~ /\A(?:pending|passed|failed|interrupted)\z/;
    for (qw(blockers checks reviews artifacts prerequisites observations)) { $s->fail("invalid state container $_") unless ref $v->{$_} eq 'ARRAY'; }
    for my $blocker (@{$v->{blockers}}) {
        $s->fail('invalid blocker') unless ref $blocker eq 'HASH' && !grep { !defined $blocker->{$_} || ref $blocker->{$_} || $blocker->{$_} !~ /\S/ } qw(reason owner next_action);
    }
    $s->fail('unsupported later evidence: use S004') if @{$v->{checks}} || @{$v->{reviews}} || defined $v->{merge} || $v->{run_complete};
    $s->fail('invalid gates') unless ref $v->{gates} eq 'HASH' && !grep { ($v->{gates}{$_} // '') ne 'unmet' } qw(implementation review merge requirement_validation);
    $s->fail('invalid gate approval') if grep { $_ ne 'unmet' } values %{$v->{gates}};
    $s->fail('invalid configuration') unless ref $v->{config} eq 'HASH' && ($v->{config}{target} // '') eq 'dev'
        && ($v->{config}{mode} // '') =~ /\A(?:local|remote)\z/ && $v->{config}{checkout} eq $v->{checkout};
    if ($v->{config}{mode} eq 'remote') {
        $s->remote_ok($v->{config}{remote});
        $s->fail('invalid remote configuration identity') unless ($v->{config}{remote_identity} // '') =~ /\A[a-f0-9]{64}\z/;
    }
    else { $s->fail('local mode contains remote configuration') if defined $v->{config}{remote}; }
    for my $a (@{$v->{artifacts}}) { $s->fail('unsafe artifact path') unless ref $a eq 'HASH' && relative_ok($a->{path}) && ($a->{sha256} // '') =~ /^[a-f0-9]{64}$/; }
    $s->fail('invalid projection metadata') unless ref $v->{projection} eq 'HASH'
        && $v->{projection}{path} eq projection_path($s, $v->{run_id});
    if (defined $v->{projection}{sha256}) {
        $s->fail('invalid projection identity') unless $v->{projection}{sha256} =~ /\A[a-f0-9]{64}\z/
            && ($v->{projection}{generation} // '') =~ /\A[1-9][0-9]*\z/ && $v->{projection}{generation} <= $v->{generation};
    }
    return $v;
}
sub read_state {
    my ($s, $id) = @_;
    $s->fail('unsafe run ID') unless run_ok($id);
    my $v = $s->validate_state($s->decode($s->bytes($s->state_path($id))));
    $s->fail('run path/identity conflict') unless $v->{run_id} eq $id;
    $s->commit($v->{$_}) for qw(baseline source target intent);
    return $v;
}
sub diagnostic_artifacts {
    my ($s, $slug) = @_;
    my @artifacts;
    # Retain content-bound references, never reinterpret predecessor reviews as
    # prerequisites. Existing malformed diagnostics remain private artifacts.
    for my $path (bsd_glob "$s->{common}/mch-workflow-evidence/$slug/*/receipt.json") {
        my $relative = File::Spec->abs2rel($path, $s->{common});
        $s->fail('unsafe diagnostic artifact') unless relative_ok($relative);
        push @artifacts, {path => $relative, sha256 => sha256_hex($s->bytes($path)), purpose => 'legacy diagnostic only, not a gate'};
    }
    return \@artifacts;
}
sub atomic {
    my ($s, $path, $bytes) = @_;
    $s->safe_path($path); $s->directories(dirname($path));
    $s->hook('create');
    my ($fh, $temp) = tempfile('.workflow-XXXXXXXX', DIR => dirname($path), UNLINK => 0);
    binmode $fh; chmod 0600, $temp or $s->fail('cannot set private file permissions');
    my $ok = eval {
        $s->hook('write');
        my $written = syswrite($fh, $bytes);
        $s->hook('short-write');
        $s->fail('short state write') unless defined $written && $written == length $bytes;
        $s->hook('flush'); $fh->flush or $s->fail('cannot flush state');
        $s->hook('file-sync'); $fh->sync or $s->fail('cannot sync state');
        close $fh or $s->fail('cannot close state');
        $s->hook('rename'); rename $temp, $path or $s->fail('cannot replace state');
        $s->hook('directory-sync');
        $s->sync_directory(dirname($path));
        1;
    };
    my $error = $@;
    close $fh if defined fileno $fh;
    unlink $temp if -f $temp;
    die $error unless $ok;
}
sub save_state {
    my ($s, $v, $expected) = @_;
    $s->fail('state mutation without ownership') unless $s->{lock};
    my $path = $s->state_path($v->{run_id});
    if (defined $expected) {
        my $old = $s->read_state($v->{run_id});
        $s->fail('stale generation') unless $old->{generation} == $expected;
        for (qw(run_id slug branch baseline intent checkout initial_branch initial_source)) { $s->fail("immutable state changed: $_") unless $old->{$_} eq $v->{$_}; }
        $s->fail('immutable configuration changed') unless json()->encode($old->{config}) eq json()->encode($v->{config});
        $s->fail('invalid phase transition') if $old->{phase} eq 'prepared' && $v->{phase} eq 'preparing';
    } else { $s->fail('runtime already exists') if -e $path; }
    my $candidate = { %$v, generation => defined $expected ? $expected + 1 : 1 };
    $s->validate_state($candidate);
    $s->atomic($path, json()->encode($candidate));
    %$v = %$candidate;
    return $v;
}
sub portable {
    my ($s, $v) = @_;
    return json()->encode({schema => 1, run_id => $v->{run_id}, generation => $v->{generation},
        change_id => $v->{change_id}, slug => $v->{slug}, branch => $v->{branch}, change_path => $v->{change_path},
        baseline => $v->{baseline}, source => $v->{source}, target => $v->{target},
        phase => $v->{phase}, phase_result => $v->{phase_result}, run_complete => JSON::PP::false,
        gates => $v->{gates}, checks => [], reviews => [], merge => undef,
        checkout => 'local/unavailable', mode => $v->{config}{mode},
        remote_freshness => $v->{config}{mode} eq 'local' ? 'not checked' : 'observed',
        updated_utc => $v->{updated_utc}, next_action => $v->{phase} eq 'prepared' ? 'S004/manual bootstrap required' : 'Explicit resume/reconciliation required'});
}
sub projection_valid {
    my ($s, $v) = @_;
    my $p = "$v->{checkout}/$v->{projection}{path}";
    return 0 unless -f $p && !-l $p && defined $v->{projection}{sha256}
        && ($v->{projection}{generation} // 0) == $v->{generation};
    my $bytes = $s->bytes($p);
    return sha256_hex($bytes) eq $v->{projection}{sha256} && $bytes eq $s->portable($v);
}
sub publish {
    my ($s, $v) = @_;
    # Three durable boundaries: reserve publication intent (not success), write
    # portable bytes, then mark prepared. The pending digest lets resume identify
    # exactly our bytes if killed between projection and final state replacement.
    my $next = { %$v, generation => $v->{generation} + 2, updated_utc => $s->now, phase => 'prepared', phase_result => 'passed', blockers => [], next_action => 'S004/manual bootstrap required' };
    $next->{observations} = [@{$v->{observations}}];
    push @{$next->{observations}}, { projection_sha256 => $v->{projection}{sha256} } if $v->{projection}{sha256};
    push @{$next->{observations}}, { projection_sha256 => $v->{projection}{pending_sha256} } if $v->{projection}{pending_sha256};
    $next->{projection} = { path => $v->{projection}{path}, generation => $next->{generation}, sha256 => sha256_hex($s->portable($next)) };
    my $pending = { %$v, observations => $next->{observations}, phase_result => 'pending', updated_utc => $next->{updated_utc},
        projection => { %{$v->{projection}}, pending_generation => $next->{generation}, pending_sha256 => $next->{projection}{sha256} } };
    $s->save_state($pending, $v->{generation}); %$v = %$pending;
    $s->hook('before-projection');
    my $path = "$v->{checkout}/$v->{projection}{path}";
    if (-e $path) {
        # Only bytes published/declared by this run may be replaced. The caller
        # checks the old projection before reserving this next generation.
        $s->fail('projection changed during publication') unless defined $s->{owned_projection}
            && $s->bytes($path) eq $s->{owned_projection};
    }
    $s->atomic($path, $s->portable($next));
    $s->hook('after-projection');
    $s->save_state($next, $v->{generation}); %$v = %$next;
    $s->fail('projection publication verification failed') unless $s->projection_valid($v);
}
sub clean {
    my ($s, $root, $v, $repair) = @_;
    my $out = $s->git('-C', $root, '-c', 'status.showUntrackedFiles=all', 'status', '--porcelain=v1', '-z', '--untracked-files=all', '--ignore-submodules=none');
    my @entries = split /\0/, $out;
    for my $line (@entries) {
        next unless length $line;
        if ($v && $line eq '?? ' . $v->{projection}{path}) {
            my $bytes = $s->bytes("$root/$v->{projection}{path}");
            if ($s->projection_valid($v)) { $s->{owned_projection} = $bytes; next; }
            # A prior durable snapshot is repairable only if its exact bytes
            # were retained with a digest in the runtime observation history.
            if ($repair && (($v->{projection}{pending_sha256} // '') eq sha256_hex($bytes)
                || grep { ($_->{projection_sha256} // '') eq sha256_hex($bytes) } @{$v->{observations}})) {
                $s->{owned_projection} = $bytes; next;
            }
        }
        $s->fail('unrelated dirty/staged/untracked/submodule input');
    }
}
sub remote_ok {
    my ($s, $remote) = @_;
    $s->fail('invalid remote name') unless defined $remote && $remote =~ /\A[a-zA-Z0-9][a-zA-Z0-9_.-]*\z/;
    my %remotes = map { $_ => 1 } split /\n/, $s->git('remote');
    $s->fail('unknown configured remote') unless $remotes{$remote};
}
sub remote_identity {
    my ($s, $remote) = @_;
    # Bind immutable effective URL without persisting credentials or printing it.
    return sha256_hex($s->git('remote', 'get-url', '--', $remote));
}
sub target {
    my ($s, $config, $state) = @_;
    return $s->commit('refs/heads/dev') if $config->{mode} eq 'local';
    my $remote = $config->{remote}; $s->remote_ok($remote);
    # BatchMode avoids interactive credential prompts; Git credentials/helpers
    # and SSH agent remain host-owned. Never echo captured stderr/remote URLs.
    local $ENV{GIT_TERMINAL_PROMPT} = '0';
    local $ENV{GIT_SSH_COMMAND} = $ENV{GIT_SSH_COMMAND} // 'ssh -o BatchMode=yes';
    my $ref = "refs/remotes/$remote/dev";
    my @fetch = ('fetch', '--no-tags', '--no-recurse-submodules', '--', $remote, "+refs/heads/dev:$ref");
    my ($rc) = $s->command('git', '-C', $s->{root}, @fetch);
    $s->{refresh_observation} = { operation => 'fetch refs/heads/dev', command => ['git', @fetch], remote => $remote, exit => $rc, observed_utc => $s->now };
    push @{$state->{observations}}, $s->{refresh_observation} if $state;
    $s->fail('remote authentication/refresh failed; cached refs not accepted') if $rc;
    return $s->commit($ref);
}
sub branch_absent {
    my ($s, $branch) = @_;
    my $refs = $s->git('for-each-ref', '--format=%(refname)', 'refs/heads', 'refs/remotes');
    $s->fail('existing local/remote-tracking branch; use explicit run reconciliation') if grep { $_ eq "refs/heads/$branch" || m{^refs/remotes/[^/]+/\Q$branch\E$} } split /\n/, $refs;
}
sub start {
    my ($s, $slug, $config) = @_;
    my $entry = $s->inventory($slug);
    $s->clean($s->{root});
    if ($config->{mode} eq 'remote') {
        $s->remote_ok($config->{remote});
        $config->{remote_identity} = $s->remote_identity($config->{remote});
    }
    $config->{checkout} = $s->{root}; $config->{target} = 'dev';
    $s->lock($slug);
    $s->branch_absent("change/$slug");
    for my $path (bsd_glob "$s->{common}/codex-workflow-runs/*/state.json") {
        my $v = $s->decode($s->bytes($path));
        $s->fail('existing run for slug; explicit resume required') if ($v->{slug} // '') eq $slug;
    }
    my $baseline = $s->commit('refs/heads/dev');
    $s->tools; # Dependency integration is checked at the selected target below,
              # not at a possibly stale local dev in explicit remote mode.
    $baseline = $s->target($config);
    my $prereqs = $s->prerequisites($entry, $baseline);
    $s->hook('after-refresh');
    $s->clean($s->{root}); $s->branch_absent("change/$slug");
    my $initial_branch = $s->git('symbolic-ref', '--quiet', '--short', 'HEAD');
    my $initial_source = $s->commit('HEAD');
    my $id = 'r-' . substr(sha256_hex(join ':', $s->now, $$, rand(), $s->{common}, $slug), 0, 32);
    $s->directories("$s->{common}/codex-workflow-runs");
    mkdir "$s->{common}/codex-workflow-runs/$id", 0700 or $s->fail('exclusive run allocation failed');
    $s->sync_directory("$s->{common}/codex-workflow-runs");
    $s->diagnostic($id);
    my $v = { schema => 1, generation => 1, run_id => $id, change_id => $entry->{id}, slug => $slug,
        branch => "change/$slug", change_path => $entry->{path}, repository => { id => $s->{repo_id}, common => $s->{common} },
        checkout => $s->{root}, initial_branch => $initial_branch, initial_source => $initial_source, config => $config, baseline => $baseline, source => $baseline, target => $baseline, intent => $baseline,
        phase => 'preparing', previous_phase => 'preparing', phase_result => 'pending', blockers => [],
        next_action => 'Explicit resume to reconcile preparation', updated_utc => $s->now, created_utc => $s->now,
        checks => [], reviews => [], merge => undef, gates => { map { $_ => 'unmet' } qw(implementation review merge requirement_validation) },
        run_complete => JSON::PP::false, artifacts => $s->diagnostic_artifacts($slug), projection => {path => $s->projection_path($id)}, prerequisites => $prereqs,
        tool => {revision => $s->commit('HEAD'), module_sha256 => sha256_hex($s->bytes(__FILE__))},
        observations => [$config->{mode} eq 'local' ? { operation => 'remote freshness not checked', exit => 0, target => $baseline, observed_utc => $s->now }
            : {%{$s->{refresh_observation}}, target => $baseline}] };
    $s->{state} = $v;
    $s->hook('before-intent'); $s->save_state($v, undef); $s->hook('after-intent');
    $s->create_branch($v);
    $s->clean($v->{checkout}, $v);
    $s->publish($v);
    return $v;
}
# Preparation uses this checkout only. No destination or extra-checkout owner
# exists: Git's selected branch and the run's original branch/source are enough.
sub create_branch {
    my ($s, $v) = @_;
    $s->hook('before-git');
    $s->fail('caller branch/source changed before creation') unless
        $s->git('symbolic-ref', '--quiet', '--short', 'HEAD') eq $v->{initial_branch}
        && $s->commit('HEAD') eq $v->{initial_source};
    $s->clean($s->{root}, $v, 1);
    $s->git('checkout', '--no-overwrite-ignore', '-b', $v->{branch}, $v->{intent});
    $s->hook('after-git');
    $s->verify_checkout($v);
}
sub verify_checkout {
    my ($s, $v) = @_;
    $s->fail('checkout repository/branch identity conflict') unless $v->{checkout} eq $s->{root}
        && $s->git('symbolic-ref', '--quiet', '--short', 'HEAD') eq $v->{branch};
    my $actual = $s->commit('HEAD');
    if ($actual ne $v->{source}) {
        push @{$v->{observations}}, { source_old => $v->{source}, source_new => $actual, evidence_usable => JSON::PP::false };
        $s->fail('source drift; S004 integration/revalidation required');
    }
    $s->inventory($v->{slug});
}
sub reconcile {
    my ($s, $v, $resume) = @_;
    $s->lock($v->{slug});
    $v = $s->read_state($v->{run_id}); $s->{state} = $v;
    $s->diagnostic($v->{run_id});
    $s->commit($v->{baseline}); $s->commit($v->{intent});
    my $entry = $s->inventory($v->{slug});
    $s->fail('configured remote identity changed') if $v->{config}{mode} eq 'remote'
        && $s->remote_identity($v->{config}{remote}) ne ($v->{config}{remote_identity} // '');
    $s->clean($s->{root}, $v, $resume);
    my $prerequisites = $s->prerequisites($entry, $v->{baseline});
    $s->fail('effective prerequisite configuration changed') unless json()->encode($prerequisites) eq json()->encode($v->{prerequisites});
    my $target = $s->target($v->{config}, $v);
    if ($target ne $v->{target}) {
        push @{$v->{observations}}, { target_old => $v->{target}, target_new => $target, evidence_usable => JSON::PP::false };
        $s->fail('target drift; S004 integration/revalidation required');
    }
    $s->clean($s->{root}, $v, $resume);
    my $selected = $s->git('symbolic-ref', '--quiet', '--short', 'HEAD');
    if ($selected ne $v->{branch}) {
        $s->fail('checkout branch changed; manual reconciliation required') unless $v->{previous_phase} eq 'preparing'
            && $v->{phase} ne 'prepared' && $selected eq $v->{initial_branch}
            && $s->commit('HEAD') eq $v->{initial_source};
        $s->branch_absent($v->{branch});
        $s->fail('creation pending; use explicit resume') unless $resume;
        $s->create_branch($v);
    } else {
        $s->verify_checkout($v);
    }
    $s->clean($v->{checkout}, $v, $resume);
    if ($s->projection_valid($v) && $v->{phase} eq 'prepared') {
        push @{$v->{observations}}, { operation => $resume ? 'resume' : 'preflight', observed_utc => $s->now, source => $v->{source}, target => $target };
        $s->publish($v);
        return $v;
    }
    $s->fail('projection/setup unreconciled; use explicit resume') unless $resume;
    $s->publish($v);
    return $v;
}
sub status {
    my ($s, $v) = @_;
    my $path = "$s->{common}/codex-workflow-locks/checkout.lock";
    my $active = 0;
    if (-e $path) {
        $s->safe_path($path);
        sysopen my $fh, $path, O_RDONLY | O_NOFOLLOW or $s->fail('cannot inspect lock');
        $active = flock($fh, LOCK_SH | LOCK_NB) ? 0 : 1;
        close $fh;
    }
    my $projection = $s->projection_valid($v);
    my ($source, $target, $git_error);
    eval { $source = $s->commit("refs/heads/$v->{branch}"); $target = $s->commit($v->{config}{mode} eq 'local' ? 'refs/heads/dev' : "refs/remotes/$v->{config}{remote}/dev"); 1 } or $git_error = 'Git observation unavailable';
    my $drift = $git_error || ($source // '') ne $v->{source} || ($target // '') ne $v->{target};
    my $checkout_ok = eval { $s->verify_checkout($v); 1 };
    my $clean = eval { $s->clean($s->{root}, $v); 1 };
    return { %$v, inspection => { active_writer => $active ? JSON::PP::true : JSON::PP::false,
        source_observed => $source, target_cached_observed => $target, git_error => $git_error,
        checkout_clean => $clean ? JSON::PP::true : JSON::PP::false,
        checkout_consistent => $checkout_ok ? JSON::PP::true : JSON::PP::false,
        projection_consistent => $projection ? JSON::PP::true : JSON::PP::false,
        reconciliation_required => $active || !$projection || $drift || !$checkout_ok || !$clean || $v->{phase} ne 'prepared' ? JSON::PP::true : JSON::PP::false } };
}
sub report {
    my ($s, $v) = @_;
    return { map({ $_ => $v->{$_} } qw(run_id slug phase phase_result run_complete baseline source target blockers next_action)),
        runtime => $s->state_path($v->{run_id}), portable => "$v->{checkout}/$v->{projection}{path}",
        (exists $v->{inspection} ? (inspection => $v->{inspection}) : ()) };
}
sub cli {
    my ($s, @args) = @_;
    my ($op, $slug, %config, $id);
    my $usage = "usage: workflow-run.pl start <slug> (--local | --remote <name>); status|preflight|resume --run <run-id>\n";
    $op = shift @args // '';
    if ($op eq 'start') {
        $slug = shift @args;
        while (@args) {
            my $key = shift @args;
            if ($key eq '--local' && !exists $config{mode}) { $config{mode} = 'local'; }
            elsif ($key eq '--remote' && !exists $config{mode} && @args) { $config{mode} = 'remote'; $config{remote} = shift @args; }
            else { print STDERR $usage; return 2; }
        }
        unless (slug_ok($slug) && $config{mode}) { print STDERR $usage; return 2; }
    } elsif ($op =~ /\A(?:status|preflight|resume)\z/ && @args == 2 && $args[0] eq '--run' && run_ok($args[1])) { $id = $args[1]; }
    else { print STDERR $usage; return 2; }
    my $signal;
    local $SIG{INT} = sub { $signal = 130; die "interrupted SIGINT\n"; };
    local $SIG{TERM} = sub { $signal = 143; die "interrupted SIGTERM\n"; };
    my $ok = eval {
        $s->repository;
        my $v = $op eq 'start' ? $s->start($slug, \%config) : $s->read_state($id);
        $v = $op eq 'status' ? $s->status($v) : $s->reconcile($v, $op eq 'resume') if $op ne 'start';
        print json()->encode($s->report($v));
        1;
    };
    my $error = $@;
    if (!$ok) {
        if (my $child = delete $s->{child}) { kill 'TERM', -$child; waitpid($child, 0); }
        if (my $v = $s->{state}) {
            # Reread after any post-rename failure: disk, not the in-memory
            # candidate, decides which generation is authoritative.
            eval {
                my $disk = $s->read_state($v->{run_id});
                push @{$disk->{observations}}, @{$v->{observations}}[$#{$disk->{observations}} + 1 .. $#{$v->{observations}}] if @{$v->{observations}} > @{$disk->{observations}};
                push @{$disk->{observations}}, { projection_sha256 => $disk->{projection}{sha256} } if $disk->{projection}{sha256};
                $disk->{previous_phase} = $disk->{phase} if $disk->{phase} =~ /^(?:preparing|prepared)$/;
                $disk->{phase} = $signal ? 'interrupted' : 'blocked'; $disk->{phase_result} = $signal ? 'interrupted' : 'failed';
                $disk->{updated_utc} = $s->now;
                # Child output/credentials are suppressed at the command
                # boundary; retain the actionable, bounded runner diagnostic.
                $disk->{blockers} = [{reason => $error, owner => 'workflow operator', next_action => 'Explicit resume/reconcile; never reset user work'}];
                $disk->{next_action} = 'Explicit resume/reconcile; S004 required for drift/later phases';
                $s->save_state($disk, $disk->{generation});
                print json()->encode($s->report($disk));
            };
        }
        print STDERR $error;
    }
    delete $s->{lock};
    return $ok ? 0 : ($signal // 1);
}
1;
