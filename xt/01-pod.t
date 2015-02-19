use strict;
use warnings;
use Test::More tests => 3;
use Test::Pod;

pod_file_ok($_) for qw< README.pod CONTRIBUTING.pod bin/github-keygen >;
