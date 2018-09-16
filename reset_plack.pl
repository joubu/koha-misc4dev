#!/usr/bin/perl

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# This program comes with ABSOLUTELY NO WARRANTY;

use Modern::Perl;

use Getopt::Long;

my $koha_dir;
my $instance;

GetOptions(
    'instance=s' => \$instance,
    'koha_dir=s' => \$koha_dir
);

$koha_dir //= '/home/vagrant/kohaclone';
$instance //= 'kohadev';

if ( -f $koha_dir . '/debian/templates/plack.psgi' ) {
    `sudo cp $koha_dir/debian/templates/plack.psgi /etc/koha/sites/$instance/plack.psgi`;
    `sudo perl -p -i -e s#/usr/share/koha/intranet/cgi-bin#$koha_dir# /etc/koha/sites/$instance/plack.psgi`;
    `sudo perl -p -i -e s#/usr/share/koha/lib#$koha_dir# /etc/koha/sites/$instance/plack.psgi`;
    `sudo perl -p -i -e s#/usr/share/koha/opac/cgi-bin/opac#$koha_dir/opac# /etc/koha/sites/$instance/plack.psgi`;
    `sudo koha-plack --restart $instance`;
}

exit(0);
