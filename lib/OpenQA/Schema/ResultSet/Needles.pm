# Copyright (C) 2018-2020 LLC
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

package OpenQA::Schema::ResultSet::Needles;

use strict;
use warnings;

use base 'DBIx::Class::ResultSet';

use OpenQA::Schema::Result::Needles;
use OpenQA::Schema::Result::NeedleDirs;
use DateTime::Format::Pg;

sub find_needle {
    my ($self, $needledir, $needlename) = @_;
    return $self->find({filename => $needlename, 'directory.path' => $needledir}, {join => 'directory'});
}

# updates needle information with data from needle editor
sub update_needle_from_editor {
    my ($self, $needledir, $needlename, $needlejson, $job) = @_;

    # create containing dir if not present yet
    my $dir = $self->result_source->schema->resultset('NeedleDirs')->find_or_new(
        {
            path => $needledir
        });
    if (!$dir->in_storage) {
        $dir->set_name_from_job($job);
        $dir->insert;
    }

    # create/update the needle
    my $needle = $self->find_or_create(
        {
            filename => "$needlename.json",
            dir_id   => $dir->id,
        },
        {
            key => 'needles_dir_id_filename'
        });
    $needle->update(
        {
            tags         => $needlejson->{tags},
            last_updated => $needle->t_updated,
        });
    return $needle;
}

sub new_needles_since {
    my ($self, $since, $tags, $row_limit) = @_;

    my %new_needle_conds = (
        last_updated => {'>=' => DateTime::Format::Pg->format_datetime($since)},
        file_present => 1,
    );
    if ($tags && @$tags) {
        my @tags_conds;
        for my $tag (@$tags) {
            push(@tags_conds, \["? = ANY (tags)", $tag]);
        }
        $new_needle_conds{-or} = \@tags_conds;
    }

    my %new_needle_params = (
        order_by => {-desc => [qw(me.last_updated me.t_created me.id)]},
        prefetch => ['directory'],
    );
    $new_needle_params{rows} = $row_limit if ($row_limit);

    return $self->search(\%new_needle_conds, \%new_needle_params);
}

1;
