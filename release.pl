#!/usr/bin/env perl

use 5.010;
use strict;
use warnings;

# Only to fail early if the tool is missing
use App::FatPacker ();
use Carp 'croak';
use Getopt::Long;

my $DRY_RUN;
my $SKIP_TESTS;

GetOptions(
    'n|dry-run|just-print' => \$DRY_RUN,
    'T|skip-tests' => \$SKIP_TESTS,
)
    or die "usage: $0 [-n]\n";

# Run author tests
unless ($SKIP_TESTS) {
    require App::Prove;
    for (App::Prove->new) {
	$_->process_args(qw< -v xt >);
	$_->run || exit 1
    }
}

# Pod::Usage is supposed to be in core since 5.6, but it is missing from perl
# bundled in msysgit
my @MODULES = qw(Pod/Usage.pm Algorithm/Diff.pm Text/Diff.pm);
my $NUL = $^O eq 'MSWin32' ? 'NUL' : '/dev/null';

@MODULES =
grep { !m{^(?:Config\.pm|(?:Carp|warnings|File/Spec)(?:\.pm|/))} }
do {
    system join(' ', qw(fatpack trace),
	(map { (my $x = substr($_, 0, -3)) =~ s{/}{::}; "--use=$x" } @MODULES),
		     "<$NUL", "2>$NUL");
    open my $trace, '<', 'fatpacker.trace' or die $!;
    map { chomp; $_ } <$trace>
};

unlink 'fatpacker.trace';

#say for @MODULES;

use Module::CoreList;

@MODULES =
    grep { (my $x = substr($_, 0, -3)) =~ s{/}{::}g; $x =~ /^Pod::/ || ! $Module::CoreList::version{'5.014002'}{$x} } @MODULES;

#say for @MODULES;
#exit 0;

# Retrieve the packlists
my @packlists = qx(fatpack packlists-for @MODULES);

#say for @packlists;


# Fill fatlib/
# Unfortunately FatPacker copies whole distribution instead of just what we need
# And it misses distribution that do not have .packlists
#system qw(fatpack tree), @packlists;
#foreach (@MODULES) {
#    die "$_ is missing!" unless -f "fatlib/$_";
#}

use File::Copy 'copy';
use File::Path qw'make_path remove_tree';

-d 'fatlib' and (remove_tree 'fatlib' or die $!);
(-d $_ or mkdir $_) for qw(lib fatlib);
foreach my $m (@MODULES) {
    (my $dir = $m) =~ s{/[^/]*$}{};
    $dir = "fatlib/$dir";
    make_path $dir;

    foreach my $I (@INC) {
	if (-f "$I/$m") {
	    copy "$I/$m", "$dir" or die $!;
	    last;
	}
    }
}


# Create the script
#system '(echo "#!/usr/bin/env perl"; fatpack file; cat bin/github-keygen) > github-keygen';
open my $script, '>:raw', 'github-keygen';
print $script "#!/usr/bin/env perl\n";
close $script;
system "fatpack file >> github-keygen";
open $script, '>>:raw', 'github-keygen';
copy('bin/github-keygen', $script);
close $script;

chmod 0755, 'github-keygen';

my $version = do {
    open my $version_output, '-|', 'perl github-keygen -v' or die $!;
    my $line = <$version_output>;
    chomp $line;
    (split / /, $line)[2]
};

die "could not get \$VERSION" unless $version;

say "\$VERSION: $version";

if (-e ".git/refs/tags/v$version") {
    say STDERR "version $version already released!";
    $version = undef;
}

use IPC::Run qw(start finish);
use Symbol 'gensym';

sub git ($;@)
{
    my ($input, $output_cb);
    $output_cb = pop if ref $_[$#_] eq 'CODE';
    $input = pop if ref $_[$#_];
    my @args = @_;
    say join(' ', '[', git => map { / / ? qq{"$_"} : $_ } @args, ']');
    my $h;
    my $out = gensym; # IPC::Run needs GLOBs
    if ($input) {
	my $in = gensym;
	$h = start [ git => @args ], '<pipe', $in, '>pipe', $out or die $!;
	binmode($in, ':utf8');
	if (ref $input eq 'ARRAY') {
	    print $in map { "$_\n" } @$input;
	} elsif (ref $input eq 'SCALAR') {
	    # use ${$input}} as raw input
	    print $in $$input;
	}
	close $in;
    } else {
	$h = start [ git => @args ], \undef, '>pipe', $out or die $!;
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
	close $out;
	finish $h;
	croak "git error ".($?>>8) if $? >> 8;
	return @output
    } elsif (defined wantarray) {
	# Only the first line
	my $output;
	defined($output = <$out>) and chomp $output;
	close $out;
	finish $h;
	croak "git error ".($?>>8) if $? >> 8;
	croak "no output" unless defined $output;
	return $output
    } else { # void context
	if ($output_cb) {
	    while (<$out>) {
		chomp;
		$output_cb->($_)
	    }
	}
	close $out;
	finish $h;
	croak "git error ".($?>>8) if $? >> 8;
	return
    }
}



my @new_files = (
    'github-keygen',
    @ARGV,
);

my ($HEAD_commit) = git 'rev-parse' => 'HEAD';
say "HEAD: $HEAD_commit";

my %HEAD_tree;
git 'ls-tree' => $HEAD_commit, sub {
    my ($mode, $type, $object, $file) = split;
    $HEAD_tree{$file} = [ $mode, $type, $object ];
};

my %updated_files;
my ($release_commit) = git 'rev-parse' => 'release';
say "release: $release_commit";
my %release_tree;
git 'ls-tree' => $release_commit, sub {
    my ($mode, $type, $object, $file) = split / |\t/;
    # Merge files updated in devel
    if (       $type eq 'blob'        # Don't touch trees
	    # Those files stay in 'devel' branch
	    && $file !~ /^(?:\.gitignore|cpanfile|tools|\.(travis|appveyor)\.yml)\z/
	    && exists $HEAD_tree{$file}
	    && $object ne $HEAD_tree{$file}[2]) {
	printf "- %s %-20s (updating)\n", $object, $file;
	$release_tree{$file} = $HEAD_tree{$file};
	$updated_files{$file} = 1;
    } else {
	say "- $object $file";
	$release_tree{$file} = [ $mode, $type, $object ];
    }
};

# Create the objects file for each new file and replace them
foreach my $file (@new_files) {
    # TODO
    my $object = git 'hash-object' => -w => $file;
    if ($object ne $release_tree{$file}[2]) {
	printf "- %s %-20s (updating)\n", $object, $file;
	$release_tree{$file}[2] = $object;
	$updated_files{$file} = 1;
    }
}

die "no updated files!\n"
    unless %updated_files;

die "github-keygen updated but version unchanged!\n"
    if $updated_files{'github-keygen'} && ! $version;

if ($DRY_RUN) {
    say "Stop before doing real suff.";
    exit 0
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
# TODO use more content in the commit message (ask interactively)
my $new_release_commit =
    git 'commit-tree', $new_release_tree,
		       -p => $release_commit,
		       -p => $HEAD_commit,
		       # For maximum compat, don't use '-m' but STDIN
		       \($version
			    ? "Release v$version"
			    : "Update ".join(', ', sort keys %updated_files));

say "new release commit: $new_release_commit";

my $branch = git 'symbolic-ref', 'HEAD';

# If we build from the 'devel' branch, update the 'release' branch
if ($branch eq 'refs/heads/devel') {
    git 'update-ref' => 'refs/heads/release' => $new_release_commit, $release_commit;

    if ($version) {
	git tag => -a =>
	           -m => "Release v$version",
		   "v$version",
		   $new_release_commit;
	say 'Done'.
	say "You can now push: git push github devel release v$version";
    } else {
	say "You can now push: git push github devel release";
    }
# Else: just create a tag to the build result, so we can check it out for
# testing
} else {
    $branch =~ s{^refs/(?:heads|remotes/[^/]+)/}{};
    git tag => -a =>
	       -m => "Build for branch $branch",
	       "$branch.build",
	       $new_release_commit;
    say "You can now check out the build: git checkout $branch.build";
}

