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
use lib "$FindBin::Bin/lib", "$FindBin::Bin/../external/os-autoinst-common/lib";
use OpenQA::Test::TimeLimit '6';
use Test::Exception;
use Test::Output 'combined_like';
use OpenQA::Script::CloneJob;
use Mojo::URL;
use Mojo::File 'tempdir';

# define fake client
{
    package Test::FakeLWPUserAgentMirrorResult;
    use Mojo::Base -base;
    has is_success => 1;
    has code       => 304;
}
{
    package Test::FakeLWPUserAgent;
    use Mojo::Base -base;
    has mirrored => sub { [] };
    sub mirror {
        my $self = shift;
        push(@{$self->mirrored}, @_);
        return Test::FakeLWPUserAgentMirrorResult->new;
    }
}

my @argv           = qw(WORKER_CLASS=local HDD_1=new.qcow2 HDDSIZEGB=40);
my %options        = ('parental-inheritance' => '');
my %child_settings = (
    NAME         => '00000810-sle-15-Installer-DVD-x86_64-Build665.2-hpc_test@64bit',
    TEST         => 'hpc_test',
    HDD_1        => 'sle-15-x86_64-Build665.2-with-hpc.qcow2',
    HDDSIZEGB    => 20,
    WORKER_CLASS => 'qemu_x86_64',
);
my %parent_settings = (
    NAME         => '00000810-sle-15-Installer-DVD-x86_64-Build665.2-create_hpc@64bit',
    TEST         => 'create_hpc',
    HDD_1        => 'sle-15-x86_64-Build665.2-with-hpc.qcow2',
    HDDSIZEGB    => 20,
    WORKER_CLASS => 'qemu_x86_64',
);

subtest 'clone job apply settings tests' => sub {
    my %test_settings = %child_settings;
    $test_settings{HDD_1}        = 'new.qcow2';
    $test_settings{HDDSIZEGB}    = 40;
    $test_settings{WORKER_CLASS} = 'local';
    $test_settings{is_clone_job} = 1;
    delete $test_settings{NAME};
    clone_job_apply_settings(\@argv, 0, \%child_settings, \%options);
    is_deeply(\%child_settings, \%test_settings, 'cloned child job with correct global setting and new settings');

    %test_settings               = %parent_settings;
    $test_settings{WORKER_CLASS} = 'local';
    $test_settings{is_clone_job} = 1;
    delete $test_settings{NAME};
    clone_job_apply_settings(\@argv, 1, \%parent_settings, \%options);
    is_deeply(\%parent_settings, \%test_settings, 'cloned parent job only take global setting');
};

subtest '_GROUP and _GROUP_ID override each other' => sub {
    my %settings = ();
    clone_job_apply_settings([qw(_GROUP=foo _GROUP_ID=bar)], 0, \%settings, \%options);
    is_deeply(\%settings, {_GROUP_ID => 'bar', is_clone_job => 1}, '_GROUP_ID overrides _GROUP');
    %settings = ();
    clone_job_apply_settings([qw(_GROUP_ID=bar _GROUP=foo)], 0, \%settings, \%options);
    is_deeply(\%settings, {_GROUP => 'foo', is_clone_job => 1}, '_GROUP overrides _GROUP_ID');
};

subtest 'delete empty setting' => sub {
    my %settings = ();
    clone_job_apply_settings([qw(ISO_1= ADDONS=)], 0, \%settings, \%options);
    is_deeply(\%settings, {is_clone_job => 1}, 'all empty settings removed');
};

subtest 'asset download' => sub {
    my $temp_assetdir = tempdir;
    my $fake_ua       = Test::FakeLWPUserAgent->new;
    my $remote        = undef;                          # should not be used here (there are no parents)
    my $remote_url    = Mojo::URL->new('http://foo');
    my %options       = (dir => $temp_assetdir);
    my $job_id        = 1;
    my %job           = (
        assets => {
            repo => 'supposed to be skipped',
            iso  => [qw(foo.iso bar.iso)],
        },
    );

    throws_ok {
        clone_job_download_assets($job_id, \%job, $remote, $remote_url, $fake_ua, \%options)
    }
    qr/can't write $temp_assetdir/, 'error because folder does not exist';

    $temp_assetdir->child('iso')->make_path;

    combined_like {
        clone_job_download_assets($job_id, \%job, $remote, $remote_url, $fake_ua, \%options)
    }
    qr{downloading.*http://.*foo.iso.*to.*foo.iso.*downloading.*http://.*bar.iso.*to.*bar.iso}s, 'download logged';
    is_deeply(
        $fake_ua->mirrored,
        [
            "http://foo/tests/$job_id/asset/iso/foo.iso", "$temp_assetdir/iso/foo.iso",
            "http://foo/tests/$job_id/asset/iso/bar.iso", "$temp_assetdir/iso/bar.iso",
        ],
        'assets downloadeded'
    ) or diag explain $fake_ua->mirrored;
    ok(-f "$temp_assetdir/iso/foo.iso", 'foo touched');
    ok(-f "$temp_assetdir/iso/bar.iso", 'foo touched');
};

subtest 'get 2 nodes HA cluster with get_deps' => sub {
    my %node1_settings = (
        NAME          => '00007936-sle-15-SP3-Online-x86_64-Build67.1-sles4sap_hana_node01@64bit-sap',
        TEST          => 'sles4sap_hana_node01',
        HDD_1         => 'SLE-15-SP3-x86_64-Build67.1-sles4sap-gnome.qcow2',
        HDDSIZEGB     => 60,
        PARALLEL_WITH => 'sles4sap_hana_supportserver@64bit-2gbram',
        NICTYPE       => 'tap',
        WORKER_CLASS  => 'tap,qemu_x86_64',
    );
    my %node2_settings = (
        NAME          => '00007935-sle-15-SP3-Online-x86_64-Build67.1-sles4sap_hana_node02@64bit-sap',
        TEST          => 'sles4sap_hana_node02',
        HDD_1         => 'SLE-15-SP3-x86_64-Build67.1-sles4sap-gnome.qcow2',
        HDDSIZEGB     => 60,
        PARALLEL_WITH => 'sles4sap_hana_supportserver@64bit-2gbram',
        NICTYPE       => 'tap',
        WORKER_CLASS  => 'tap,qemu_x86_64',
    );
    my %supportserver_settings = (
        NAME         => "00007934-sle-15-SP3-Online-x86_64-Build67.1-sles4sap_hana_supportserver@64bit-2gbram",
        TEST         => 'sles4sap_hana_supportserver',
        HDD_1        => 'openqa_support_server_sles12sp3.x86_64.qcow2',
        HDDSIZEGB    => 60,
        NICTYPE      => 'tap',
        WORKER_CLASS => 'tap,qemu_x86_64',
    );
    my %node1_job = (
        settings => \%node1_settings,
        id       => 7936,
        parents  => {
            Parallel => [7934],
        },
    );
    my %node2_job = (
        settings => \%node2_settings,
        id       => 7935,
        parents  => {
            Parallel => [7934],
        },
    );
    my %supportserver_job = (
        settings => \%supportserver_settings,
        id       => 7934,
        children => {
            Parallel => [7935, 7936],
        },
    );
    my ($chained, $directly_chained, $parallel)
      = OpenQA::Script::CloneJob::get_deps(\%supportserver_job, \%options, 'children');
    is_deeply($parallel, [7935, 7936], 'getting children nodes jobid from supportserver');
    ($chained, $directly_chained, $parallel) = OpenQA::Script::CloneJob::get_deps(\%node1_job, \%options, 'parents');
    is_deeply($parallel, [7934], 'getting supportserver jobid from node1');
    ($chained, $directly_chained, $parallel) = OpenQA::Script::CloneJob::get_deps(\%node2_job, \%options, 'parents');
    is_deeply($parallel, [7934], 'getting supportserver jobid from node2');
};

done_testing();
