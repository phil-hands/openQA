#!/usr/bin/env perl
# Copyright (C) 2016-2021 SUSE LLC
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

use Test::Most;

use Mojo::IOLoop;

use FindBin;
use lib "$FindBin::Bin/lib", "$FindBin::Bin/../external/os-autoinst-common/lib";
use OpenQA::Jobs::Constants;
use OpenQA::Test::Client 'client';
use OpenQA::Test::Database;
use OpenQA::Test::TimeLimit '10';
use Test::MockModule;
use Test::Mojo;
use Test::Warnings ':report_warnings';
use Mojo::File qw(tempdir path);
use Mojo::JSON qw(decode_json);
use OpenQA::WebAPI::Plugin::AMQP;

my %published;

my $plugin_mock = Test::MockModule->new('OpenQA::WebAPI::Plugin::AMQP');
$plugin_mock->redefine(
    publish_amqp => sub {
        my ($self, $topic, $data) = @_;
        $published{$topic} = $data;
    });

OpenQA::Test::Database->new->create(fixtures_glob => '01-jobs.pl 03-users.pl 05-job_modules.pl');

# this test also serves to test plugin loading via config file
my @conf    = ("[global]\n", "plugins=AMQP\n");
my $tempdir = tempdir;
$ENV{OPENQA_CONFIG} = $tempdir;
path($ENV{OPENQA_CONFIG})->make_path->child("openqa.ini")->spurt(@conf);

my $t = client(Test::Mojo->new('OpenQA::WebAPI'));

# create a parent group
my $schema        = $t->app->schema;
my $parent_groups = $schema->resultset('JobGroupParents');
$parent_groups->create(
    {
        id   => 2000,
        name => 'test',
    });

my $settings = {
    DISTRI      => 'Unicorn',
    FLAVOR      => 'pink',
    VERSION     => '42',
    BUILD       => '666',
    TEST        => 'rainbow',
    ISO         => 'whatever.iso',
    DESKTOP     => 'DESKTOP',
    KVM         => 'KVM',
    ISO_MAXSIZE => 1,
    MACHINE     => "RainbowPC",
    ARCH        => 'x86_64'
};

# create a job via API
my $job;
subtest 'create job' => sub {
    $t->post_ok("/api/v1/jobs" => form => $settings)->status_is(200);
    ok($job = $t->tx->res->json->{id}, 'got ID of new job');
    is_deeply(
        $published{'suse.openqa.job.create'},
        {
            "ARCH"        => "x86_64",
            "BUILD"       => "666",
            "DESKTOP"     => "DESKTOP",
            "DISTRI"      => "Unicorn",
            "FLAVOR"      => "pink",
            "ISO"         => "whatever.iso",
            "ISO_MAXSIZE" => "1",
            "KVM"         => "KVM",
            "MACHINE"     => "RainbowPC",
            "TEST"        => "rainbow",
            "VERSION"     => "42",
            "group_id"    => undef,
            "id"          => $job,
            "remaining"   => 1
        },
        'job create triggers amqp'
    );
};

subtest 'mark job as done' => sub {
    $t->post_ok("/api/v1/jobs/$job/set_done")->status_is(200);
    is_deeply(
        $published{'suse.openqa.job.done'},
        {
            "ARCH"      => "x86_64",
            "BUILD"     => "666",
            "FLAVOR"    => "pink",
            "ISO"       => "whatever.iso",
            "MACHINE"   => "RainbowPC",
            "TEST"      => "rainbow",
            "bugref"    => undef,
            "group_id"  => undef,
            "id"        => $job,
            "newbuild"  => undef,
            "remaining" => 0,
            "result"    => INCOMPLETE,
            "reason"    => undef,
        },
        'job done triggers amqp'
    );
};

subtest 'mark job with taken over bugref as done' => sub {
    # prepare previous job of 99963 to test carry over
    my $jobs         = $schema->resultset('Jobs');
    my $previous_job = $jobs->find(99962);
    $previous_job->comments->create(
        {
            text    => 'bsc#123',
            user_id => $schema->resultset('Users')->first->id,
        });
    is($previous_job->bugref, 'bsc#123', 'added bugref recognized');

    # mark so far running job 99963 as failed which should trigger bug carry over
    $t->post_ok(
        "/api/v1/jobs/99963/set_done",
        form => {
            result => OpenQA::Jobs::Constants::FAILED
        })->status_is(200);
    is_deeply(
        $published{'suse.openqa.job.done'},
        {
            "ARCH"      => "x86_64",
            "BUILD"     => "0091",
            "FLAVOR"    => "DVD",
            "ISO"       => "openSUSE-13.1-DVD-x86_64-Build0091-Media.iso",
            "MACHINE"   => "64bit",
            "TEST"      => "kde",
            "bugref"    => "bsc#123",
            "bugurl"    => "https://bugzilla.suse.com/show_bug.cgi?id=123",
            "group_id"  => 1001,
            "id"        => 99963,
            "newbuild"  => undef,
            "remaining" => 3,
            "result"    => "failed",
            "reason"    => undef,
        },
        'carried over bugref and resolved URL present in AMQP event'
    );
};

subtest 'duplicate and cancel job' => sub {
    $t->post_ok("/api/v1/jobs/$job/duplicate")->status_is(200);
    my $newjob = $t->tx->res->json->{id};
    is_deeply(
        $published{'suse.openqa.job.restart'},
        {
            id        => $job,
            result    => {$job => $newjob},
            auto      => 0,
            ARCH      => 'x86_64',
            BUILD     => '666',
            FLAVOR    => 'pink',
            ISO       => 'whatever.iso',
            MACHINE   => 'RainbowPC',
            TEST      => 'rainbow',
            bugref    => undef,
            group_id  => undef,
            remaining => 1,
        },
        'job duplicate triggers amqp'
    );

    $t->post_ok("/api/v1/jobs/$newjob/cancel")->status_is(200);
    is_deeply(
        $published{'suse.openqa.job.cancel'},
        {
            "ARCH"      => "x86_64",
            "BUILD"     => "666",
            "FLAVOR"    => "pink",
            "ISO"       => "whatever.iso",
            "MACHINE"   => "RainbowPC",
            "TEST"      => "rainbow",
            "group_id"  => undef,
            "id"        => $newjob,
            "remaining" => 0
        },
        "job cancel triggers amqp"
    );
};

sub assert_common_comment_json {
    my ($json) = @_;
    ok($json->{id}, 'id');
    is($json->{job_id}, undef,   'job id');
    is($json->{text},   'test',  'text');
    is($json->{user},   'perci', 'user');
    ok($json->{created}, 't_created');
    ok($json->{updated}, 't_updated');
}

subtest 'create job group comment' => sub {
    $t->post_ok('/api/v1/groups/1001/comments' => form => {text => 'test'})->status_is(200);
    my $json = $published{'suse.openqa.comment.create'};
    assert_common_comment_json($json);
    is($json->{group_id},        1001,  'job group id');
    is($json->{parent_group_id}, undef, 'parent group id');
};

subtest 'create parent group comment' => sub {
    $t->post_ok('/api/v1/parent_groups/2000/comments' => form => {text => 'test'})->status_is(200);
    my $json = $published{'suse.openqa.comment.create'};
    assert_common_comment_json($json);
    is($json->{group_id},        undef, 'job group id');
    is($json->{parent_group_id}, 2000,  'parent group id');
};

$t->app->config->{amqp}{topic_prefix} = '';

subtest 'publish without topic prefix' => sub {
    $t->post_ok("/api/v1/jobs" => form => $settings)->status_is(200);
    is($published{'openqa.job.create'}->{ARCH}, "x86_64", 'got message with correct topic');
};

# Now let's unmock publish_amqp so we can test it...
$plugin_mock->unmock('publish_amqp');
%published = ();
# ...but we'll mock the thing it calls.
my $publisher_mock = Test::MockModule->new('Mojo::RabbitMQ::Client::Publisher');
$publisher_mock->redefine(
    publish_p => sub {
        # copied from upstream git master as of 2019-07-24
        my $self    = shift;
        my $body    = shift;
        my $headers = {};
        my %args    = ();

        if (ref($_[0]) eq 'HASH') {
            $headers = shift;
        }
        if (@_) {
            %args = (@_);
        }
        # end copying
        $published{body}    = $body;
        $published{headers} = $headers;
        $published{args}    = \%args;
        # we need to return a Promise or stuff breaks
        my $client_promise = Mojo::Promise->new();
        return $client_promise;
    });

# we need an instance of the plugin now. I can't find a documented
# way to access the one that's already loaded...
my $amqp = OpenQA::WebAPI::Plugin::AMQP->new;
$amqp->register($t->app);

subtest 'amqp_publish call without headers' => sub {
    $amqp->publish_amqp('some.topic', 'some message');
    is($published{body}, 'some message', "message body correctly passed");
    is_deeply($published{headers},             {},           "headers is empty hashref");
    is_deeply($published{args}->{routing_key}, 'some.topic', "topic appears as routing key");
};

subtest 'amqp_publish call with headers' => sub {
    %published = ();
    $amqp->publish_amqp('some.topic', 'some message', {'someheader' => 'something'});
    is($published{body}, 'some message', "message body correctly passed");
    is_deeply($published{headers},             {'someheader' => 'something'}, "headers is expected hashref");
    is_deeply($published{args}->{routing_key}, 'some.topic',                  "topic appears as routing key");
};

subtest 'amqp_publish call with incorrect headers' => sub {
    throws_ok(
        sub {
            $amqp->publish_amqp('some.topic', 'some message', 'some headers');
        },
        qr/publish_amqp headers must be a hashref!/,
        'dies on bad headers'
    );
};

subtest 'amqp_publish call with reference as body' => sub {
    %published = ();
    my $body = {"field" => "value"};
    $amqp->publish_amqp('some.topic', $body);
    is($published{body}, $body, "message body kept as ref not encoded by publish_amqp");
    is_deeply($published{args}->{routing_key}, 'some.topic', "topic appears as routing key");
};

done_testing();
