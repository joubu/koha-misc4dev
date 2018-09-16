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

use Getopt::Long;

my $instance;
my $userid;
my $password;
my $koha_dir;
my $elasticsearch;
my $gitify_dir;
my $opac_base_url;
my $intranet_base_url;
my $marcflavour = 'MARC21';

GetOptions(
    'elasticsearch'       => \$elasticsearch,
    'gitify_dir=s'        => \$gitify_dir,
    'instance=s'          => \$instance,
    'intranet-base-url=s' => \$intranet_base_url,
    'koha_dir=s'          => \$koha_dir,
    'marcflavour=s'       => \$marcflavour,
    'opac-base-url=s'     => \$opac_base_url,
    'password=s'          => \$password,
    'userid=s'            => \$userid
);


my $create_superlibrarian_opts = "";
$create_superlibrarian_opts .= "--userid $userid "
	if defined $userid;
$create_superlibrarian_opts .= "--password $password "
	if defined $password;

$instance          //= 'kohadev';
$koha_dir          //= '/home/vagrant/kohaclone';
$opac_base_url     //= 'catalogue.kohadev.vm';
$intranet_base_url //= 'pro.kohadev.vm';
$gitify_dir        //= '/home/vagrant/gitify';

$marcflavour = uc($marcflavour);

if (     $marcflavour ne 'MARC21'
     and $marcflavour ne 'UNIMARC' ) {
    die "Invalid MARC flavour '$marcflavour' passed.";
}

my $misc_dir = dirname( abs_path( $0 ) );

my ( $cmd, $success, $error_code, $full_buf, $stdout_buf, $stderr_buf );
my $PERL5LIB = $ENV{PERL5LIB};

$cmd = "sudo koha-shell $instance -p -c 'PERL5LIB=$PERL5LIB perl $misc_dir/populate_db.pl -v --opac-base-url $opac_base_url --intranet-base-url $intranet_base_url --marcflavour $marcflavour'";
( $success, $error_code, $full_buf, $stdout_buf, $stderr_buf ) = run( command => $cmd, verbose => 1 );
exit(1) unless $success;
$cmd = "sudo koha-shell $instance -p -c 'PERL5LIB=$PERL5LIB perl $misc_dir/create_superlibrarian.pl $create_superlibrarian_opts'";
( $success, $error_code, $full_buf, $stdout_buf, $stderr_buf ) = run( command => $cmd, verbose => 1 );
exit(1) unless $success;
$cmd = "sudo koha-shell $instance -c 'PERL5LIB=$PERL5LIB perl $misc_dir/insert_data.pl --marcflavour $marcflavour'";
( $success, $error_code, $full_buf, $stdout_buf, $stderr_buf ) = run( command => $cmd, verbose => 1 );
exit(1) unless $success;
$cmd = "sudo perl $misc_dir/cp_debian_files.pl --instance=$instance --koha_dir=$koha_dir --gitify_dir=$gitify_dir";
( $success, $error_code, $full_buf, $stdout_buf, $stderr_buf ) = run( command => $cmd, verbose => 1 );
exit(1) unless $success;
$cmd = "PERL5LIB=$PERL5LIB perl $misc_dir/reset_plack.pl";
( $success, $error_code, $full_buf, $stdout_buf, $stderr_buf ) = run( command => $cmd, verbose => 1 );
exit(1) unless $success;
$cmd = "sudo systemctl restart apache2";
( $success, $error_code, $full_buf, $stdout_buf, $stderr_buf ) = run( command => $cmd, verbose => 1 );
exit(1) unless $success;
$cmd = "sudo koha-rebuild-zebra -f -v $instance";
( $success, $error_code, $full_buf, $stdout_buf, $stderr_buf ) = run( command => $cmd, verbose => 1 );
exit(1) unless $success;

if ($elasticsearch) {
    $cmd = "sudo koha-shell $instance -p -c 'PERL5LIB=$PERL5LIB perl $koha_dir/misc/search_tools/rebuild_elastic_search.pl -v'";
    ( $success, $error_code, $full_buf, $stdout_buf, $stderr_buf ) = run( command => $cmd, verbose => 1 );
    exit(1) unless $success;
}

exit(0);
