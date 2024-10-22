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

use Cwd 'abs_path';
use File::Basename qw( dirname );
use Getopt::Long;
use IPC::Cmd qw( run );

my ( $koha_dir );
my $instance   = 'kohadev';

GetOptions(
    'koha_dir=s'   => \$koha_dir,
);

die "Missing mandatory option 'koha_dir'"   unless $koha_dir;

my $cmd = qq{cp -r $koha_dir/etc/zebradb/marc_defs/* /etc/koha/zebradb/marc_defs/};
run( command => $cmd, verbose => 1 ); 

exit(0);
