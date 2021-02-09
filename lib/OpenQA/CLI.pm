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

package OpenQA::CLI;
use Mojo::Base 'Mojolicious::Commands';

has hint => <<EOF;

See 'openqa-cli help COMMAND' for more information on a specific command.
EOF
has message    => sub { shift->extract_usage . "\nCommands:\n" };
has namespaces => sub { ['OpenQA::CLI'] };

1;

=encoding utf8

=head1 SYNOPSIS

  Usage: openqa-cli COMMAND [OPTIONS]

    # Show api command help with all available options and more examples
    openqa-cli api --help

    # Show details for job from localhost
    openqa-cli api jobs/4160811

    # Show details for job from arbitrary host
    openqa-cli api --host http://openqa.example.com jobs/408

    # Show details for OSD job (prettified JSON)
    openqa-cli api --osd --pretty jobs/4160811

    # Archive job from O3
    openqa-cli archive --o3 408 /tmp/job_408

  Options (for all commands):
        --apibase <path>        API base, defaults to /api/v1
        --apikey <key>          API key
        --apisecret <secret>    API secret
        --host <host>           Target host, defaults to http://localhost
    -h, --help                  Get more information on a specific command
        --osd                   Set target host to http://openqa.suse.de
        --o3                    Set target host to https://openqa.opensuse.org

=cut
