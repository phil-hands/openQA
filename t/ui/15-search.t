#!/usr/bin/env perl
# Copyright (C) 2020 SUSE LLC
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

use Test::Mojo;
use Test::Warnings ':report_warnings';

use FindBin;
use lib "$FindBin::Bin/../lib", "$FindBin::Bin/../../external/os-autoinst-common/lib";
use OpenQA::Test::TimeLimit '20';
use OpenQA::Test::Case;
use OpenQA::Client;

use OpenQA::SeleniumTest;

OpenQA::Test::Case->new->init_data(skip_fixtures => 1);

plan skip_all => $OpenQA::SeleniumTest::drivermissing unless my $driver = call_driver;

my $t = Test::Mojo->new('OpenQA::WebAPI');
# we need to talk to the phantom instance or else we're using wrong database
my $url = 'http://localhost:' . OpenQA::SeleniumTest::get_mojoport;

subtest 'Perl modules' => sub {
    my $search = $driver->find_element_by_id('global-search');
    $search->click();
    is $search->get_text(), '', 'empty search entry by default';

    $search->send_keys('timezone');
    $search->send_keys(Selenium::Remote::WDKeys->KEYS->{'enter'});
    wait_for_element(selector => '#results .list-group-item');

    like $driver->get_title(), qr/Search/, 'search shown' or return;
    my $header  = $driver->find_element_by_id('results-heading');
    my $results = $driver->find_element_by_id('results');
    my @entries = $results->children('.list-group-item');
    is $header->get_text(), 'Search results: ' . scalar @entries . ' matches found', 'number of results in header';
    is scalar @entries, 2, '2 elements' or return;

    my $first = $entries[0];
    is $first->child('.occurrence')->get_text(), 'opensuse/tests/installation/installer_timezone.pm',
      'expected occurrence';

    my $second = $entries[1];
    is $second->child('.occurrence')->get_text(), 'opensuse/tests/installation/installer_timezone.pm',
      'expected occurrence';
    is $second->child('.contents')->get_text(),
      qq{    3 # Summary: Verify timezone settings page\n}
      . qq{   11     assert_screen "inst-timezone", 125 || die 'no timezone';},
      'expected contents';
};

END { kill_driver() }
done_testing();
