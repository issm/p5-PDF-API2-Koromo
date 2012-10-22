use strict;
use warnings;
use Test::More;
use PDF::API2::Koromo;
use t::Util;

eval { require Image::Magick };
if ( $@ ) {
    ok warn 'Image::Magick is unavailable, skip this test.';
    done_testing;
    exit 0;
}

my $dir = tempdir();

my $pdf = new_object();
$pdf->save(
    as_image => {
        file => "$dir/1.jpg",
    },
);
ok -f "$dir/1.jpg", 'saved image should exist';
ok ! -f "$dir/1.jpg.pdf", 'pdf should not exist';

done_testing;
