
# CPAN requirements
# -----------------
# See https://metacpan.org/pod/cpanfile

# We do not strictly require this ("recommends" should be enough), but this
# gives a much better experience. And, anyway, someone who uses this cpanfile
# obviouly has access to CPAN. Our fallback is only for users who don't (and
# we could even remove it now that we fatpack the modules).

requires 'Text::Diff';
requires 'Pod::Usage';

on test => sub {
    # xt/
    requires 'Test::More';
    requires 'Test::Pod';
    requires 'Test::Spelling';
    requires 'Test::Pod::No404s';
    requires 'Test::Requires';
    # Only available on perl 5.10+
    recommends 'Test::Vars' => '0.012';
};

on develop => sub {
    # Stuff for the maintainer to make releases (see release.pl)
    requires 'App::Prove';
    requires 'App::FatPacker';
    requires 'Module::CoreList';
    requires 'File::Copy';
    requires 'File::Path';
    requires 'IPC::Run';
    requires 'Symbol';
    requires 'LWP::Protocol::https'; # xt/03-03-no-404s.t
    requires 'Test::Vars';           # xt/04-unused-vars.t

    # tools/
    recommends 'Path::Tiny';
    recommends 'MIME::Base64';
    recommends 'JSON::PP';
};
