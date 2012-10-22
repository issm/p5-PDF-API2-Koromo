package t::Util;
use strict;
use warnings;
use File::Basename ();
use File::Spec ();
use File::Temp ();
use File::Path ();
use Data::Validator;
use PDF::API2::Koromo;

my @subs_import = qw/
    basedir
    tempdir
    new_object
    ttf
/;

my @font_dirs = qw{
    /Library/Fonts
    /usr/share/fonts
    /usr/local/share/fonts
    c:/windows/fonts
    c:/winnt/fonts
};

sub import {
    my $class = shift;
    my $caller = caller;
    for my $f ( @subs_import ) {
        no strict 'refs';
        *{"$caller\::$f"} = \&$f;
    }
}

sub basedir { File::Basename::dirname(__FILE__) }

sub tempdir {
    my ($keep) = @_;
    my $dir = File::Spec->catdir( basedir(), 'tmp' );
    File::Path::mkpath $dir  unless -d $dir;
    File::Temp::tempdir(
        DIR     => File::Spec->catdir( basedir(), 'tmp' ),
        CLEANUP => $keep ? 0 : 1,
    );
}

sub new_object { PDF::API2::Koromo->new(@_) }

sub ttf {
    my ($name) = @_;
    $name .= '.ttf'  if $name !~ /\.ttf$/;
    my ($f) = grep { -f $_ } map { "$_/$name" } @font_dirs;
    return $f;
}


1;
