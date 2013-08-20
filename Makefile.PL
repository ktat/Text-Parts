use inc::Module::Install;

name     'Text-Parts';
all_from 'lib/Text/Parts.pm';
author   q{Ktat <ktat@cpan.org>};
license  'perl';

build_requires
    'Test::More' => 0,
    'File::Spec' => 0,
    ;
test_requires
    'Test::Requires'  => 0,
    'Digest::MD5'     => 0,
    ;

resources
    bugtracker => 'https://github.com/ktat/Text-Parts/issues',
    repository => 'https://github.com/ktat/Text-Parts',
    ;

auto_install;

WriteAll;

