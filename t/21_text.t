use strict;
use warnings;
use Test::More;
use PDF::API2::Koromo;
use Try::Tiny;
use t::Util;

my $pdf = new_object(
    ttfont => ttf('Courier New'),
);

### ng
for my $param (
    [],
    [ x => 0 ],
    [ y => 0 ],
    [ x => 0, y => 0 ],
    [ text => 'foobar' ],
    [ x => 0, text => 'foobar' ],
    [ y => 0, text => 'foobar' ],
)  {
    try {
        $pdf->text( @$param );
        fail 'should have error.';
    } catch {
        my $msg = shift;
        ok $msg;
    };
}

### ok
is $pdf->text( x => 0, y => 0, text => 'foobar' ), 1;


done_testing;
