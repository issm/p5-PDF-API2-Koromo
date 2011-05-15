use inc::Module::Install;
name 'PDF-API2-Koromo';
all_from 'lib/PDF/API2/Koromo.pm';

# requires '';

tests 't/*.t';
author_tests 'xt';

test_requires 'Test::More';
auto_set_repository;
auto_include;
WriteAll;
