use strict;
use warnings;
use Test::More;
use PDF::API2::Koromo::Types qw/Color is_Color/;
use Data::Validator;
use t::Util;

for my $v (
    '#000000',
    '#abcdef',
    '#ABCDEF',
) {
    ok is_Color($v), "type of \"$v\" is-a " . Color;
}

for my $v ('', qw/foo bar/) {
    ok ! is_Color($v), "type of \"$v\" is-not-a " . Color;
}

done_testing;
