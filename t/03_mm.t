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
    [ '123mm' ],
) {
    try {
        $pdf->mm( @$args );
        fail 'Should have error.';
    } catch {
        my $msg = shift;
        ok $msg;
    };
}

### ok
for my $v (
    123,
    '+123',
    '-123',
    123.123,
    '+123.123',
    '-123.123',
) {
    try {
        ok is_Int( $pdf->mm($v) );
    } catch {
        my $msg = shift;
        fail 'Should success.';
    };
}

done_testing;
