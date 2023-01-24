# Copyright 2018 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

package OpenQA::Client::Handler;
use Mojo::Base 'Mojo::EventEmitter', -signatures;

use OpenQA::Client;
use OpenQA::Utils qw(is_host_local);

has client => sub { OpenQA::Client->new };

has api_path => '/api/v1/';

sub _build_url ($self, $uri) {
    # Check and make it Mojo::URL if wasn't already
    $self->client->base_url(Mojo::URL->new($self->client->base_url)) unless ref $self->client->base_url eq 'Mojo::URL';

    my $base_url = $self->client->base_url->clone;
    my $is_api_url = $base_url->path->parts->[0];
    $uri = ($is_api_url && $is_api_url eq 'api') ? $uri : $self->api_path . $uri;
    $base_url->scheme('http') unless $base_url->scheme;    # Guard from no scheme in worker's conf files
    $base_url->path($uri);

    return $base_url;
}

sub _build_post { $_[0]->client->build_tx(POST => shift()->_build_url(+shift()) => form => +shift()) }

sub is_local ($self) { is_host_local($self->_build_url('/')->to_abs->host) }

1;
