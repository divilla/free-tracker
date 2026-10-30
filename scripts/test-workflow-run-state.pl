#!/usr/bin/env perl
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/lib", "$FindBin::Bin/test-lib";
use Test::More;
use RunStateTest;

cases('G');
done_testing;
