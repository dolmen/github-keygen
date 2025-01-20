#!perl

use strict; use warnings;

use Test::More 0.88
    # Test platforms may not have network access (Travis), so disable
    ($ENV{AUTOMATED_TESTING} ? (skip_all => 'Disabled for automated testing')
			     : ());

use Test::Pod::No404s;

require_ok "LWP/Protocol/https.pm" or BAIL_OUT 'Module LWP::Protocol::https is required to check for https:// URLs';


# $TODO = 'Test::Pod::No404s has issues with ';

pod_file_ok($_) for qw< README.pod bin/github-keygen CONTRIBUTING.pod >;

done_testing;
