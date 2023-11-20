# Copyright 2023 LLC
# SPDX-License-Identifier: GPL-2.0-or-later

package OpenQA::Schema::ResultSet::ScheduledProducts;

use Mojo::Base 'DBIx::Class::ResultSet', -signatures;
use OpenQA::Schema::Result::ScheduledProducts qw(CANCELLED);
use OpenQA::App;

sub create_with_event ($self, $params, $user, $webhook_id = undef) {
    my $scheduled_product = $self->create(
        {
            distri => $params->{DISTRI} // '',
            version => $params->{VERSION} // '',
            flavor => $params->{FLAVOR} // '',
            arch => $params->{ARCH} // '',
            build => $params->{BUILD} // '',
            iso => $params->{ISO} // '',
            settings => $params,
            user_id => $user->id,
            webhook_id => $webhook_id,
        });
    OpenQA::App->singleton->emit_event(openqa_iso_create => {scheduled_product_id => $scheduled_product->id});
    return $scheduled_product;
}

sub cancel_by_webhook_id ($self, $webhook_id, $reason) {
    my $count = 0;
    $count += $_->cancel($reason) for $self->search({webhook_id => $webhook_id, -not => {status => CANCELLED}});
    return {jobs_cancelled => $count};
}

1;
