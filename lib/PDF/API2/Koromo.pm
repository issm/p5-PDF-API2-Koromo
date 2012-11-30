#--------------------------------------------------------------------------------
#
#  座標系：水平右方向を x，垂直下方向を y とする．また，左上を (x, y) = (0, 0) とする

#  使用可能な単位
#    px:     ピクセル
#    mm:     ミリメートル
#    cm:     センチメートル
#    %w, %W: ページ幅に対する割合
#    %h, %H: ページ高さに対する割合
#
#--------------------------------------------------------------------------------
package PDF::API2::Koromo;
use 5.008008;
use strict;
use warnings;
use utf8;
use Data::Validator;
use PDF::API2;
use PDF::API2::Lite;
use Image::Size ();
# use Image::Magick;
use Encode;
use Carp;
use Try::Tiny;
use PDF::API2::Koromo::Types qw/Measure Unit Color LineMode DrawAction/;
use MouseX::Types::Mouse qw/Bool Str Num Int is_Int Object/;
use Class::Accessor::Lite (
    new => 0,
    rw  => [qw/
        _PDF _DPI _MEASURE
        _MM2PX_RATE _PT2PX_RATE
        _WIDTH _HEIGHT
        _FONT _FONT_SIZE _LINE_HEIGHT
        _ROTATE _COLOR_STROKE _COLOR_FILL _LINE_WIDTH

        measure dpi width height
        ttfont fontsize line_height
        strokecolor fillcolor linewidth
        file

        _ua _tmpfiles
    /],
);
use constant +{
    DEFAULT_MEASURE      => 'px',      # 単位
    DEFAULT_DPI          => 300,       # 解像度
    DEFAULT_PAGE_WIDTH   => '210mm',   # ページ幅 [px]    デフォルトは A4 （縦）の幅
    DEFAULT_PAGE_HEIGHT  => '297mm',   # ページ高さ [px]  デフォルトは A4 （縦）の高さ
    DEFAULT_FONT_SIZE    => 14,        # フォントサイズ
    DEFAULT_LINE_HEIGHT  => '100%',    # 行高さ
    DEFAULT_ROTATE       => 0,         # 配置オブジェクトの回転角度
    DEFAULT_COLOR_STROKE => '#000000', # ストロークの色
    DEFAULT_COLOR_FILL   => '#ffffff', # 塗りつぶしの色
    DEFAULT_LINE_WIDTH   => 1,         # 線の幅
};

our $VERSION = '0.00_05';


my $RE = {
    NL               => qr/(?:\x0d?\x0a|\x0d)/x,     # 改行文字の正規表現: CR+LF, LF, CR
    CHAR_TATE_ROTATE => qr/[ー（）｛｝「」『』\(\)]/x,  #
    CHAR_TATE_SLIDE  => qr/[、。，．]/x,              #
    #CHAR_HANKAKU     => qr/[\x20-\x7E\xA1-\xDF]/,    # 半角カナを含む
    CHAR_HANKAKU     => qr/[\x20-\x7E]/x,            # 半角カナを含まない
    LENGTH           => qr/^\s* ([\+\-]? \d+(?:\.\d+)? ) \s* (\D+)? \s*$/x,  # （単位つき）長さ
};


my $MAP_YOKO2TATE = {
    #'、' => "\x{2661}",
};




#
#  コンストラクタ
#
#  @param   ?measure      scalar  使用単位
#  @param   ?dpi          scalar  解像度
#  @param   ?width        scalar  ページ幅
#  @param   ?height       scalar  ページ高さ
#  @param   ?ttfont       scalar  TrueTypeフォントファイル名
#  @param   ?fontsize     scalar  フォントサイズ
#  @param   ?line_height  scalar  行の高さ
#  @param   ?strokecolor  scalar  前景色
#  @param   ?fillcolor    scalar  背景色
#  @param   ?linewidth    scalar  線の幅
#
sub new {
    my ($class, %params) = @_;
    my $self = bless {}, $class;

    my $v = Data::Validator->new(
        measure     => { isa => Measure, default => DEFAULT_MEASURE },
        dpi         => { isa => Int, default => DEFAULT_DPI },
        width       => { isa => Unit, default => DEFAULT_PAGE_WIDTH },
        height      => { isa => Unit, default => DEFAULT_PAGE_HEIGHT },
        ttfont      => { isa => Str, optional => 1 },
        fontsize    => { isa => Unit, default => DEFAULT_FONT_SIZE },
        line_height => { isa => Str, default => DEFAULT_LINE_HEIGHT },
        strokecolor => { isa => Color, default => DEFAULT_COLOR_STROKE },
        fillcolor   => { isa => Color, default => DEFAULT_COLOR_FILL },
        linewidth   => { isa => Str, default => DEFAULT_LINE_WIDTH },
        file        => { isa => Str, optional => 1 },
    );
    %params = %{ $v->validate(%params) };

    for my $meth (qw/
        measure dpi width height
        ttfont fontsize line_height
        strokecolor fillcolor linewidth
        file
    /) {
        $self->$meth( $params{$meth} );
    }

    return $self->_init(%params);
}

#
#  初期化
#
sub _init {
    my ($self, %params) = @_;
    my $PDF;
    my %api2_params;
    $api2_params{-file} = $params{file}  if exists $params{file};

    $self->_DPI( $self->dpi );
    $self->_MEASURE( $self->measure );
    $self->_MM2PX_RATE( $self->_DPI / 25.4 );
    $self->_PT2PX_RATE( $self->_DPI / 72 );
    $self->_WIDTH( $self->to_px( $self->width ) );
    $self->_HEIGHT( $self->to_px( $self->height ) );

    $self->_PDF( $PDF = PDF::API2::Lite->new(%api2_params) );
    $self->page;

    $self->_FONT( $PDF->ttfont( $self->ttfont ) )  if defined $self->ttfont;

    $self->_FONT_SIZE( $self->to_px( $self->fontsize ) );
    $self->_LINE_HEIGHT( $self->line_height );
    $self->_COLOR_STROKE( $self->strokecolor );
    $self->_COLOR_FILL( $self->fillcolor );
    $self->_LINE_WIDTH( $self->linewidth );

    $PDF->strokecolor($self->_COLOR_STROKE);
    $PDF->fillcolor($self->_COLOR_FILL);

    $self->_tmpfiles([]);

    return $self;
}

sub DESTROY {
    my $self = shift;
    for my $f ( @{$self->_tmpfiles} ) {
        unlink $f;
    }
}


#
#  単位付き文字列を [px] に変換する
#
#  @param   scalar
#
#  @return  scalar  ピクセル数
#
sub to_px {
    my ($self, @args) = @_;
    my $v = Data::Validator->new(
        length => { isa => Unit },
    )->with('StrictSequenced');
    my %params = %{ $v->validate(@args) };

    my $length = $params{length};
    my ($val, $measure) = $length =~ $RE->{LENGTH};
    $measure = $self->_MEASURE  unless defined $measure;
    return 0  unless defined $val;

    my $ret = 0;

    # mm
    if    (lc $measure eq 'mm')    { $ret = $self->mm($val); }
    # cm
    elsif (lc $measure eq 'cm')    { $ret = $self->mm($val * 10); }
    # pt
    elsif (lc $measure eq 'pt')    { $ret = $self->pt($val); }
    # %w, %W
    elsif (lc $measure =~ /^\%w$/) { $ret = int($self->_WIDTH * $val / 100); }
    # %h, %H
    elsif (lc $measure =~ /^\%h$/) { $ret = int($self->_HEIGHT * $val / 100); }
    # その他もしくは px
    else                           { $ret = int($val); }

    return $ret;
}


#
#  [mm] を [px] に変換する
#
#  @param   scalar
#
#  @return  scalar  ピクセル数
#
sub mm {
    my ($self, @args) = @_;
    my $v = Data::Validator->new( mm => { isa => Num } )->with('StrictSequenced');
    my %params = %{ $v->validate(@args) };
    return int( $params{mm} * $self->_MM2PX_RATE );
};

#
#  [pt] を [px] に変換する
#
sub pt {
    my ($self, @args) = @_;
    my $v = Data::Validator->new( pt => { isa => Num } )->with('StrictSequenced');
    my %params = %{ $v->validate(@args) };
    return int( $params{pt} * $self->_PT2PX_RATE );
}

#
#  左上を原点，水平右方向をx，垂直下方向をy とした座標系での座標をから
#  左下を原点，水平右方向をx，垂直上方向をy とした座標系での座標を取得する
#
#  @param   scalar  x座標
#  @param   scalar  y座標
#
#  @return  ( scalar, scalar )  変換後の座標
#
sub convert_coordinate {
    my ($self, @args) = @_;
    my $v = Data::Validator->new(
        x => { isa => Unit },
        y => { isa => Unit },
    )->with('StrictSequenced');
    my %params = %{ $v->validate(@args) };

    my ($x, $y) = @params{qw/x y/};

    $x .= 'w'  if $x =~ m{\%\s*$};
    $y .= 'h'  if $y =~ m{\%\s*$};

    return (
        $self->to_px($x),
        $self->_HEIGHT - $self->to_px($y),
    );
}



#
#  新規にページを作成する
#
sub page {
    my $self = shift;
    $self->_PDF->page($self->_WIDTH, $self->_HEIGHT);
}


#
#  指定したページを開く（？）
#
sub openpage {
    my $self = shift;
    my $param = +{@_};
    $self->_PDF->{api}->openpage($param->{page} || -1);
}

#
#  指定したページを指定した角度で回転させる
#
sub rotatepage {
    my $self = shift;
    my $param = +{@_};
    my $page   = $param->{page} || -1;
    my $degree = $param->{degree} || $param->{deg} || 0;
    $self->openpage(page => $page)->rotate($degree);
}


#
#  指定したPDFを取り込む
#
sub importpage {
    my ($self, %params) = @_;
    my $v = Data::Validator->new(
        pdf  => { isa => Str|Object },
        page => { isa => Int|Object, default => 1 },
        into => { isa => Int|Object, default => 1 },
    );
    %params = %{ $v->validate(\%params) };

    my ($pdf, $page, $into);

    ### pdf
    my $ref_pdf = ref $params{pdf};
    if ( $ref_pdf eq '' ) {
        $pdf = PDF::API2->open($params{pdf});
    }
    elsif ( $ref_pdf eq __PACKAGE__ ) {
        $pdf = $self->_PDF->{api};
    }
    # elsif ( $ref_pdf eq 'PDF::API2::Lite' ) {
    # }
    else {
        $pdf = $params{pdf};
    }

    ### page
    if ( is_Int($params{page}) ) {
        $page = $pdf->openpage($params{page});
        # xxx: ここで openpage すると $page->{' fixed'} == 0 となってしまうので，1にセットする
        # ref($params{page}) eq 'PDF::API2::Page' のとき，その ->{' fixed'} は 1 となっている．why?
        $page->{' fixed'} = 1;
    }
    else {
        $page = $params{page};
    }

    ### into
    $into = $params{into};

    $self->_PDF->{api}->importpage( $pdf, $page, $into );
}



#
# NOT IMPLEMENTED!
#
sub load {
    my $self = shift;
    my $param = +{@_};
    my $file = $param->{file};
    try {
        $self->_PDF->{api} = PDF::API2->open($file);
    }
    catch {
        carp shift;
        $self->_PDF->{api} = undef;
    }
}



#
#  PDFを保存する
#  拡張子が画像系の場合，画像に変換して保存する
#
#  @param    file        scalar  保存先
#  @param   ?image       scalar  画像としての保存先      (deprecated)
#  @param   ?scale       scalar  画像保存時の倍率        (deprecated)
#  @param   ?image_only  scalar  画像のみの保存かどうか  (deprecated)
#
#  @param   ?image       hashref
#              file      scalar
#             ?only      scalar
#             ?width     scalar
#             ?square    scalar  格納する正方形の1辺の長さ
#             ?height    scalar
#             ?scale     scalar
#              
#

#  @param    scalar  保存先
#  @param   ?scalar  倍率（画像保存時）
#
#  @return   scalar  保存できたら 1，失敗したら 0．．．のつもり
#
sub save {
    my ($self, %params) = @_;
    my $v = Data::Validator->new(
        as       => { isa => Str,     default => undef },
        file     => { isa => Str,     default => undef },  # synonym of 'as'
        as_image => { isa => 'HashRef', default => undef },
        scale    => { isa => 'Num',     default => 1 },
    );
    %params = %{ $v->validate(%params) };

    my $file     = exists $params{as} ? $params{as} : $params{file};
    my $as_image = $params{as_image};
    my $scale    = $params{scale};

    if ( ! defined $file  &&  defined $as_image ) {
        $file = "$as_image->{file}.pdf";
        $as_image->{only} = 1;
    }

    return 0  unless $self->_PDF->{api}->{pdf};  # 一度saveを呼び出すと，この値（？）は undef される． ← PDF::API2::out_file あたりを参照

    ### PDF を保存
    $self->_PDF->saveas( $file )  ||  die $!;

    ### 画像として保存（新タイプ）
    if( defined $as_image  &&  ref $as_image eq 'HASH' ) {
        if( $as_image->{file} =~ m{\. ( jpe?g | png | gif ) $}ix ) {
            require Image::Magick;

            my $img = Image::Magick->new;
            $img->Read( filename => $file );

            # 幅，高さ指定時
            if( $as_image->{width}  ||  $as_image->{height} ) {
                $img->Resize(
                    width  => $self->to_px( $as_image->{width}  ||  $as_image->{height} ),
                    height => $self->to_px( $as_image->{height}  ||  $as_image->{width} ),
                );
            }
            # 格納正方形指定時
            elsif( $as_image->{square} ) {
                my $geometry = sprintf '%dx%d', $self->to_px( $as_image->{square} ), $self->to_px( $as_image->{square} );
                $img->Resize( geometry => $geometry );
            }
            # 倍率指定時
            elsif( defined $as_image->{scale} ) {
                $img->Resize(
                    width  => $self->_WIDTH  * $as_image->{scale},
                    height => $self->_HEIGHT * $as_image->{scale},
                );
            }

            # 属性の設定
            # $img->Set(
            #     density => sprintf( '%dx%d', $self->_DPI, $self->_DPI ),
            #     units   => 'PixelsPerInch',
            # );
            # 出力
            $img->Write( filename => $as_image->{file} );
            undef $img;
        }

        unlink $file  if $as_image->{only};  # 「画像のみ保存」指定の場合，保存したPDFを削除する
    }
    ### 画像として保存（旧タイプ，deprecated）
    elsif( defined $as_image  &&  ref $as_image eq '' ) {
        if( $as_image =~ m{\. ( jpe?g | png | gif ) $}ix ) {
            require Image::Magick;

            my $img = Image::Magick->new;
            $img->Read( $file );
            $img->Resize( width => $self->{PAGE_WIDTH} * $scale, height => $self->{PAGE_HEIGHT} * $scale );
            # 属性の設定
            $img->Set(
                density => sprintf( '%dx%d', $self->{DPI}, $self->{DPI} ),
                #density => sprintf( '%dx%d', $self->{PAGE_WIDTH}, $self->{PAGE_HEIGHT} ),
                units   => 'PixelsPerInch',
            );
            # 出力
            $img->Write( filename => $as_image );
            undef $img;
        }

        unlink $file  if $as_image->{only};  # 「画像のみ保存」指定の場合，保存したPDFを削除する
    }

    1;
}



#
#  指定した情報でテキストを描画する
#
#  指定する座標
#    横書きの場合: ボックスの左上の座標
#    縦書きの場合: ボックスの右上の座標
#
#  @param    x            scalar
#  @param    y            scalar
#  @param    text         scalar
#  @param   ?w            scalar      # テキストボックスの幅
#  @param   ?h            scalar      # テキストボックスの高さ
#  @param   ?tate         scalar_flg  # 縦書きフラグ
#  @param   ?ttfont       scalar      # TrueTypeフォントファイル
#  @param   ?fontsize     scalar      # フォントサイズ
#  @param   ?size         scalar      # フォントサイズ．パラメータ fontsize のシノニム
#  @param   ?line_height  scalar      # 行高さ
#  @param   ?rotate       scalar      # 回転角度
#  @param   ?color        scalar      # 色
#  @param   ?debug        scalar_flg  # デバッグフラグ
#
#  @return
#
sub text {
    #my $self = shift;
    my ($self, %params) = @_;

    my $v = Data::Validator->new(
        x           => { isa => Unit },
        y           => { isa => Unit },
        text        => { isa => Str },
        w           => { isa => Unit, optional => 1 },
        h           => { isa => Unit, optional => 1 },
        tate        => { isa => Bool, default => 0 },
        ttfont      => { isa => Str, default => $self->ttfont },
        fontsize    => { isa => Unit, default => 0 },  # synonym of size
        size        => { isa => Unit, default => $self->fontsize },
        line_height => { isa => Str, default => $self->_LINE_HEIGHT },
        rotate      => { isa => Num, default => $self->_ROTATE },
        color       => { isa => Color, default => $self->_COLOR_FILL },
        debug       => { isa => Bool, default => 0 },
    );
    %params = %{ $v->validate(%params) };

    my $PDF = $self->_PDF;

    my $x           = $params{x};
    my $y           = $params{y};
    my $text        = $params{text};
    my $w           = $params{w};
    my $h           = $params{h};
    my $tate        = $params{tate};
    my $ttfont      = $params{ttfont};
    my $fontsize    = $self->to_px( $params{fontsize} || $params{size} );
    my $line_height = $params{line_height};  # ここではまだ to_px しない
    my $rotate      = $params{rotate};
    my $color       = $params{color};
    my $debug       = $params{debug};
    my $font        = defined $ttfont ? $PDF->ttfont($ttfont) : $self->_FONT;

    die 'Font is not set.'  unless defined $font;

    ($x, $y) = $self->convert_coordinate($x, $y);

    $w = defined $w ? $self->to_px($w) : $self->_WIDTH - $self->to_px($x);
    $h = defined $h ? $self->to_px($h) : $self->_HEIGHT - $self->to_px($y);

    $PDF->fillcolor( $color );

    {
        local $@;
        eval {
            $text = decode( 'utf-8', $text );
        }
    }

    # 行高さ
    if( $line_height =~ m{^\s*(\d+(\.\d+)?)\%\s*$} ) {
        my $val = $1;
        $line_height = int( $fontsize * $val / 100 );
    }
    else { $line_height = $self->to_px( $line_height ); }

    #
    #  縦書きモード
    #
    if( $tate ) {
        my $l = 0;
        $x -= $fontsize;  # 最初の行のx座標
        $y -= $fontsize;

        $text =~ s{$RE->{NL}}{\x0a}g;  # 改行をLFに統一
        for my $line ( split m{\x0a}, $text ) {  # 改行ごとに区切って処理
            #my $x_ = $x - $fontsize * $l++;
            my $x_ = $x - $line_height * $l++;
            my $c = 0;
            for my $char ( split '', $line ) {
                my $y_ = $y - $fontsize * $c++;

                if( $MAP_YOKO2TATE->{$char} ) {
                    $PDF->print( $font, $fontsize, $x_, $y_, $rotate, 0, $MAP_YOKO2TATE->{$char} );
                }
                elsif( $char =~ $RE->{CHAR_TATE_ROTATE} ) {
                    $PDF->print( $font, $fontsize, $x_, $y_ + $fontsize, $rotate - 90, 0, $char );
                }
                elsif( $char =~ $RE->{CHAR_TATE_SLIDE} ) {
                    $PDF->print( $font, $fontsize, $x_ + int( $fontsize * .7 ), $y_ + int( $fontsize * .7 ), $rotate, 0, $char );
                }
                else {
                    $PDF->print( $font, $fontsize, $x_, $y_, $rotate, 0, $char );
                }
            }
        }
    }
    #
    #  横書きモード
    #
    else {
        # テキストボックスからはみ出る部分に \x0a を挿入する
        if( 1 ) {
            my @tmp;
            $text =~ s{$RE->{NL}}{\x0a}g; # 改行をLFに統一
            for my $line ( split m{\x0a}, $text ) {  # 改行ごとに区切って処理
                my $cursor = 0;
                my $n_char = length $line;  # 文字数
                my $n_char_per_row = int( $w / $fontsize );  # 行内文字数

                my $buff_tmp = '';
                my $n_hankaku = 0;  # 文字列の「半角」数（全角は2でカウントする）
                # v 空行の場合，$n_char == 0
                if ($n_char == 0) {
                    push @tmp, '';
                    $buff_tmp = '';
                    $n_hankaku = 0;
                }
                # v 空行でない場合（このブロックは，空行の場合自ずと無視されるべき）
                for( my $i = 0; $i < $n_char; $cursor++, $i++ ) {
                    my $char = substr( $line, $cursor, 1 );  # 1文字抜き出す
                    $n_hankaku += $char =~ $RE->{CHAR_HANKAKU}  ?  1  :  2;

                    $buff_tmp .= $char;

                    # 行内文字数を超えた，もしくは次の文字がない
                    # -1 するのはハミ出し対策
                    if( $n_hankaku >= $n_char_per_row * 2 - 1  ||  substr( $line, $cursor + 1, 1 ) !~ m{.}  ) {
                        push @tmp, $buff_tmp;
                        $buff_tmp = '';
                        $n_hankaku = 0;
                        next;
                    }
                }
            }
            $text = join "\x0a", @tmp;
        }

        my $l = 0;
        $y -= $fontsize;  # 最初の行のy座標

        $text =~ s{$RE->{NL}}{\x0a}g;  # 改行をLFに統一
        for my $line ( split m{\x0a}, $text ) {  # 改行ごとに区切って処理
            #my $y_ = $y - $fontsize * $l++;
            my $y_ = $y - $line_height * $l++;

            my $x_ = $x;
            for my $char ( split '', $line ) {
                unless( $debug ) {
                    $PDF->print( $font, $fontsize, int $x_, int $y_, $rotate, 0, $char );
                }
                else {
                    my $line_ = sprintf '%2d: (%3d,%3d): %s', $l, int $x, int $y_, $line;
                    $PDF->print( $font, $fontsize, int $x_, int $y_, $rotate, 0, $line_ );
                }
                $x_ += $fontsize / ( $char =~ $RE->{CHAR_HANKAKU}  ?  2 : 1 );
            }
        }
    }

    1;
}



#
#  指定したファイル，情報で画像を配置する
#
#  指定する座標：画像の左上の座標とする
#
#  @param    x         scalar
#  @param    y         scalar
#  @param    file      scalar
#  @param   ?width     scalar      # 幅指定
#  @param   ?height    scalar      # 高さ指定
#  @param   ?scale     scalar      # 倍率
#  @param   ?rotate    scalar      # 回転角度
#  @param   ?debug     scalar_flg  # デバッグフラグ
#
#  @return
#
sub image {
    my ($self, %params) = @_;
    my $v = Data::Validator->new(
        x           => { isa => Unit },
        y           => { isa => Unit },
        file        => { isa => Str, xor => 'url' },
        url         => { isa => Str, xor => 'file' },
        width       => { isa => Unit, optional => 1, xor => 'scale' },
        height      => { isa => Unit, optional => 1, xor => 'scale' },
        keep_aspect => { isa => Bool, optional => 1, xor => 'scale' },
        scale       => { isa => Num, optional => 1, xor => [qw/width height keep_aspect/], },
        rotate      => { isa => Num, default => 0 },
        debug       => { isa => Bool, default => 0 },
    );
    %params = %{ $v->validate(%params) };

    my $PDF = $self->_PDF;

    my $x           = $params{x};
    my $y           = $params{y};
    my $file        = $params{file};
    my $url         = $params{url};
    my $width       = $params{width};
    my $height      = $params{height};
    my $scale       = $params{scale};
    my $keep_aspect = $params{keep_aspect};
    my $rotate      = $params{rotate};
    my $debug       = $params{debug};

    my ($w, $h, $type, $img);

    ### 画像URL指定時，その画像を一時ファイルとして保存し，それを $file として扱う
    if ( defined $url ) {
        require Furl;
        require File::Temp;

        my $fh;
        ($fh, $file) = File::Temp::tempfile( UNLINK => 0 );  # remove on DESCTROY

        my $ua = $self->_ua || Furl->new(
            agent   => "PDF::API2::Koromo/$VERSION",
            timeout => 10,
        );
        my $res = $ua->get($url);
        if ( $res->code != 200 ) {
            die 'Fetching image has failed: ' . $res->status_line;
        }

        $fh->print( $res->content );
        push @{ $self->_tmpfiles }, $file;
    }

    -f $file  or  die 'Image file does not exist: ' . $file;

    ($w, $h, $type) = Image::Size::imgsize($file);
    die 'Unavailable image type: ' . $type  if $type !~ /^(jpg|png|tif)$/i;

    # JPG
    if (uc $type eq 'JPG')    { $img = $PDF->image_jpeg($file) }
    # PNG
    elsif (uc $type eq 'PNG') { $img = $PDF->image_png($file) }
    # TIF
    elsif (uc $type eq 'TIF') { $img = $PDF->image_tiff($file) }

    if ( defined $scale ) {
        $width  = $w * $scale;
        $height = $h * $scale;
    }
    elsif ( defined $width  &&  defined $height ) {
        $width  = $self->to_px($width);
        $height = $self->to_px($height);
    }
    elsif ( defined $width  &&  ! defined $height ) {
        my $r = $h / $w;
        $width = $self->to_px($width);
        $height = $keep_aspect ? $width * $r : $h;
    }
    elsif ( ! defined $width  &&  defined $height ) {
        my $r = $w / $h;
        $height = $self->to_px($height);
        $width = $keep_aspect ? $height * $r : $w;
    }
    $width  = $w  unless defined $width;
    $height = $h  unless defined $height;

    ($x, $y) = $self->convert_coordinate($x, $y);
    $y -= $height;

    $PDF->image( $img, $x, $y , $width, $height );

    return 1;
}



#
#  hline
#    指定した座標から水平右方向へ指定した長さだけ直線を描画する．line( mode => 'horizontal' ) のラッパ
#  vline
#    指定した座標から垂直下方向へ指定した長さだけ直線を描画する．line( mode => 'vertical' ) のラッパ
#
#  @param   x       scalar  # 始点のx座標
#  @param   y       scalar  # 始点のy座標
#  @param   length  scalar  # 直線の長さ
#  @param  ?size    scalar  # 直線の幅
#  @param  ?type    scalar  # 直線の種類
#  @param  ?color   scalar  # 直線の色
#
#  @return
#
sub hline { shift->line( mode => 'h', @_ ); }
sub vline { shift->line( mode => 'v', @_ ); }
#
#  直線を描画する
#
#  @param   mode    scalar  # 描画モード．horizontal: 水平線, vertical: 垂直線
#  @param   x       scalar  # 始点のx座標
#  @param   y       scalar  # 始点のy座標
#  @param   length  scalar  # 直線の長さ
#  @param  ?size    scalar  # 直線の幅
#  @param  ?type    scalar  # 直線の種類
#  @param  ?color   scalar  # 直線の色
#
#  @return
#
sub line {
    my ($self, %params) = @_;
    my $v = Data::Validator->new(
        mode   => { isa => LineMode },
        x      => { isa => Unit },
        y      => { isa => Unit },
        length => { isa => Unit },
        size   => { isa => Unit, default => $self->_LINE_WIDTH },
        color  => { isa => Color, default => $self->_COLOR_STROKE },
    );
    %params = %{ $v->validate(%params) };

    my $PDF = $self->_PDF;

    my $mode   = $params{mode};
    my $x      = $params{x};
    my $y      = $params{y};
    my $length = $params{length};
    my $size   = $params{size};
    my $color  = $params{color};

    #
    #  horizontal
    #
    if ( $mode =~ /^h(orizontal)?$/  ) {
        $length .= 'w'  if $length =~ m{\%\s*$};  # 長さを割合で指定した場合，ページ幅を対象とする
        $size   .= 'h'  if $size   =~ m{\%\s*$};  # 線幅を割合で指定した場合，ページ高さを対象とする

        ( $x, $y ) = $self->convert_coordinate( $x, $y );
        $length = $self->to_px( $length );
        $size   = $self->to_px( $size );

        $PDF->strokecolor( $color );
        $PDF->linewidth( $size );
        $PDF->move( $x, $y );
        $PDF->line( $x + $length, $y );
        $PDF->stroke;
    }
    #
    #  vertical
    #
    elsif ( $mode =~ /^v(ertical)?$/ ) {
        $length .= 'h'  if $length =~ m{\%\s*$};  # 長さを割合で指定した場合，ページ高さを対象とする
        $size   .= 'w'  if $size   =~ m{\%\s*$};  # 線幅を割合で指定した場合，ページ幅を対象とする

        ( $x, $y ) = $self->convert_coordinate( $x, $y );
        $length = $self->to_px( $length );
        $size   = $self->to_px( $size );

        $PDF->strokecolor( $color );
        $PDF->linewidth( $size );
        $PDF->move( $x, $y );
        $PDF->line( $x, $y - $length );
        $PDF->stroke;
    }

    1;
}



#
#  角丸長方形を描画する
#
#  @param    x            scalar   左上のx座標
#  @param    y            scalar   左上のy座標
#  @param    w            scalar   幅
#  @param    h            scalar   高さ
#  @param    r            scalar   角丸の半径
#  @param   ?linewidth    scalar   輪郭の幅
#  @param   ?strokecolor  scalar
#  @param   ?fillcolor    scalar
#  @param   ?action       scalar   描画方法．stroke, fill, fillstroke
#
#  @return
#
sub roundrect {
    my ($self, %params) = @_;
    my $v = Data::Validator->new(
        x           => { isa => Unit },
        y           => { isa => Unit },
        w           => { isa => Unit },
        h           => { isa => Unit },
        r           => { isa => Unit },
        linewidth   => { isa => Unit, default => $self->_LINE_WIDTH },
        strokecolor => { isa => Color, default => $self->_COLOR_STROKE },
        fillcolor   => { isa => Color, default => $self->_COLOR_FILL },
        action      => { isa => DrawAction, default => 'stroke' },
    );
    %params = %{ $v->validate(%params) };

    my $PDF = $self->_PDF;

    my ($x, $y, $w, $h, $r) = @params{qw/x y w h r/};
    my $linewidth   = $params{linewidth};
    my $strokecolor = $params{strokecolor};
    my $fillcolor   = $params{fillcolor};
    my $action      = $params{action};

    ( $x, $y ) = $self->convert_coordinate( $x, $y );
    $w = $self->to_px( $w );
    $h = $self->to_px( $h );
    $r = $self->to_px( $r );

    $PDF->linewidth( $linewidth );
    $PDF->strokecolor( $strokecolor );
    $PDF->fillcolor( $fillcolor );

    # パスをセット
    $PDF->move( $x, $y - $r );
    $PDF->curve( $x, $y - $r,  $x, $y,  $x + $r, $y );                                # 左上角丸
    $PDF->line( $x + $w - $r, $y );                                                   # 上辺
    $PDF->curve( $x + $w - $r, $y,  $x + $w, $y,  $x + $w, $y - $r );                 # 右上角丸
    $PDF->line( $x + $w, $y - $h + $r );                                              # 右辺
    $PDF->curve( $x + $w, $y - $h + $r,  $x + $w, $y - $h,  $x + $w - $r, $y - $h );  # 右下角丸
    $PDF->line( $x + $r, $y - $h );                                                   # 下辺
    $PDF->curve( $x + $r, $y - $h,  $x, $y - $h,  $x, $y - $h + $r );                 # 左下角丸
    $PDF->close;                                                                      # パスを閉じることで左辺

    # 描画
    if   ( $action eq 'stroke' )     { $PDF->stroke; }
    elsif( $action eq 'fill' )       { $PDF->fill; }
    elsif( $action eq 'fillstroke' ) { $PDF->fillstroke; }
    else                             { die "action \"$action\" is not supported." }

    return 1;
}


sub add_font_dirs {
    shift  if $_[0] eq __PACKAGE__  ||  ref($_[0]) eq __PACKAGE__;
    my @dirs = @_;
    return PDF::API2::addFontDirs(@dirs);
}


#
#  ラッパ
#

sub pages {
    shift->_PDF->{api}->pages;
}

sub update {
    shift->_PDF->{api}->update;
}

sub end {
    shift->_PDF->{api}->end;
}




1;
__END__

=head1 NAME

PDF::API2::Koromo - B<**ALPHA QUALITY**>  A wrapper of PDF::API2.

=head1 SYNOPSIS

  use PDF::API2::Koromo;

  my $pdf = PDF::API2::Koromo->new;
  $pdf->page;
  $pdf->text( x => 0, y => 20, text => 'hoge' );
  $pdf->image( x => '5mm', y => '10%', file => '/path/to/image.jpg' );
  $pdf->save( file => $file );

=head1 DESCRIPTION

PDF::API2::Koromo is a wrapper of PDF::API2.

=head1 CONSTRUCTOR

=over 4

=item $pdf = PDF::API2::Koromo->new( %options )

B<%options>:
  measure => $measure
    デフォルトで使用する単位．px（ピクセル）, mm（ミリメートル）が使用可能．
  dpi => $dpi
    解像度．[DPI]
  width  => $width
    生成するPDFのページ幅．
  height => $height
    生成するPDFのページ高さ．
  ttfont => $ttfont_file
    デフォルトで使用するTrueTypeフォントのファイル．
  fontsize => $fontsize
    フォントのサイズ．
  line_height => $line_height
    行高さ．
  strokecolor => $strokecolor
    ストロークの色．
  fillcolor => $fillcolor
    塗りつぶしの色．
  linewidth => $linewidth
    線・輪郭の幅．

=back

=head1 METHODS

=over 4

=item $px = $pdf->to_px( $length );

単位つきの数値（文字列）をピクセル値に変換する．

"mm", "cm", "pt", "%w", "%h" and  "px" are available.

=item $px = $pdf->mm( $mm )

Converts from [mm] to [px].

=item $px = $pdf->pt( $pt )

Converts from [pt] to [px].

=item ( $x_new, $y_new ) = $pdf->convert_coordinate( $x, $y )

左上を原点，水平右方向をx軸，垂直下方向をy軸とした座標系における座標から，
左下を原点，水平右方向をx軸，垂直上方向をy軸とした座標系における座標を取得する．

=item $pdf->load( $file )

NOT IMPLEMENTED.

=item $pdf->page

Creates new page.

=item $pdf->save( file => $file [, image => $image, scale => $scale, image_only => $image_only] )

Saves as PDF or image.

=item $pdf->ttfont( $ttf_file )

Sets TryeType Font.

=item $pdf->text( x => $x, y => $y, text => $text [, %options ] )

Draws text.

B<%options>:
  w
  h
  tate
  ttfont
  fontsize
  size
  line_height
  rotate
  color
  debug

=item $pdf->image( x => $x, y => $y, file => $image_file [, %options ] )

Locates image.

B<%options>:
  width
  height
  scale
  rotate
  debug

=item $pdf->hline( x => $x, y => $y, length => $length [, %options ] )

Draws a horizontal line.

B<%options>:
  size
  type
  color

=item $pdf->vline( x => $x, y => $y, length => $length [, %options ] )

Draws a vertical line.

B<%options>:
  size
  type
  color

=item $pdf->line( mode => $mode, x => $x, y => $y [, %options ] )

Draws a line.

B<%options>:
  size
  type
  color

=item $pdf->roundrect( x => $x, y => $y, w => $w, h => $h, r => $r [, %options ] )

Draws a rounded rectangle.

B<%options>
  linewidth
  strokecolor
  fillcolor
  action  描画方法． stroke, fill, fillstroke

=item @font_dirs_all = PDF::API2::Koromo->add_font_dirs( @font_dirs );

Adds default font directories.


=back

=head1 AUTHOR

issm E<lt>issmxx@gmail.comE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
