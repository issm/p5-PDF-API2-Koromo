use strict;
use warnings;
use Test::More;
use PDF::API2::Koromo;
use Try::Tiny;
use t::Util;

my $pdf = new_object();

### ng
for my $args (
    [],
    [ 0 ],
    [ undef, 0 ],
)  {
    try {
        $pdf->convert_coordinate( @$args );
        fail 'should have error.';
    } catch {
        my $msg = shift;
        ok $msg;
    };
}

### ok
for my $case (
    { arg => [0, 0] },
) {
    ok $pdf->convert_coordinate( @{ $case->{arg} } );
}


done_testing;
