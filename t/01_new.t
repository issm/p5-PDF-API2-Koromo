use strict;
use Test::More;
use PDF::API2::Koromo;

my $pdf = PDF::API2::Koromo->new;
isa_ok $pdf, 'PDF::API2::Koromo';

done_testing;
__END__
