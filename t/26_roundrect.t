use strict;
use warnings;
use Test::More;
use PDF::API2::Koromo;
use Try::Tiny;
use t::Util;

my $pdf = new_object();

### ng
# mode x y length
for my $param (
    [],
    [ x => 0, y => 0 ],
    [ w => 100, h => 100 ],
    [ x => 0, y => 0, w => 100, h => 100 ],
    [ x => 0, y => 0, r => 10 ],
    [ w => 100, h => 100, r => 10 ],
    [ x => 0, y => 0, w => 0, h => 0, r => 10, action => 'foobar' ],
)  {
    try {
        $pdf->line( @$param );
        fail 'should have error.';
    } catch {
        my $msg = shift;
        ok $msg;
    };
}

### ok
is $pdf->roundrect( x => 0, y => 0, w => 0, h => 0, r => 10 ), 1;
is $pdf->roundrect( x => 0, y => 0, w => 0, h => 0, r => 10, action => 'stroke' ), 1;
is $pdf->roundrect( x => 0, y => 0, w => 0, h => 0, r => 10, action => 'fill' ), 1;
is $pdf->roundrect( x => 0, y => 0, w => 0, h => 0, r => 10, action => 'fillstroke' ), 1;

done_testing;
