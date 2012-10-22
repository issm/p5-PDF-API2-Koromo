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
    [ x => 0 ],
    [ y => 0 ],
    [ x => 0, y => 0 ],
    [ length => 0 ],
    [ length => 0, x => 0 ],
    [ length => 0, y => 0 ],
)  {
    try {
        $pdf->vline( @$param );
        fail 'should have error.';
    } catch {
        my $msg = shift;
        ok $msg;
    };
}

### ok
is $pdf->vline( x => 0, y => 0, length => 0 ), 1;

done_testing;
