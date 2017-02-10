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

our $koha_root = q|/home/vagrant/kohaclone|;
our $kohadev = q|kohadev|;

if ( -f $koha_root . '/debian/templates/plack.psgi' ) {
    `sudo cp $koha_root/debian/templates/plack.psgi /etc/koha/sites/kohadev/plack.psgi`;
    `sudo perl -p -i -e s#/usr/share/koha/intranet/cgi-bin#/home/vagrant/kohaclone# /etc/koha/sites/kohadev/plack.psgi`;
    `sudo perl -p -i -e s#/usr/share/koha/lib#/home/vagrant/kohaclone# /etc/koha/sites/kohadev/plack.psgi`;
    `sudo perl -p -i -e s#/usr/share/koha/opac/cgi-bin/opac#/home/vagrant/kohaclone/opac# /etc/koha/sites/kohadev/plack.psgi`;
    `sudo koha-plack --restart $kohadev`;
}

exit(0);
