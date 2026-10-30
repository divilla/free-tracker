#!/usr/bin/env perl
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/lib";
use JSON::PP;
use mch::WorkflowEvidence qw(delivery_status);

@ARGV == 2 or die "usage: perl scripts/workflow-evidence.pl <slug> <dev-commit-or-ref>\n";
my $result = delivery_status(@ARGV);
print JSON::PP->new->canonical->pretty->encode($result);
# Inspection success is not a delivery verdict. Unknown outcomes stay explicit.
