# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

package OpenQA::Task::Needle::Delete;
use Mojo::Base 'Mojolicious::Plugin';

use OpenQA::Utils;
use Scalar::Util 'looks_like_number';
use Time::Seconds 'ONE_HOUR';

sub register {
    my ($self, $app) = @_;
    $app->minion->add_task(delete_needles => sub { _delete_needles($app, @_) });
}

sub _delete_needles {
    my ($app, $minion_job, $args) = @_;

    my $schema = $app->schema;
    my $needles = $schema->resultset('Needles');
    my $user = $schema->resultset('Users')->find($args->{user_id});
    my $needle_ids = $args->{needle_ids};

    my (@removed_ids, @errors);

    my %to_remove;
    for my $needle_id (@$needle_ids) {
        my $needle = looks_like_number($needle_id) ? $needles->find($needle_id) : undef;
        if (!$needle) {
            push @errors,
              {
                id => $needle_id,
                message => "Unable to find needle with ID \"$needle_id\"",
              };
            next;
        }
        push @{$to_remove{$needle->directory->path}}, $needle;
    }

    for my $dir (sort keys %to_remove) {
        my $needles = $to_remove{$dir};
        # prevent multiple git tasks to run in parallel
        my $guard;
        unless ($guard = $app->minion->guard("git_clone_${dir}_task", 2 * ONE_HOUR)) {
            push @errors,
              {
                id => $_,
                message => "Another git task for $dir is ongoing. Try again later.",
              }
              for map { $_->id } @$needles;
            next;
        }
        for my $needle (@$needles) {
            my $needle_id = $needle->id;
            if (my $error = $needle->remove($user)) {
                push @errors,
                  {
                    id => $needle_id,
                    display_name => $needle->filename,
                    message => $error,
                  };
                next;
            }
            push @removed_ids, $needle_id;
        }
    }

    return $minion_job->finish(
        {
            removed_ids => \@removed_ids,
            errors => \@errors
        });
}

1;
