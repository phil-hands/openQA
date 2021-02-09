# Copyright (C) 2019-2020 SUSE LLC
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

use FindBin;
use lib "$FindBin::Bin/../lib", "$FindBin::Bin/../../external/os-autoinst-common/lib";
use Test::Mojo;
use OpenQA::Test::TimeLimit '8';
use OpenQA::Test::Database;
use OpenQA::Test::Case;
use Mojo::File qw(tempdir path);
use File::Copy::Recursive 'dircopy';

OpenQA::Test::Case->new->init_data(fixtures_glob => '03-users.pl');

$ENV{OPENQA_CONFIG} = my $tempdir = tempdir;
my $home_template = path(__FILE__)->dirname->dirname->child('data', 'openqa-trigger-from-obs');
my $home          = "$tempdir/openqa-trigger-from-obs";
dircopy($home_template, $home);
$tempdir->child('openqa.ini')->spurt(<<"EOF");
[global]
plugins=ObsRsync
[obs_rsync]
home=$home
EOF

my $t = Test::Mojo->new('OpenQA::WebAPI');

# needs to log in (it gets redirected)
$t->get_ok('/');
my $token = $t->tx->res->dom->at('meta[name=csrf-token]')->attr('content');
$t->get_ok('/login');

BAIL_OUT('Login exit code (' . $t->tx->res->code . ')') if $t->tx->res->code != 302;

$t->post_ok('/admin/obs_rsync/Proj1/runs' => {'X-CSRF-Token' => $token})->status_is(201, "trigger rsync");

$t->get_ok('/admin/obs_rsync/queue')->status_is(200, "jobs list")->content_like(qr/Proj1/);

done_testing();
