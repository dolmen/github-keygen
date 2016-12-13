use strict;
use warnings;

use Test::More;
use Test::Vars;

# To use Test::Vars on a script, we wrap the script in a fake package
# in a fake package source file.

my $script = 'bin/github-keygen';
#my $fake_package = 'GHKG';
(my $fake_package = $script) =~ s/[^\w]/::/g;
(my $fake_source = "$fake_package.pm") =~ s/::/\//g;

note "Mocking $script as module $fake_package...";

sub require_fake {
    return unless $_[1] eq "$fake_source";
    open my $f, '<', $script or return;
    my $content = do { local $/; <$f> };
    close $f;
    $content =
	  "package $fake_package;\n"
	. "sub __main {\n"
	#. "#line 1 \"$script\"\n"
	. "#line 1 \"$fake_source\"\n"
	. $content;
    $content =~ s/^(__(?:END|DATA)__)$/} # end of __main\n1;\n$1/m;
    ( \$content )
};

unshift @INC, \&require_fake;

#print STDOUT ${ require_fake(undef, "$fake_source') }; exit;
#require $fake_source;

vars_ok($fake_package);
done_testing;
