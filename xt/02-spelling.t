use utf8;
use strict;
use warnings;

use Test::More;
use Test::Spelling;

plan skip_all => 'No working spellchecker (hint: install hunspell and LibreOffice dictionaries)'
  unless has_working_spellchecker;

local $TODO = 'Test::Spelling is broken (no UTF-8 support)';

add_stopwords <DATA>;
pod_file_spelling_ok $_ for qw< bin/github-keygen README.pod CONTRIBUTING.pod >;

done_testing;

__END__
Mengu
StrawberryPerl
MERCHANTABILITY
publickey
keygen
msys
msysgit
XDG
UI
hackathon
fatpacked
Beng
Hee
Figueiredo
Lefevre
advices
