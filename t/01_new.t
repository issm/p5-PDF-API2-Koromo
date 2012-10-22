use strict;
use Test::More;
use PDF::API2::Koromo;
use t::Util;

my $pdf = new_object();
isa_ok $pdf, 'PDF::API2::Koromo';

done_testing;
__END__
