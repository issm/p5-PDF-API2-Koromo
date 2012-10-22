package PDF::API2::Koromo::Types;
use strict;
use warnings;
use utf8;
use MouseX::Types -declare => [qw/
    Measure
    Unit
    Color
    LineMode
    DrawAction
/];
use MouseX::Types::Mouse qw/Str Int/;

subtype Measure,
    as Str,
    where { /^(px|mm|cm|pt)$/ } ;

subtype Unit,
    as Str,
    where { /^[+-]?\d+(\.\d+)?(px|mm|cm|pt|\%[wW]|\%[hH])?$/ } ;

subtype Color,
    as Str,
    where { /^#[0-9a-f]{6}$/i } ;

subtype LineMode,
    as Str,
    where { /^(h(orizontal)?|v(ertical)?)$/ } ;

enum DrawAction,
    qw/stroke fill fillstroke/ ;

1;
