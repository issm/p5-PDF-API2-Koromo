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
    as       => "$dir/pdf.pdf",
    as_image => {
        file => "$dir/img.jpg",
    },
);
ok -f "$dir/pdf.pdf", 'saved pdf should exist';
ok -f "$dir/img.jpg", 'saved image should exist';

done_testing;
