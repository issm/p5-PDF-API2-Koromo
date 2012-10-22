use strict;
use warnings;
use Test::More;
use PDF::API2::Koromo;
use Try::Tiny;
use t::Util;

my $pdf = new_object(
    ttfont => ttf('Courier New'),
);

my $img_url = 'http://si0.twimg.com/profile_images/1158606012/issm-20101103-400sq.jpg';

### ng
for my $param (
    [],
    [ x => 0 ],
    [ y => 0 ],
    [ x => 0, y => 0 ],
    [ file => 'foobar' ],
    [ x => 0, file => 'foobar' ],
    [ y => 0, file => 'foobar' ],

    [ x => 0, y => 0, file => 'foobar' ],
    [ x => 0, y => 0, file => basedir() . '/img/sample.bmp' ],
    [ x => 0, y => 0, file => basedir() . '/img/sample.png', url => $img_url ],

    [ x => 0, y => 0, file => basedir() . '/img/sample.png', width => 100, scale => 1 ],
    [ x => 0, y => 0, file => basedir() . '/img/sample.png', height => 100, scale => 1 ],
    [ x => 0, y => 0, file => basedir() . '/img/sample.png', height => 100, keep_aspect => 1, scale => 1 ],
    [ x => 0, y => 0, file => basedir() . '/img/sample.png', width => 100, height => 100, scale => 1 ],

    [ x => 0, y => 0, url => $img_url, width => 100, scale => 1 ],
    [ x => 0, y => 0, url => $img_url, height => 100, scale => 1 ],
    [ x => 0, y => 0, url => $img_url, height => 100, keep_aspect => 1, scale => 1 ],
    [ x => 0, y => 0, url => $img_url, width => 100, height => 100, scale => 1 ],
)  {
    try {
        $pdf->image( @$param );
        fail 'should have error.';
    } catch {
        my $msg = shift;
        ok $msg;
    };
}

### ok
is $pdf->image( x => 0, y => 0, file => basedir() . '/img/sample.png' ), 1;
is $pdf->image( x => 0, y => 0, file => basedir() . '/img/sample.jpg' ), 1;
is $pdf->image( x => 0, y => 0, file => basedir() . '/img/sample.tiff' ), 1;
is $pdf->image( x => 0, y => 0, url => $img_url ), 1;

is $pdf->image( x => '10mm', y => 0, file => basedir() . '/img/sample.png' ), 1;
is $pdf->image( x => '10mm', y => '10mm', file => basedir() . '/img/sample.png' ), 1;
is $pdf->image( x => '10mm', y => '10mm', width => '10mm', file => basedir() . '/img/sample.png' ), 1;
is $pdf->image( x => '10mm', y => '10mm', width => '10mm', height => '10mm', file => basedir() . '/img/sample.png' ), 1;

done_testing;
