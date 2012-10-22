use strict;
use warnings;
use Test::More;
use MouseX::Types::Mouse qw/is_Int/;
use PDF::API2::Koromo;
use Try::Tiny;
use t::Util;

my $pdf = new_object();

### ng
for my $args (
    [],
)  {
    try {
        $pdf->to_px( @$args );
        fail 'should have error.';
    } catch {
        my $msg = shift;
        ok $msg;
    };
}

### ok
for my $case (
    { arg => 100, expected => 100 },
    { arg => '10px' },
    { arg => '10mm' },
    { arg => '10cm' },
    { arg => '10pt' },
    { arg => '10%w' },
    { arg => '10%W' },
    { arg => '10%h' },
    { arg => '10%H' },
) {
    my $px = $pdf->to_px( $case->{arg} );
    ok is_Int($px);
    is $px, $case->{expected}  if defined $case->{expedted};
}


done_testing;
