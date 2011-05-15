use inc::Module::Install;
name 'PDF-API2-Koromo';
all_from 'lib/PDF/API2/Koromo.pm';

requires 'Class::Accessor::Lite';  # PDF::API2::Koromo
requires 'Data::Validator';        # PDF::API2::Koromo
requires 'PDF::API2';              # PDF::API2::Koromo
requires 'Image::Magick';          # PDF::API2::Koromo
requires 'Image::Size';            # PDF::API2::Koromo
requires 'Try::Tiny';              # PDF::API2::Koromo

tests 't/*.t';
author_tests 'xt';

test_requires 'Test::More';
auto_set_repository;
auto_include;
WriteAll;
