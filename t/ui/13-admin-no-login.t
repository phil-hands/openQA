#!/usr/bin/env perl
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
# You should have received a copy of the GNU General Public License along
# with this program; if not, see <http://www.gnu.org/licenses/>.

use Test::Most;

use FindBin;
use lib "$FindBin::Bin/../lib", "$FindBin::Bin/../../external/os-autoinst-common/lib";

use Test::Warnings ':report_warnings';
use OpenQA::Test::TimeLimit '18';
use OpenQA::Test::Case;
use OpenQA::SeleniumTest;

my $test_case = OpenQA::Test::Case->new;
$test_case->init_data(fixtures_glob => '01-jobs.pl 02-workers.pl 04-products.pl');

plan skip_all => $OpenQA::SeleniumTest::drivermissing unless my $driver = call_driver;

$driver->title_is('openQA');

subtest 'Test suites without login' => sub {
    is $driver->get('/admin/test_suites'), 1, 'opened test suites';
    $driver->title_is('openQA: Test suites');
    wait_for_ajax(msg => 'Wait for test suites table');
    like($driver->find_element('#test-suites tbody tr:nth-child(2) td')->get_text(), qr/advanced_kde/, '2nd entry');
    like($driver->find_element('#test-suites tbody tr:nth-child(5) td')->get_text(), qr/kde/,          '5th entry');
    my $description = $driver->find_element('#test-suites tbody tr:nth-child(5) td:nth-child(3)')->get_text();
    like($description, qr/Simple kde test, before advanced_kde/, '5th entry has a description');
    like($driver->find_element('#test-suites tbody tr:last-child td')->get_text(), qr/textmode/, 'last entry');
};

subtest 'Test suites can be searched' => sub {
    $driver->get('/admin/test_suites?q=client2');
    wait_for_ajax(msg => 'Wait for test suites table search result');
    like($driver->find_element('#test-suites tbody tr:first-child td')->get_text(), qr/client2/, 'first entry');
};

subtest Products => sub {
    $driver->get('/admin/products');
    wait_for_ajax(msg => 'Wait for products table');
    like($driver->find_element('#products tbody tr:first-child td')->get_text(), qr/opensuse/, 'first product entry');

    $driver->get('/admin/products?q=sle');
    wait_for_ajax(msg => 'Wait for products table search result');
    like($driver->find_element('#products tbody tr:first-child td')->get_text(), qr/sle/, 'product search entry');
};

subtest Machines => sub {
    $driver->get('/admin/machines');
    wait_for_ajax(msg => 'Wait for machines table');
    like($driver->find_element('#machines tbody tr:first-child td')->get_text(), qr/32bit/, 'first machine entry');

    $driver->get('/admin/machines?q=laptop');
    wait_for_ajax(msg => 'Wait for machines table search result');
    like($driver->find_element('#machines tbody tr:first-child td')->get_text(), qr/Laptop_64/, 'machine search entry');
};

kill_driver();
done_testing();
