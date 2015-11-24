#!perl

use strict; use warnings;

use Test::More 0.88
    # Test platforms may not have network access (Travis), so disable
    ($ENV{AUTOMATED_TESTING} ? (skip_all => 'Disabled for automated testing')
			     : ());

use Test::Pod::No404s;

$TODO = 'Test::Pod::No404s has issues with stribika.github.io and cpanmin.us';
pod_file_ok($_) for qw< README.pod bin/github-keygen CONTRIBUTING.pod >;

done_testing;
