use v6;

use PDF::Style::Element;

class PDF::Style::Element::Text
    is PDF::Style::Element {

    use CSS::Box;
    use CSS::Properties;
    use PDF::Style::Font;

    use PDF::Content::Color :&color, :&gray;
    use PDF::Content::Text::Box;
    use PDF::Content::FontObj;
    has PDF::Content::Text::Box $.text;
    use PDF::Tags::Elem;

    method !text-box-options( :$font!, CSS::Properties :$css! ) {
        my $kern = $css.font-kerning eq 'normal' || (
            $css.font-kerning eq 'auto' && $css.em <= 32
        );

        my $align = $css.text-align;
        my $font-size = $css.em;
        my $leading = $css.measure(:line-height) / $font-size;
        my PDF::Content::FontObj $face = $font.font-obj;

        # support a vertical-align subset
        my $valign = do given $css.vertical-align {
            when 'middle' { 'center' }
            when 'top'|'bottom' { $_ }
            default { 'top' };
        }
        my %opt = :baseline<top>, :font($face), :$kern, :$font-size, :$leading, :$align, :$valign;

        given $css.letter-spacing {
            %opt<CharSpacing> = $css.measure($_)
                unless $_ eq 'normal';
        }

        given $css.word-spacing {
            %opt<WordSpacing> = $css.measure($_) - $face.stringwidth(' ', $font-size)
                unless $_ eq 'normal';
        }

        %opt;
    }

    #| create a child element. Positioning is relative to this object. CSS styles
    #| are inherited from this object.
    method place-element( Str:D :$text!,
                          CSS::Properties :$css!,
                          CSS::Box :$container!,
                          PDF::Tags::Elem :$tag,
        ) {

        my PDF::Style::Font $font = $container.font.setup($css);
        my %opt = self!text-box-options( :$font, :$css);
        my &build-content = sub (|c) {
            text => PDF::Content::Text::Box.new( :$text, |%opt, |c);
        };
        nextwith(:$css, :&build-content, :$container, :$tag);
    }

    method !set-font-color($gfx) {
        with $.css.color {
            $gfx.FillColor = color $_;
            $gfx.FillAlpha = .a / 255;
        }
        else {
            $gfx.FillColor = gray(0.0);
            $gfx.FillAlpha = 1.0;
        }
        $gfx.StrokeAlpha = 1.0;
    }

    method render-element($gfx) {
        with $!text -> \text {
            my $top = $.top - $.bottom;
            self!set-font-color($gfx);
            $gfx.print(text, :position[ :left(0), :$top]);
        }
    }

    method html {
        my $css = $.css.clone;
        $css.vertical-align = Nil; # we'll deal with this later
        my $style = $css.write;

        my $text = do with $!text {
            $.html-escape(.text);
        }
        else {
            ''
        }
        with $.css.vertical-align -> $valign {
            when 'baseline' { }
            default {
                # wrap content in a table cell for valign to take affect
                $text = '<table width="100%%" height="100%%" cellspacing=0 cellpadding=0><tr><td style="vertical-align:%s">%s</td></tr></table>'.sprintf($valign, $text);
            }
        }

        my $style-att = $style
            ?? $.html-escape($style).fmt: ' style="%s"'
            !! '';
        '<div%s>%s</div>'.sprintf($style-att, $text);
    }

}
