use strict;
use warnings;
use Test::More;
use PDF::API2::Koromo::Types qw/LineMode is_LineMode/;
use Data::Validator;
use t::Util;

for my $v (qw/h horizontal v vertical/) {
    ok is_LineMode($v), "type of \"$v\" is-a " . LineMode;
}

for my $v ('', qw/foo bar/) {
    ok ! is_LineMode($v), "type of \"$v\" is-not-a " . LineMode;
}

done_testing;
