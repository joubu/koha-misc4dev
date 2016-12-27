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
use File::Basename qw( dirname );
use Cwd 'abs_path';
use IPC::Cmd qw( run );

my $koha_dir = '/home/vagrant/kohaclone'; # FIXME hardcoded
my $koha_debian_dir = "$koha_dir/debian";

open my $fh, '<', $koha_debian_dir . '/koha-common.install' or die "Cannnot open file $!";

while ( my $line = <$fh> ) {
    chomp $line;
    $line =~ s|\s+| |;
    my ( $from, $to ) = split ' ', $line;
    next unless $to; # TODO We could handle that
    next if $from =~ m|/tmp/|;
    next if $from =~ m|/tmp_docbook/|; # Done later
    $to = "/$to";
    my $cmd = "sudo cp $koha_dir/$from $to";
    run( command => $cmd, verbose => 1 );
}

close $fh;

run( command => "sudo xsltproc --output /usr/share/man/man8/ /usr/share/xml/docbook/stylesheet/docbook-xsl/manpages/docbook.xsl $koha_debian_dir/docs/*.xml", verbose => 1 );
run( command => "sudo rm /usr/share/man/man8/koha-*.8.gz", verbose => 1 );
run( command => "sudo gzip /usr/share/man/man8/koha-*.8", verbose => 1 );

exit(0);
