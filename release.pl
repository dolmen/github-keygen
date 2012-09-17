#!/usr/bin/env perl

# Only to fail early if the tool is missing
use App::FatPacker ();

# Pod::Usage is supposed to be in core since 5.6, but it is missing from perl
# bundled in msysgit
my @MODULES = qw(Pod/Usage.pm Text/Diff.pm);

# Retrieve the packlists
my @packlists = qx(fatpack packlists-for @MODULES);

# Fill fatlib/
system qw(fatpack tree), @packlists;
foreach (@MODULES) {
    die "$_ is missing!" unless -f "fatlib/$_";
}
-d 'lib' or mkdir 'lib';

# Create the script
system '(fatpack file; cat bin/github-keygen) > github-keygen';
chmod 0755, 'github-keygen';

# TODO
print <<'EOF';
TODO:
  git stash save --include-untracked 'github-keygen fatpacked for release'
  git checkout master
  git stash pop
  git add github-keygen
  ????  # Merge to mark devel as merged
  git commit
  v=$(bin/github-keygen -v | head -n1 | cut -d' ' -f3)
  git tag -a -m "Version $v" "v$v"
EOF
