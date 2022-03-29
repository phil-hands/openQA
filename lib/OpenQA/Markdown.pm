# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
package OpenQA::Markdown;
use Mojo::Base -strict;

use Exporter 'import';
use Regexp::Common 'URI';
use OpenQA::Utils qw(BUGREF_REGEX LABEL_REGEX bugurl);
use OpenQA::Constants qw(FRAGMENT_REGEX);
use CommonMark;

our @EXPORT_OK = qw(bugref_to_markdown is_light_color markdown_to_html);

sub bugref_to_markdown {
    my $text = shift;
    $text =~ s/${\BUGREF_REGEX}/"[$+{match}](" . bugurl($+{match}) . ')'/geio;
    return $text;
}

sub is_light_color {
    my $color = shift;
    return undef unless $color =~ m/^#([a-fA-F0-9]{2})([a-fA-F0-9]{2})([a-fA-F0-9]{2})$/;
    my ($red, $green, $blue) = ($1, $2, $3);
    my $sum = hex($red) + hex($green) + hex($blue);
    return $sum > 380;
}

sub markdown_to_html {
    my $text = shift;

    $text = bugref_to_markdown($text);

    # Turn all remaining URLs into links
    $text =~ s/(?<!['"(<>])($RE{URI}${\FRAGMENT_REGEX})/<$1>/gio;

    # Turn references to test modules and needling steps into links
    $text =~ s!\b(t#([\w/]+))![$1](/tests/$2)!gi;

    my $html = CommonMark->markdown_to_html($text);

    # Make labels easy to highlight
    $html =~ s/${\LABEL_REGEX}/<span class="openqa-label">label:$+{match}<\/span>/g;

    # Custom markup "{{color:#ff0000|Some text}}"
    $html =~ s/(\{\{([^|]+?)\|(.*?)\}\})/_custom($1, $2, $3)/ge;

    return $html;
}

sub _custom {
    my ($full, $rules, $text) = @_;
    if ($rules =~ /^color:(#[a-fA-F0-9]{6})$/) {
        my $color = $1;
        my $bg = is_light_color($color) ? 'black' : 'white';
        return qq{<span style="color:$color;background-color:$bg">$text</span>};
    }
    return $full;
}

1;
