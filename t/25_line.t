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
    [ mode => 'h' ],
    [ mode => 'h', x => 0 ],
    [ mode => 'h', y => 0 ],
    [ mode => 'h', x => 0, y => 0 ],
    [ x => 0 ],
    [ y => 0 ],
    [ x => 0, y => 0 ],
    [ x => 0, y => 0, length => 0 ],
    [ mode => 'h', length => 0 ],
    [ mode => 'h', length => 0, x => 0 ],
    [ mode => 'h', length => 0, y => 0 ],
    [ mode => 'foobar', x => 0, y => 0, length => 0 ],
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
is $pdf->line( mode => 'h',          x => 0, y => 0, length => 0 ), 1;
is $pdf->line( mode => 'horizontal', x => 0, y => 0, length => 0 ), 1;
is $pdf->line( mode => 'v',          x => 0, y => 0, length => 0 ), 1;
is $pdf->line( mode => 'vertical',   x => 0, y => 0, length => 0 ), 1;


done_testing;
