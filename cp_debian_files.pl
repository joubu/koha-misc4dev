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

my $koha_dir   = '/home/vagrant/kohaclone';
my $gitify_dir = '/home/vagrant/gitify';
my $instance   = 'kohadev';

GetOptions(
    'koha_dir=s'   => \$koha_dir,
    'gitify_dir=s' => \$gitify_dir,
    'instance=s'   => \$instance,
);

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

my $system_files_mapping = {
    'koha-common.bash-completion' => '/etc/bash_completion.d/koha-common',
    'koha-common.cron.d'          => '/etc/cron.d/koha-common',
    'koha-common.cron.daily'      => '/etc/cron.daily/koha-common',
    'koha-common.cron.hourly'     => '/etc/cron.hourly/koha-common',
    'koha-common.cron.monthly'    => '/etc/cron.monthly/koha-common',
    'koha-common.default'         => '/etc/default/koha-common',
    'koha-common.init'            => '/etc/init.d/koha-common',
    'koha-common.logrotate'       => '/etc/logrotate.d/koha-common'
};

foreach my $debian_file ( keys %{ $system_files_mapping } ) {
    my $cmd = "sudo cp $koha_dir/debian/$debian_file " . $system_files_mapping->{ $debian_file };
    run( command => $cmd, verbose => 1 );
}

run( command => "sudo xsltproc --output /usr/share/man/man8/ /usr/share/xml/docbook/stylesheet/docbook-xsl/manpages/docbook.xsl $koha_debian_dir/docs/*.xml", verbose => 1 );
run( command => "sudo rm /usr/share/man/man8/koha-*.8.gz", verbose => 1 );
run( command => "sudo gzip /usr/share/man/man8/koha-*.8", verbose => 1 );

# Update *-git.conf apache files
run( command => "sudo cp $koha_dir/debian/templates/apache-shared*.conf /etc/koha/" );
run( command => "sudo rm /etc/koha/apache-shared-opac-git.conf /etc/koha/apache-shared-intranet-git.conf" );
run( command => "cd $gitify_dir; sudo ./koha-gitify $instance $koha_dir" );

run( command => "sudo chown -R $instance-koha:$instance-koha /etc/koha/sites/$instance" );

exit(0);
