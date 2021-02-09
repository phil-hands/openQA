# Copyright (C) 2020 LLC
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

package OpenQA::Schema::ResultSet::Comments;

use strict;
use warnings;

use base 'DBIx::Class::ResultSet';

use OpenQA::App;
use OpenQA::Utils;

=over 4

=item referenced_bugs()

Return a hashref of all bugs referenced by job comments.

=back

=cut

sub referenced_bugs {
    my ($self) = @_;

    my $comments = $self->search({-not => {job_id => undef}});
    my %bugrefs  = map { $_ => 1 } map { @{find_bugrefs($_->text)} } $comments->all;
    return \%bugrefs;
}

1;
