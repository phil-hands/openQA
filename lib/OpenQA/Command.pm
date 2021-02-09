# Copyright (C) 2020 SUSE LLC
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, see <http://www.gnu.org/licenses/>.

package OpenQA::Command;
use Mojo::Base 'Mojolicious::Command';

use Cpanel::JSON::XS ();
use OpenQA::Client;
use Mojo::IOLoop;
use Mojo::Util qw(decode getopt);
use Mojo::URL;
use Term::ANSIColor qw(colored);

my $JSON = Cpanel::JSON::XS->new->utf8->canonical->allow_nonref->allow_unknown->allow_blessed->convert_blessed
  ->stringify_infnan->escape_slash->allow_dupkeys->pretty;

has apibase => '/api/v1';
has [qw(apikey apisecret host)];
has host => 'http://localhost';

sub client {
    my ($self, $url) = @_;
    return OpenQA::Client->new(apikey => $self->apikey, apisecret => $self->apisecret, api => $url->host)
      ->ioloop(Mojo::IOLoop->singleton);
}

sub data_from_stdin {
    vec(my $r = '', fileno(STDIN), 1) = 1;
    return !-t STDIN && select($r, undef, undef, 0) ? join '', <STDIN> : '';
}

sub decode_args {
    my ($self, @args) = @_;
    return map { decode 'UTF-8', $_ } @args;
}

sub handle_result {
    my ($self, $tx, $options) = @_;

    my $res     = $tx->res;
    my $is_json = ($res->headers->content_type // '') =~ m!application/json!;

    my $err                 = $res->error;
    my $is_connection_error = $err && !$err->{code};

    if ($options->{verbose} && !$is_connection_error) {
        my $version = $res->version;
        my $code    = $res->code;
        my $msg     = $res->message;
        print "HTTP/$version $code $msg\n", $res->headers->to_string, "\n\n";
    }

    elsif (!$options->{quiet} && $err) {
        my $code = $err->{code} // '';
        $code .= ' ' if length $code;
        my $msg = $err->{message};
        print STDERR colored(['red'], "$code$msg", "\n");
    }

    if    ($options->{pretty} && $is_json) { print $JSON->encode($res->json) }
    elsif (length(my $body = $res->body))  { say $body }

    return $err ? 1 : 0;
}

sub parse_headers {
    my ($self, @headers) = @_;
    return {map { /^\s*([^:]+)\s*:\s*(.*+)$/ ? ($1, $2) : () } @headers};
}

sub parse_params {
    my ($self, @args) = @_;

    my %params;
    for my $arg (@args) {
        next unless $arg =~ /^([[:alnum:]_\[\]\.]+)=(.*)$/s;
        push @{$params{$1}}, $2;
    }

    return \%params;
}

sub run {
    my ($self, @args) = @_;

    getopt \@args, ['pass_through'],
      'apibase=s'   => sub { $self->apibase($_[1]) },
      'apikey=s'    => sub { $self->apikey($_[1]) },
      'apisecret=s' => sub { $self->apisecret($_[1]) },
      'host=s'      => sub { $self->host($_[1] =~ m!^/|://! ? $_[1] : "https://$_[1]") },
      'o3'          => sub { $self->host('https://openqa.opensuse.org') },
      'osd'         => sub { $self->host('http://openqa.suse.de') };

    return $self->command(@args);
}

sub url_for {
    my ($self, $path) = @_;
    $path = "/$path" unless $path =~ m!^/!;
    return Mojo::URL->new($self->host)->path($self->apibase . $path);
}

1;
