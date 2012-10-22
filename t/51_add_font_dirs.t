use strict;
use warnings;
use Test::More;
use MouseX::Types::Mouse qw/is_Int/;
use PDF::API2::Koromo;
use Try::Tiny;
use t::Util;

my $pdf  = new_object();
my $pdf1 = new_object();
my @font_dirs_default = PDF::API2::addFontDirs();

is_deeply [ $pdf->add_font_dirs() ], \@font_dirs_default;

is_deeply (
    [ $pdf->add_font_dirs(qw/foo bar/) ],
    [ @font_dirs_default, qw/foo bar/ ],
);
is_deeply (
    [ $pdf->add_font_dirs(qw/baz/) ],
    [ @font_dirs_default, qw/foo bar baz/ ],
);

is_deeply (
    [ PDF::API2::Koromo->add_font_dirs(qw/hoge fuga/) ],
    [ @font_dirs_default, qw/foo bar baz hoge fuga/ ],
);

is_deeply (
    [ PDF::API2::Koromo::add_font_dirs(qw/piyo/) ],
    [ @font_dirs_default, qw/foo bar baz hoge fuga piyo/ ],
);

is_deeply (
    [ $pdf1->add_font_dirs(qw/a b c/) ],
    [ @font_dirs_default, qw/foo bar baz hoge fuga piyo a b c/ ],
);

done_testing;
