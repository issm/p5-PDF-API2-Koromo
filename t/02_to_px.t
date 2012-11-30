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

    { arg => '+100', expected => 100 },
    { arg => '+10px' },
    { arg => '+10mm' },
    { arg => '+10cm' },
    { arg => '+10pt' },
    { arg => '+10%w' },
    { arg => '+10%W' },
    { arg => '+10%h' },
    { arg => '+10%H' },

    { arg => '-100', expected => -100 },
    { arg => '-10px' },
    { arg => '-10mm' },
    { arg => '-10cm' },
    { arg => '-10pt' },
    { arg => '-10%w' },
    { arg => '-10%W' },
    { arg => '-10%h' },
    { arg => '-10%H' },

    { arg => 100.123, expected => 100.123 },
    { arg => '10.123px' },
    { arg => '10.123mm' },
    { arg => '10.123cm' },
    { arg => '10.123pt' },
    { arg => '10.123%w' },
    { arg => '10.123%W' },
    { arg => '10.123%h' },
    { arg => '10.123%H' },

    { arg => '+100.123', expected => 100.123 },
    { arg => '+10.123px' },
    { arg => '+10.123mm' },
    { arg => '+10.123cm' },
    { arg => '+10.123pt' },
    { arg => '+10.123%w' },
    { arg => '+10.123%W' },
    { arg => '+10.123%h' },
    { arg => '+10.123%H' },

    { arg => '-100.123', expected => -100.123 },
    { arg => '-10.123px' },
    { arg => '-10.123mm' },
    { arg => '-10.123cm' },
    { arg => '-10.123pt' },
    { arg => '-10.123%w' },
    { arg => '-10.123%W' },
    { arg => '-10.123%h' },
    { arg => '-10.123%H' },
) {
    my $px = $pdf->to_px( $case->{arg} );
    ok is_Int($px), qq{to_px("$case->{arg}") is-a Int};
    is $px, $case->{expected}  if defined $case->{expedted};
}


done_testing;
