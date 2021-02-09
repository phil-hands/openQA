# Copyright (C) 2014-2020 SUSE LLC
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
use Test::Warnings ':report_warnings';
use OpenQA::Test::TimeLimit '10';
use OpenQA::Test::Case;

OpenQA::Test::Case->new->init_data(fixtures_glob => '01-jobs.pl 04-products.pl');

use OpenQA::SeleniumTest;

my $t = Test::Mojo->new('OpenQA::WebAPI');
plan skip_all => $OpenQA::SeleniumTest::drivermissing unless my $driver = call_driver;

ok $driver->get('/tests?groupid=0'), 'list jobs without group';
wait_for_ajax(msg => 'wait for test list without group');
my @rows = $driver->find_child_elements($driver->find_element('#scheduled tbody'), 'tr');
is @rows, 1, 'one scheduled job without group';

ok $driver->get('/tests?groupid=1001'), 'list jobs with group 1001';
wait_for_ajax(msg => 'wait for test list with one group');
@rows = $driver->find_child_elements($driver->find_element('#running tbody'), 'tr');
is @rows, 1, 'one running job with this group';
ok $driver->find_element('#running #job_99963'), '99963 listed';

kill_driver;
done_testing;
