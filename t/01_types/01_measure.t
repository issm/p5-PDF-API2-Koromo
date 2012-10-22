use strict;
use warnings;
use Test::More;
use PDF::API2::Koromo::Types qw/Measure is_Measure/;
use Data::Validator;
use t::Util;

for my $v (qw/px mm cm pt/) {
    ok is_Measure($v), "type of \"$v\" is-a " . Measure;
}

for my $v ('', qw/foo bar m/) {
    ok ! is_Measure($v), "type of \"$v\" is-not-a " . Measure;
}

done_testing;
