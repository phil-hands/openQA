# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

package OpenQA::Worker::Isotovideo::Client;
use Mojo::Base -base;

use Mojo::UserAgent;
use OpenQA::Log qw(log_debug);

has job => undef, weak => 1;
has ua => sub { Mojo::UserAgent->new };

sub stop_gracefully {
    my ($self, $reason, $callback) = @_;

    return Mojo::IOLoop->next_tick($callback) unless my $url = $self->url;
    $url .= '/broadcast';

    log_debug("Announcing job termination (due to $reason) to command server via $url");
    my $ua = $self->ua;
    my $old_timeout = $ua->request_timeout;
    $ua->request_timeout(10);
    $ua->post(
        $url => json => {stopping_test_execution => $reason} => sub {
            my ($ua, $tx) = @_;

            my $res = $tx->res;
            if (!$res->is_success) {
                log_debug('Unable to announce job termination (NOT the reason for the job termination):');
                log_debug($res->code ? $res->to_string : 'Command server is likely finished already');
            }
            $callback->();
        });
    $ua->request_timeout($old_timeout);
}

sub url {
    my $self = shift;
    return undef unless my $info = $self->job->info;
    return $info->{URL};
}

1;
