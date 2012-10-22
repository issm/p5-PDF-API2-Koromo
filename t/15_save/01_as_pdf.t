use strict;
use warnings;
use Test::More;
use PDF::API2::Koromo;
use t::Util;

my $dir = tempdir();

my $pdf = new_object();
$pdf->save( as => "$dir/1.pdf" );
ok -f "$dir/1.pdf", 'saved pdf should exist';

done_testing;
