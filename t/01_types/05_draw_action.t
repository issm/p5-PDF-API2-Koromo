use strict;
use warnings;
use Test::More;
use PDF::API2::Koromo::Types qw/DrawAction is_DrawAction/;
use Data::Validator;
use t::Util;

for my $v (qw/stroke fill fillstroke/) {
    ok is_DrawAction($v), "type of \"$v\" is-a " . DrawAction;
}

for my $v ('', qw/foo bar/) {
    ok ! is_DrawAction($v), "type of \"$v\" is-not-a " . DrawAction;
}

done_testing;
