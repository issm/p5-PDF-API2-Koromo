use inc::Module::Install;
name 'PDF-API2-Koromo';
all_from 'lib/PDF/API2/Koromo.pm';

requires 'Class::Accessor::Lite';
requires 'Data::Validator';
requires 'MouseX::Types';
requires 'PDF::API2';
requires 'Image::Size';
requires 'Image::Magick';
requires 'Furl';
requires 'Try::Tiny';

tests 't/*.t t/*/*.t';
author_tests 'xt';

test_requires 'Test::More';
auto_set_repository;
auto_include;
WriteAll;
