
# CPAN requirements
# -----------------
# See https://metacpan.org/pod/cpanfile

# We do not strictly require this ("recommends" should be enough), but this
# gives a much better experience. And, anyway, someone who uses this cpanfile
# obviouly has access to CPAN. Our fallback is only for users who don't (and
# we could even remove it now that we fatpack the modules).

requires 'Text::Diff';
requires 'Pod::Usage';

# Stuff for the maitainer to make releases (see release.pl)
on develop => sub {
    requires 'App::FatPacker';
    requires 'Module::CoreList';
    requires 'File::Copy';
    requires 'File::Path';
    requires 'IPC::Run';
    requires 'Symbol';
};
