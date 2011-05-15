package PDF::API2::Koromo;
use strict;
use warnings;
use utf8;
use base qw/Class::Accessor::Faster/;
use PDF::API2;
use PDF::API2::Lite;
use Image::Magick;
use Image::Size;
use Encode;
use Carp;
use Try::Tiny;

our $VERSION = '0.00_01';

#
#
#
#  座標系：水平右方向を x，垂直下方向を y とする．また，左上を (x, y) = (0, 0) とする
#

#
#  使用可能な単位
#
#    px:     ピクセル
#    mm:     ミリメートル
#    cm:     センチメートル
#    %w, %W: ページ幅に対する割合
#    %h, %H: ページ高さに対する割合
#

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


#--------------------------------------------------------------------------------
#
#  初期値
#
#--------------------------------------------------------------------------------
my $MEASURE      = 'px';       # 単位
my $DPI          = 300;        # 解像度
my $PAGE_WIDTH   = '210mm';    # ページ幅 [px]    デフォルトは A4 （縦）の幅
my $PAGE_HEIGHT  = '297mm';    # ページ高さ [px]  デフォルトは A4 （縦）の高さ

my $PDF          = undef;      #  PDFオブジェクト
my $FONT         = undef;      #  フォントオブジェクト
my $FONT_SIZE    = 14;         #  フォントサイズ
my $LINE_HEIGHT  = '100%';     #  行高さ

my $ROTATE       = 0;          # 配置オブジェクトの回転角度
my $COLOR_STROKE = '#000000';  # ストロークの色
my $COLOR_FILL   = '#ffffff';  # 塗りつぶしの色

my $LINE_WIDTH   = 1;          # 線の幅


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
    my $class = shift;
    my $param = shift || {};
    my $self = bless $class->SUPER::new($param), $class;

    $class->mk_accessors(
        qw/
              _PDF _MEASURE _DPI _WIDTH _HEIGHT _FONT _FONT_SIZE _LINE_HEIGHT _ROTATE _COLOR_STROKE _COLOR_FILL _LINE_WIDTH
              measure dpi width height ttfont fontsize line_height strokecolor fillcolor linewidth
          /
    );

    return $self->_init;
}

#
#  初期化
#
sub _init {
    my $self = shift;
    my $param = +{@_};
    #my ($self, $param ) = self_param(@_);

    $self->_DPI(
        defined $self->dpi  ?  $self->dpi  :  $DPI
    );
    $self->_MEASURE(
        defined $self->measure  ?  $self->measure  :  $MEASURE
    );
    $self->_WIDTH(
        $self->to_px(defined $self->width  ?  $self->width  :  $PAGE_WIDTH)
    );
    $self->_HEIGHT(
        $self->to_px(defined $self->height  ?  $self->height  :  $PAGE_HEIGHT)
    );

    $self->_PDF(
        $PDF = PDF::API2::Lite->new
    );
    $self->page;

    $self->_FONT($PDF->ttfont( $self->ttfont ))  if defined $self->ttfont;

    $self->_FONT_SIZE(
        $self->to_px(defined $self->fontsize  ?  $self->fontsize  :  $FONT_SIZE)
    );
    $self->_LINE_HEIGHT(
        defined $self->line_height  ?  $self->line_height  :  $LINE_HEIGHT
    );

    $self->_COLOR_STROKE(
        defined $self->strokecolor  ?  $self->strokecolor  :  $COLOR_STROKE
    );
    $self->_COLOR_FILL(
        defined $self->fillcolor  ?  $self->fillcolor  :  $COLOR_FILL
    );

    $self->_LINE_WIDTH(
        defined $self->linewidth  ?  $self->linewidth  :  $LINE_WIDTH
    );


    $PDF->strokecolor($self->_COLOR_STROKE);
    $PDF->fillcolor($self->_COLOR_FILL);

    $self;
}


#
#  単位付き文字列を [px] に変換する
#
#  @param   scalar
#
#  @return  scalar  ピクセル数
#
sub to_px {
    my $self = shift;
    my $length = shift  ||  0;

    my ($val, $measure) = $length =~ $RE->{LENGTH};
    $measure = $self->_MEASURE  unless defined $measure;
    return 0  unless defined $val;

    my $ret = 0;

    #$val *= $self->{RATE}  unless lc $measure =~ m{^\%(w|h)$};

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
    else                           { $ret = $val; }

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
    my ($self, $mm) = @_;
    my $mm2px_rate = $self->_DPI / 25.4;
    return int(($mm || 0) * $mm2px_rate);
};

#
#  [pt] を [px] に変換する
#
sub pt {
    my ($self, $pt) = @_;
    my $pt2px_rate = $self->_DPI / 72;
    return int(($pt || 0) * $pt2px_rate);
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
    my $self = shift;
    my ($x, $y) = @_;
    $x .= 'w'  if $x =~ m{\%\s*$};
    $y .= 'h'  if $y =~ m{\%\s*$};

    carp 'not specified x or/and y'  unless defined  $x  &&  defined $y;

    return (
        $self->to_px($x),
        $self->_HEIGHT - $self->to_px($y),
    );
}



#
#
#
sub load {
    my $self = shift;
    my $param = +{@_};
    #my ($self, $param) = self_param( @_ );
    my $file = $param->{file};
    try {
        $PDF->{api} = PDF::API2->open($file);
    }
    catch {
        carp shift;
        $PDF->{api} = undef;
    }
}



#
#  新規にページを作成する
#
sub page {
    my $self = shift;
    $PDF->page($self->_WIDTH, $self->_HEIGHT);
}


#
#  指定したページを開く（？）
#
sub openpage {
    my $self = shift;
    my $param = +{@_};
  #my ($self, $param) = self_param @_;
  $PDF->{api}->openpage($param->{page} || -1);
}

#
#  指定したページを指定した角度で回転させる
#
sub rotatepage {
    my $self = shift;
    my $param = +{@_};
    #my ($self, $param) = self_param @_;
    my $page   = $param->{page} || -1;
    my $degree = $param->{degree} || $param->{deg} || 0;
    $self->openpage(page => $page)->rotate($degree);
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
    my $self = shift;
    my $param = +{@_};
  #my ( $self, $param )  = self_param( @_ );
  my $file       = $param->{file}        ||  '';
  my $image      = $param->{image};
  my $scale      = $param->{scale}       ||  1;
  my $image_only = $param->{image_only}  ||  0;

  return 0  unless $file;
  return 0  unless $PDF->{api}->{pdf};  # 一度saveを呼び出すと，この値（？）は undef される． ← PDF::API2::out_file あたりを参照

  #
  #  PDF を保存
  #
  $PDF->saveas( $file )  ||  die $!;


  #
  #  画像として保存（新タイプ）
  #
  if( defined $image  &&  ref $image eq 'HASH' ) {
    if( $image->{file} =~ m{\. ( jpe?g | png | gif ) $}ix ) {
      my $img = Image::Magick->new;
      $img->Read( filename => $file );

      # 幅，高さ指定時
      if( $image->{width}  ||  $image->{height} ) {
        $img->Resize(
          width  => $self->to_px( $image->{width}  ||  $image->{height} ),
          height => $self->to_px( $image->{height}  ||  $image->{width} ),
        );
      }
      # 格納正方形指定時
      elsif( $image->{square} ) {
        my $geometry = sprintf '%dx%d', $self->to_px( $image->{square} ), $self->to_px( $image->{square} );
        $img->Resize( geometry => $geometry );
      }
      # 倍率指定時
      elsif( defined $image->{scale} ) {
        $img->Resize(
          width  => $self->_WIDTH  * $image->{scale},
          height => $self->_HEIGHT * $image->{scale},
        );
      }

      # 属性の設定
      # $img->Set(
      #   density => sprintf( '%dx%d', $self->_DPI, $self->_DPI ),
      #   units   => 'PixelsPerInch',
      # );
      # 出力
      $img->Write( filename => $image->{file} );
      undef $img;
    }

    unlink $file  if $image->{only};  # 「画像のみ保存」指定の場合，保存したPDFを削除する
  }
  #
  #  画像として保存（旧タイプ，deprecated）
  #
  elsif( defined $image  &&  ref $image eq '' ) {
    if( $image =~ m{\. ( jpe?g | png | gif ) $}ix ) {
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
      $img->Write( filename => $image );
      undef $img;
    }

    unlink $file  if $image_only;  # 「画像のみ保存」指定の場合，保存したPDFを削除する
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
    my $self = shift;
    my $param = +{@_};
  #my ( $self, $param ) = self_param( @_ );
  my $x           = $param->{x};
  my $y           = $param->{y};
  my $text        = $param->{text};
  my $w           = $param->{w};
  my $h           = $param->{h};
  my $tate        = $param->{tate}      || 0;
  my $ttfont      = $param->{ttfont};
  my $fontsize    = defined $param->{fontsize} || defined $param->{size}  ?  $self->to_px( $param->{fontsize} || $param->{size} )  :  $self->_FONT_SIZE;
  my $line_height = defined $param->{line_height}  ?  $param->{line_height}  :  $self->_LINE_HEIGHT;  # ここではまだ to_px しない
  my $rotate      = $param->{rotate}    ||  $self->_ROTATE;
  my $color       = $param->{color}     ||  $self->_COLOR_FILL;
  my $debug       = $param->{debug}     ||  0;

  return 0  unless( defined $x  &&  defined $y  &&  defined $text );

  $w = $w  ?  $self->to_px( $w )  :  $self->_WIDTH - $self->to_px( $x );
  $h = $h  ?  $self->to_px( $h )  :  $self->_HEIGHT - $self->to_px( $y );

  ( $x, $y ) = $self->convert_coordinate( $x, $y );

  $PDF->fillcolor( $color );

  my $font = $ttfont  ?  $PDF->ttfont( $ttfont )  :  $self->_FONT;

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
    my $self = shift;
    my $param = +{@_};
    #my ( $self, $param ) = self_param( @_ );
    my $x      = $param->{x};
    my $y      = $param->{y};
    my $file   = $param->{file};
    my $width  = defined $param->{width}  ? $param->{width}  : 0;
    my $height = defined $param->{height} ? $param->{height} : 0;
    my $scale  = defined $param->{scale}  ? $param->{scale}  : 1;
    my $rotate = $param->{rotate} || 0;
    my $debug  = $param->{debug}  || 0;

    return 0  unless  defined $x  &&  defined $y  &&  defined $file;
    return 0  unless -f $file;

    ($x, $y) = $self->convert_coordinate($x, $y);

    $width  .= 'w'  if $width  =~ m{\%\s*$};
    $height .= 'h'  if $height =~ m{\%\s*$};
    $width  = $self->to_px($width);
    $height = $self->to_px($height);

    my ($w, $h, $type) = imgsize($file);
    my $img;
    my $flg = 1;

    # 幅，高さが未定義の場合
    $width ||= $w;  $height ||= $h;

    # 幅・高さどちらも指定
    if ($width  &&  $height) {
        1;
    }
    # 幅のみ指定
    elsif ($width) {
        $scale = $width / $w;
    }
    # 高さのみ指定
    elsif ($height) {
        $scale = $height / $h;
    }

    # JPG
    if (uc $type eq 'JPG') {
        $img = $PDF->image_jpeg($file);
    }
    # PNG
    elsif (uc $type eq 'PNG') {
        $img = $PDF->image_png($file);
    }
    # TIF
    elsif (uc $type eq 'TIF') {
        $img = $PDF->image_tiff($file);
    }
    else {
        $flg = 0;
    }

    if ($flg) {
        $width  &&  $height
            ?  $PDF->image($img, $x, $y - $height, $width, $height)
            :  $PDF->image($img, $x, $y - int($h * $scale), $scale)
        ;
    }

    $flg ? 1 : 0;
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
sub hline { shift->line( mode => 'horizontal', @_ ); }
sub vline { shift->line( mode => 'vertical', @_ ); }
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
    my $self = shift;
    my $param = +{@_};
  #my ( $self, $param ) = self_param( @_ );
  my $mode   = $param->{mode};
  my $x      = $param->{x};
  my $y      = $param->{y};
  my $length = $param->{length};
  my $size   = $param->{size}   ||  $self->_LINE_WIDTH;
  my $type   = $param->{type};
  my $color  = $param->{color}  ||  $self->_COLOR_STROKE;

  return 0  unless( defined $mode  &&  defined $x  &&  defined $y  &&  defined  $length );

  #
  #  horizontal
  #
  if( $mode eq 'horizontal' ) {
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
  elsif( $mode eq 'vertical' ) {
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
    my $self = shift;
    my $param = +{@_};
  #my ( $self, $param ) = self_param( @_ );
  my ( $x, $y, $w, $h, $r ) = ( $param->{x}, $param->{y}, $param->{w}, $param->{h}, $param->{r} );
  my $linewidth   = defined $param->{linewidth}  ?  $self->to_px( $param->{linewidth} )  :  $self->_LINE_WIDTH;
  my $strokecolor = $param->{strokecolor}  ||  $self->_COLOR_STROKE;
  my $fillcolor   = $param->{fillcolor}    ||  $self->_COLOR_FILL;
  my $action      = $param->{action}       ||  'stroke';

  return 0  unless( defined $x  &&  defined $y  &&  defined $w  &&  defined $h  &&  defined $r );

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
  if( $action eq 'stroke' )        { $PDF->stroke; }
  elsif( $action eq 'fill' )       { $PDF->fill; }
  elsif( $action eq 'fillstroke' ) { $PDF->fillstroke; }
  else                             { $PDF->stroke; }
  1;
}


#
#  ラッパ
#


sub importpage {
  my $self = shift;
  my $pdf_source   = shift;  # PDF::API2::Koromo オブジェクト
  my $index_source = shift  ||  0;
  my $index_target = shift  ||  0;

  defined $pdf_source
    ? $PDF->{api}->importpage( $pdf_source->_PDF->{api}, $index_source, $index_target )
    : undef
  ;
}


sub pages {
  $PDF->{api}->pages;
}

sub update {
  $PDF->{api}->update;
}

sub end {
  $PDF->{api}->end;
}



1;
__END__

=head1 NAME

PDF::API2::Koromo - A wrapper of PDF::API2.

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

=item $pdf = Megane::Tool::PDF->new( %options )

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


=item $px = $pdf->mm( $mm )

ミリメートル値をピクセル値に変換する．

=item $px = $pdf->pt( $pt )

ポイント値をピクセル値に変換する．

=item ( $x_new, $y_new ) = $pdf->convert_coordinate( $x, $y )

左上を原点，水平右方向をx軸，垂直下方向をy軸とした座標系における座標から，
左下を原点，水平右方向をx軸，垂直上方向をy軸とした座標系における座標を取得する．

=item $pdf->load( $file )

未実装．

=item $pdf->page

新しいページを作成する．

=item $pdf->save( file => $file [, image => $image, scale => $scale, image_only => $image_only] )

PDFや画像として保存する．

=item $pdf->ttfont( $ttf_file )

TrueTypeフォントを設定する．

=item $pdf->text( x => $x, y => $y, text => $text [, %options ] )

テキストを描画する．

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

画像を配置する．

B<%options>:
  width
  height
  scale
  rotate
  debug

=item $pdf->hline( x => $x, y => $y, length => $length [, %options ] )

水平線を描画する．

B<%options>:
  size
  type
  color

=item $pdf->vline( x => $x, y => $y, length => $length [, %options ] )

水平線を描画する．

B<%options>:
  size
  type
  color

=item $pdf->line( mode => $mode, x => $x, y => $y [, %options ] )

直線を描画する．

B<%options>:
  size
  type
  color

=item $pdf->roundrect( x => $x, y => $y, w => $w, h => $h, r => $r [, %options ] )

角丸長方形を描画する．

B<%options>
  linewidth
  strokecolor
  fillcolor
  action  描画方法． stroke, fill, fillstroke

=back

=head1 AUTHOR

issm E<lt>issmxx@gmail.comE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
