#!/usr/bin/env perl
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/lib";
use mch::WorkflowRun;

exit mch::WorkflowRun->new(root => "$FindBin::Bin/..")->cli(@ARGV);
