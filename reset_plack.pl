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
    my $psgi_filepath = qq|/etc/koha/sites/$instance/plack.psgi|;
    `sudo cp $koha_dir/debian/templates/plack.psgi $psgi_filepath`;
    `sudo perl -p -i -e s#/usr/share/koha/intranet/cgi-bin#$koha_dir# $psgi_filepath`;
    `sudo perl -p -i -e s#/usr/share/koha/lib#$koha_dir# $psgi_filepath`;
    `sudo perl -p -i -e s#/usr/share/koha/opac/cgi-bin/opac#$koha_dir/opac# $psgi_filepath`;
    `sudo koha-plack --restart $instance`;
    unless ( qx{git -C $koha_dir log --oneline | grep "Bug 18137: Migrate from Swagger2 to Mojolicious::Plugin::OpenAPI" } ) {
        # This is a bit hacky, we want to comment the api line if 18137 is not applied
        my $fh;
        open($fh, '-|', 'sudo', 'cat', $psgi_filepath) or die "Unable to open pipe: $!\n";
        my $inside_api_block;
        my @lines;
        while ( my $line = <$fh> ) {
            chomp $line;
            if ( $line =~ m|^my \$api| ) {
                $inside_api_block = 1;
            }
            if ( $line =~ m|mount.*\$api| ) { # mount '/api/v1/app.pl' => $apiv1;
                $line =~ s|^|#|; # Comment out the block
            }
            if ( $inside_api_block ) {
                $inside_api_block = 0 if $line =~ m|^};|; # End of block
                $line =~ s|^|#|; # Comment out the block
            }
            push @lines, $line;
        }
        close $fh;
        open($fh, '|-', 'sudo', 'tee', $psgi_filepath) or die "Unable to open pipe: $!\n";
        say $fh $_ for @lines;
        close $fh;
    }
    `sudo koha-plack --restart $instance`;
}

exit(0);
