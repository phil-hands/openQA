# Copyright (C) 2018-2020 SUSE LLC
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
# You should have received a copy of the GNU General Public License

use Test::Most;

use FindBin;
use lib "$FindBin::Bin/lib", "$FindBin::Bin/../external/os-autoinst-common/lib";
use OpenQA::Test::TimeLimit '6';

use Test::Mojo;
use Test::MockModule;
use Test::MockObject;
use Test::Output;
use Test::Warnings ':report_warnings';
use OpenQA::WebAPI;
use OpenQA::Test::Case;
use OpenQA::Script::Client;

subtest 'client instantiation prevented from the daemons itself' => sub {
    OpenQA::WebSockets::Client::mark_current_process_as_websocket_server;
    throws_ok(
        sub {
            OpenQA::WebSockets::Client->singleton;
        },
        qr/is forbidden/,
        'can not create ws server client from ws server itself'
    );

    OpenQA::Scheduler::Client::mark_current_process_as_scheduler;
    throws_ok(
        sub {
            OpenQA::Scheduler::Client->singleton;
        },
        qr/is forbidden/,
        'can not create scheduler client from scheduler itself'
    );
};

is prepend_api_base('jobs'),      '/api/v1/jobs', 'API base prepended';
is prepend_api_base('/my_route'), '/my_route',    'API base not prepended for absolute paths';
throws_ok sub { run }, qr/Need \@args/, 'needs arguments parsed from command line';

my %options      = (verbose => 1);
my $client_mock  = Test::MockModule->new('OpenQA::UserAgent');
my $code         = 200;
my $content_type = 'application/json';
my $headers_mock = Test::MockObject->new()->set_bound(content_type => \$content_type);
my $json         = {my => 'json'};
my $code_mock    = Test::MockObject->new()->set_bound(code => \$code)->mock(headers => sub { $headers_mock })
  ->set_always(json => $json)->set_always(body => 'my: yaml');
my $res = Test::MockObject->new()->mock(res => sub { $code_mock });
$client_mock->redefine(
    new => sub {
        Test::MockObject->new()->mock(get => sub { $res });
    });

is run(\%options, qw(jobs)),     $json, 'returns job data';
is run(\%options, qw(jobs GeT)), $json, 'method can be passed (case in-sensitive)';

is run({%options, 'json-output' => 1}, qw(jobs)), $json, 'returns job data in json mode';
is run({%options, 'yaml-output' => 1}, qw(jobs)), $json, 'returns job data in yaml mode';
$content_type = 'text/yaml';
Test::MockModule->new('OpenQA::Script::Client')->redefine(load_yaml => undef);
is run(\%options, qw(jobs)), $json, 'returns job data for YAML';
is run({%options, 'json-output' => 1}, qw(jobs)), $json, 'returns job data in json mode for YAML';
is run({%options, 'yaml-output' => 1}, qw(jobs)), $json, 'returns job data in yaml mode for YAML';

$code = 201;
$code_mock->{error} = {message => 'created'};
my $ret;
stderr_like { $ret = run(\%options, qw(jobs post test=foo)) } qr/$code.*created/, 'Codes reported';
is $ret, $json, 'can create job';
$code = 404;
$code_mock->{error} = {message => 'Not Found'};
sub wrong_call { $ret = run(\%options, qw(unknown)) }
stderr_like \&wrong_call, qr/$code.*Not Found/, 'Error reported';
is $ret, undef, 'undef shows error';
$options{json} = 1;
stderr_like \&wrong_call, qr/$code.*Not Found/, 'Error reported for undocumented "json" parameter';
is $ret, undef, 'undef shows error for undocumented parameter';

done_testing();
