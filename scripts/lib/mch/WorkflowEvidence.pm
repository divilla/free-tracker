package mch::WorkflowEvidence;
use strict;
use warnings;
use Exporter 'import';
use Cwd qw(abs_path);
use File::Path qw(make_path);
use File::Spec;
use File::Temp qw(tempdir tempfile);
use IO::Handle;
use JSON::PP qw(decode_json);
use POSIX qw(strftime);
use Time::HiRes qw(time);

our @EXPORT_OK = qw(git_value save_receipt delivery_status implementation_outcome);

sub git_value {
    open my $fh, '-|', 'git', @_ or die "cannot start git: $!\n";
    local $/;
    my $value = <$fh> // '';
    close $fh or die "git @_ failed\n";
    $value =~ s/\s+\z//;
    return $value;
}

sub slug_ok { defined $_[0] && $_[0] =~ /\A[0-9][0-9][0-9]+-[a-z0-9-_]+\z/ }

sub evidence_root {
    my $common = abs_path(git_value(qw(rev-parse --absolute-git-dir)));
    defined $common or die "cannot resolve Git directory\n";
    return File::Spec->catdir($common, 'mch-workflow-evidence');
}

sub read_json {
    my ($path) = @_;
    open my $fh, '<:raw', $path or die "cannot read $path: $!\n";
    local $/;
    my $value = decode_json(<$fh> // '');
    close $fh or die "cannot close $path: $!\n";
    ref $value eq 'HASH' or die "invalid object in $path\n";
    return $value;
}

# This is an observation receipt, not S003's run-state ledger or a gate writer.
# Each observation is immutable; atomic publication leaves an interrupted write
# visibly incomplete rather than replacing a previously valid receipt.
sub save_receipt {
    my ($slug, $data) = @_;
    slug_ok($slug) or die "invalid evidence slug\n";
    my $parent = File::Spec->catdir(evidence_root(), $slug);
    make_path($parent, { mode => 0700 });
    my $dir = tempdir(sprintf('%.6f-', time) . 'XXXXXXXX', DIR => $parent, CLEANUP => 0);
    my ($fh, $temporary) = tempfile('receipt-XXXXXXXX', DIR => $dir, UNLINK => 0);
    my $receipt = { %$data, schema => 1, slug => $slug,
        observed_utc => strftime('%Y-%m-%dT%H:%M:%SZ', gmtime),
        observation_order => time + 0 };
    print {$fh} JSON::PP->new->canonical->pretty->encode($receipt)
        or die "cannot write receipt: $!\n";
    $fh->flush && $fh->sync or die "cannot sync receipt: $!\n";
    close $fh or die "cannot close receipt: $!\n";
    my $path = File::Spec->catfile($dir, 'receipt.json');
    rename $temporary, $path or die "cannot publish receipt: $!\n";
    print "Workflow evidence: $path\n";
    return $path;
}

sub implementation_outcome {
    my ($path) = @_;
    return 'invalid' if !defined $path || !-f $path;
    my $value = eval { read_json($path) };
    return 'invalid' if !$value || ($value->{schema} // 0) != 1;
    my $outcome = $value->{outcome} // '';
    return $outcome if !ref $outcome && $outcome =~ /\A(?:complete|blocked|failed)\z/;
    return 'invalid';
}

sub delivery_status {
    my ($slug, $baseline) = @_;
    slug_ok($slug) or die "invalid evidence slug\n";
    $baseline = git_value('rev-parse', '--verify', '--end-of-options', "${baseline}^{commit}");
    my $parent = File::Spec->catdir(evidence_root(), $slug);
    my (@receipts, @incomplete, @diagnostic_errors);
    if (-d $parent) {
        opendir my $dh, $parent or die "cannot read evidence directory: $!\n";
        my @dirs = sort grep { $_ ne '.' && $_ ne '..' } readdir $dh;
        closedir $dh;
        for my $name (@dirs) {
            my $path = File::Spec->catfile($parent, $name, 'receipt.json');
            if (!-f $path) { push @incomplete, $name; next; }
            my $value = eval { read_json($path) };
            if (!$value || ($value->{schema} // '') ne '1' || ($value->{slug} // '') ne $slug
                || ($value->{observation_order} // '') !~ /\A[0-9]+(?:\.[0-9]+)?\z/) {
                push @diagnostic_errors, "invalid, unsupported or conflicting receipt: $path";
                next;
            }
            $value->{path} = $path;
            push @receipts, $value;
        }
    }
    @receipts = sort { $a->{observation_order} <=> $b->{observation_order}
        || $a->{path} cmp $b->{path} } @receipts;
    my $result = { schema => 1, slug => $slug, baseline => $baseline,
        integration => 'unverified', review => 'unverified', checks => 'inspect-required-checks',
        receipts => \@receipts, incomplete_observations => \@incomplete,
        diagnostic_errors => \@diagnostic_errors };
    # Integration is a Git fact, independent of whether diagnostic receipts
    # were retained. A consumer checks required contents, not delivery history.
    my @commits;
    for my $line (split /\n/, git_value('log', '--format=%H%x09%s', $baseline, '--')) {
        my ($commit, $subject) = split /\t/, $line, 2;
        push @commits, $commit if $subject eq "Implement change $slug";
    }
    if (@commits > 1) {
        $result->{integration} = 'ambiguous';
        $result->{integration_candidates} = \@commits;
        return $result;
    }
    return $result if !@commits;
    my $commit = $commits[0];
    $result->{integration} = 'verified';
    $result->{merge_commit} = $commit;
    my $tree = git_value('rev-parse', "${commit}^{tree}");
    my $parents = git_value('rev-list', '--parents', '-n', '1', $commit);
    my @merges = grep { ($_->{phase} // '') eq 'merge'
        && ($_->{outcome} // '') eq 'verified' && ($_->{merge_commit} // '') eq $commit } @receipts;
    for my $merge (@merges) {
        if ($tree ne ($merge->{tree} // '') || $parents ne "$commit " . ($merge->{baseline} // '')) {
            push @diagnostic_errors, "merge receipt conflicts with Git: $merge->{path}";
        }
    }
    my @reviews = grep { ($_->{phase} // '') eq 'review' && ($_->{mode} // '') eq 'code' } @receipts;
    my $review = $reviews[-1];
    if (!@diagnostic_errors && !@incomplete && $review && ($review->{outcome} // '') eq 'clean'
        && $parents eq "$commit " . ($review->{baseline} // '')
        && ($review->{tree} // '') eq $tree) {
        $result->{review} = 'verified';
        $result->{reviewed_source} = $review->{source};
    }
    return $result;
}

1;
