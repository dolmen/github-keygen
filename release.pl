#!/usr/bin/env perl

use 5.010;
use strict;
use warnings;

# Only to fail early if the tool is missing
use App::FatPacker ();
use Carp 'croak';


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
    grep { (my $x = substr($_, 0, -3)) =~ s{/}{::}; $x =~ /^Pod::/ || ! $Module::CoreList::version{5.014002}{$x} } @MODULES;

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
	croak "no output" unless defined $output;
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



my @new_files = (
    'github-keygen',
    @ARGV,
);

my ($devel_commit) = git 'rev-parse' => 'devel';
say "devel: $devel_commit";

my %devel_tree;
git 'ls-tree' => $devel_commit, sub {
    my ($mode, $type, $object, $file) = split;
    $devel_tree{$file} = [ $mode, $type, $object ];
};

my %updated_files;
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
	$updated_files{$file} = 1;
    } else {
	say "- $file: $object";
	$release_tree{$file} = [ $mode, $type, $object ];
    }
};

# Create the objects file for each new file and replace them
foreach my $file (@new_files) {
    # TODO
    my $object = git 'hash-object' => -w => $file;
    if ($object ne $release_tree{$file}[2]) {
	say "- $file: $object (updated)";
	$release_tree{$file}[2] = $object;
	$updated_files{$file} = 1;
    }
}

die "github-keygen updated but version unchanged!"
    if $updated_files{'github-keygen'} && ! $version;

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
		       -p => $devel_commit,
		       -m => ($version ? "Release v$version" : "Update docs");

say "new release commit: $new_release_commit";

git 'update-ref' => 'refs/heads/release' => $new_release_commit, $release_commit;

if ($version) {
    git tag => -a =>
	       -m => "Release v$version",
	       "v$version",
	       $new_release_commit;
}

say 'Done.';
say "You can now push: git push github devel release v$version";
