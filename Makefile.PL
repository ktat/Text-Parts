use inc::Module::Install;

name     'Text-Parts';
all_from 'lib/Text/Parts.pm';
author   q{Ktat <ktat@cpan.org>};
license  'perl';

build_requires
    'Test::More' => 0,
    'File::Spec' => 0,
    ;

auto_install;

WriteAll;

