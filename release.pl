#!/usr/bin/env perl

use 5.010;
use strict;
use warnings;

# Only to fail early if the tool is missing
use App::FatPacker ();
use Carp;

#goto X;

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
system '(echo "#!/usr/bin/env perl"; fatpack file; cat bin/github-keygen) > github-keygen';
chmod 0755, 'github-keygen';

my $version = do {
    open my $version_output, '-|', './github-keygen -v' or die $!;
    my $line = <$version_output>;
    chomp $line;
    (split / /, $line)[2]
};

if (-e ".git/refs/tags/v$version") {
    say STDERR "version $version already released!";
#    exit 1
}

say "\$VERSION: $version";


sub git ($;@)
{
    my ($input, $output_cb);
    $output_cb = pop if ref $_[$#_] eq 'CODE';
    $input = pop if ref $_[$#_];
    my @args = @_;
    say join(' ', '[', git => @args, ']');
    my ($pid, $out);
    local $SIG{PIPE} = sub { say "SIGPIPE" };
    if ($input) {
	use IPC::Open2;
	my $in;
	$pid = open2($out, $in, git => @args) or die $!;
	binmode($in, ':utf8');
	if (ref $input eq 'ARRAY') {
	    print $in map { "$_\n" } @$input;
	} elsif (ref $input eq 'SCALAR') {
	    # use ${$input}} as raw input
	    print $in $$input;
	}
	close $in;
    } else {
	$pid = open($out, '-|', git => @args) or die $!;
    }
    binmode($out, ':utf8');
    if (wantarray) {
	my @output;
	if ($output_cb) {
	    while (<$out>) {
		chomp;
		push @output, $output_cb->($_)
	    }
	} else {
	    while (<$out>) {
		chomp;
		push @output, $_
	    }
	}
	waitpid($pid, 0);
	croak "git error ".($?>>8) if $? >> 8;
	return @output
    } elsif (defined wantarray) {
	# Only the first line
	my $output;
	defined($output = <$out>) and chomp $output;
	waitpid($pid, 0);
	croak "git error ".($?>>8) if $? >> 8;
	return $output
    } else { # void context
	if ($output_cb) {
	    while (<$out>) {
		chomp;
		$output_cb->($_)
	    }
	}
	waitpid($pid, 0);
	croak "git error ".($?>>8) if $? >> 8;
	return
    }
}


#my $old_tree = 

X:

my @new_files = (
    'github-keygen',
    @ARGV,
);

#my $devel = `git rev-parse devel`;
#my $master = `git rev-parse master`;
my ($devel_commit) = git 'rev-parse' => 'devel';
say "devel: $devel_commit";

my %devel_tree;
git 'ls-tree' => $devel_commit, sub {
    my ($mode, $type, $object, $file) = split;
    $devel_tree{$file} = [ $mode, $type, $object ];
};

my ($release_commit) = git 'rev-parse' => 'release';
say "release: $release_commit";
my %release_tree;
git 'ls-tree' => $release_commit, sub {
    my ($mode, $type, $object, $file) = split / |\t/;
    # Merge files updated in devel
    if (       $type eq 'blob'        # Don't touch trees
	    && $file ne '.gitignore'  # One .gitignore for each branch
	    && exists $devel_tree{$file}
	    && $object ne $devel_tree{$file}[2]) {
	say "- $file: $object (updated)";
	$release_tree{$file} = $devel_tree{$file};
    } else {
	say "- $file: $object";
	$release_tree{$file} = [ $mode, $type, $object ];
    }
};

# Create the objects file each new file and replace them
foreach my $file (@new_files) {
    # TODO
    my $object = git 'hash-object' => -w => $file;
    say "- $file: $object (updated)";
    $release_tree{$file}[2] = $object;
}

# Build the new tree object for release
my $new_release_tree = git mktree => -z =>
\(
    join(
	'',
	map { sprintf("%s %s %s\t%s\0", @{$release_tree{$_}}, $_) }
	    keys %release_tree
    )
);
say "new release tree: $new_release_tree";

# Create the release commit
# TODO use the "author" of devel as the committer
my $new_release_commit =
    git 'commit-tree', $new_release_tree,
		       -p => $release_commit,
		       -p => $devel_commit,
		       -m => "Release v$version";

say "new release commit: $new_release_commit";

git 'update-ref' => 'refs/heads/toto' => $new_release_commit, $release_commit;

exit 0; # ********

git tag => -a =>
	   -m => "Release v$version",
	   "v$version",
	   $new_release_commit;

exit 0;
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
