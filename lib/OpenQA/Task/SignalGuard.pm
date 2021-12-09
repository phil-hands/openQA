# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

package OpenQA::Task::SignalGuard;
use Mojo::Base -base, -signatures;
use Scalar::Util qw(weaken);

# whether the retry is enabled, set to a falsy value to keep the job running
# despite receiving signals
# note: It makes sense to disable the retry right before the job would terminate anyways, e.g.
#       before spawning follow-up jobs. This is useful to prevent spawning an incomplete set of
#       follow-up jobs.
has retry => 1;

# retries the specified Minion job when receiving SIGTERM/SIGINT as long as the returned object exists
# note: Prevents the job to fail with "Job terminated unexpectedly".
sub new ($class, $job, @attributes) {
    my $self = $class->SUPER::new(@attributes);
    $self->{_job} = $job;
    $self->{_old_term_handler} = $SIG{TERM};
    $self->{_old_int_handler} = $SIG{INT};

    # assign closure to global signal handlers using a weak reference to $self so DESTROY will still run
    my $self_weak = $self;
    weaken $self_weak;
    $SIG{TERM} = $SIG{INT} = sub ($signal) { _handle_signal($self_weak, $signal) };
    return $self;
}

sub _handle_signal ($self_weak, $signal) {
    # do nothing if the job is supposed to be concluded despite receiving a signal at this point
    my $job = $self_weak->{_job};
    return $job->note(signal_handler => "Received signal $signal, concluding") unless $self_weak->retry;

    # schedule a retry before stopping the job's execution prematurely
    $job->note(signal_handler => "Received signal $signal, scheduling retry and releasing locks");
    $job->retry;
    exit;
}

sub DESTROY ($self) {
    $SIG{TERM} = $self->{_old_term_handler};
    $SIG{INT} = $self->{_old_int_handler};
}

1;
