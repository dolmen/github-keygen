use strict;
use warnings;
use Test::More tests => 2;
use Test::Pod;

pod_file_ok($_) for qw< README.pod bin/github-keygen >;
