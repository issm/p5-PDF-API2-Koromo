use strict;
use warnings;
use Test::More;
use PDF::API2::Koromo;
use PDF::API2;
use t::Util;

my $dir = tempdir();

my $pdf1 = new_object( file => "$dir/1.pdf" );
my $pdf2 = new_object( file => "$dir/2.pdf" );
$pdf1->text(x => 0, y => 0, ttfont => ttf('Courier New'), text => 'foobar');
$pdf2->text(x => 0, y => 0, ttfont => ttf('Courier New'), text => 'foobar');
$pdf1->save();
$pdf2->save();

subtest 'param "pdf" isa...' => sub {
    subtest 'Str' => sub {
        my $pdf;

        $pdf = new_object();
        $pdf->importpage( pdf => "$dir/1.pdf" );
        is $pdf->pages, 2;

        $pdf = new_object();
        $pdf->importpage( pdf => "$dir/1.pdf" );
        $pdf->importpage( pdf => "$dir/2.pdf" );
        is $pdf->pages, 3;

        $pdf = new_object();
        $pdf->importpage( pdf => "$dir/1.pdf" );
        $pdf->importpage( pdf => "$dir/2.pdf" );
        $pdf->importpage( pdf => "$dir/2.pdf" );
        is $pdf->pages, 4;
    };

    subtest 'PDF::API2' => sub {
        my $pdf;
        my $pdf1 = PDF::API2->open( "$dir/1.pdf" );
        my $pdf2 = PDF::API2->open( "$dir/2.pdf" );
        isa_ok $pdf1, 'PDF::API2';
        isa_ok $pdf2, 'PDF::API2';

        $pdf = new_object();
        $pdf->importpage( pdf => $pdf1 );
        is $pdf->pages, 2;

        $pdf = new_object();
        $pdf->importpage( pdf => $pdf1 );
        $pdf->importpage( pdf => $pdf2 );
        is $pdf->pages, 3;
    };

    subtest 'PDF::API2::Koromo' => sub {
        my $pdf;
        $pdf1->load( file => "$dir/1.pdf" );
        $pdf2->load( file => "$dir/2.pdf" );

        $pdf = new_object();
        $pdf->importpage( pdf => $pdf1 );
        is $pdf->pages, 2;

        $pdf = new_object();
        $pdf->importpage( pdf => $pdf1 );
        $pdf->importpage( pdf => $pdf2 );
        is $pdf->pages, 3;
     };
};


subtest 'param "into" isa...' => sub {
    subtest 'Int' => sub {
        my $pdf;

        $pdf = new_object();
        $pdf->importpage( pdf => "$dir/1.pdf", into => 1 );
        is $pdf->pages, 2;

        $pdf = new_object();
        $pdf->importpage( pdf => "$dir/1.pdf", into => 1 );
        $pdf->importpage( pdf => "$dir/1.pdf", into => 1 );
        is $pdf->pages, 3;

        $pdf = new_object();
        $pdf->importpage( pdf => "$dir/1.pdf", into => 1 );
        $pdf->importpage( pdf => "$dir/2.pdf", into => 1 );
        is $pdf->pages, 3;
    };

    subtest 'PDF::API2::Page' => sub {
        my $pdf;

        $pdf = new_object();
        $pdf->importpage( pdf => "$dir/1.pdf", into => $pdf->openpage( page => 1 ) );
        is $pdf->pages, 1;

        $pdf = new_object();
        $pdf->importpage( pdf => "$dir/1.pdf", into => $pdf->openpage( page => 1 ) );
        $pdf->importpage( pdf => "$dir/1.pdf", into => $pdf->openpage( page => 1 ) );
        is $pdf->pages, 1;

        $pdf = new_object();
        $pdf->importpage( pdf => "$dir/1.pdf", into => $pdf->openpage( page => 1 ) );
        $pdf->importpage( pdf => "$dir/2.pdf", into => $pdf->openpage( page => 1 ) );
        is $pdf->pages, 1;
    };

    subtest 'mixed' => sub {
        my $pdf;

        $pdf = new_object();
        $pdf->importpage( pdf => "$dir/1.pdf", into => 1 );
        $pdf->importpage( pdf => "$dir/2.pdf", into => $pdf->openpage( page => 1 ) );
        is $pdf->pages, 2;

        $pdf = new_object();
        $pdf->importpage( pdf => "$dir/1.pdf", into => $pdf->openpage( page => 1 ) );
        $pdf->importpage( pdf => "$dir/2.pdf", into => 1 );
        is $pdf->pages, 2;
    };
};


done_testing;
