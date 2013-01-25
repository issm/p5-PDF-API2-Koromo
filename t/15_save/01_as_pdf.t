use strict;
use warnings;
use Test::More;
use PDF::API2::Koromo;
use t::Util;

my $dir = tempdir();
my $pdf;

$pdf = new_object();
$pdf->save( as => "$dir/1.pdf" );
ok -f "$dir/1.pdf", 'saved pdf should exist';

$pdf = new_object();
$pdf->save( file => "$dir/2.pdf" );
ok -f "$dir/2.pdf", 'saved pdf should exist';

done_testing;
