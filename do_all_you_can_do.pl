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

use C4::Context;
use Koha;

my $instance;
my $userid;
my $password;
my $koha_dir;
my $elasticsearch;
my $gitify_dir;
my $opac_base_url;
my $intranet_base_url;
my $marcflavour = 'MARC21';
my $use_existing_db;

GetOptions(
    'elasticsearch'       => \$elasticsearch,
    'gitify_dir=s'        => \$gitify_dir,
    'instance=s'          => \$instance,
    'intranet-base-url=s' => \$intranet_base_url,
    'koha_dir=s'          => \$koha_dir,
    'marcflavour=s'       => \$marcflavour,
    'opac-base-url=s'     => \$opac_base_url,
    'password=s'          => \$password,
    'userid=s'            => \$userid,
    'use-existing-db'     => \$use_existing_db,
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

my $shared_dir = "$koha_dir/shared";

$marcflavour = uc($marcflavour);

if (     $marcflavour ne 'MARC21'
     and $marcflavour ne 'UNIMARC' ) {
    die "Invalid MARC flavour '$marcflavour' passed.";
}

my $misc_dir = dirname( abs_path( $0 ) );

my ( $cmd, $success, $error_code, $full_buf, $stdout_buf, $stderr_buf );
my $PERL5LIB = $ENV{PERL5LIB};
my $PATH     = $ENV{PATH};

my $dbh = C4::Context->dbh; # At the beginning to die if DB does not exist.

my $HandleError = $dbh->{HandleError};
$dbh->{HandleError} = sub { return 1 };

my ( $prefs_count ) = $dbh->selectrow_array(q|SELECT COUNT(*) FROM systempreferences|);
my ( $patrons_count ) = $dbh->selectrow_array(q|SELECT COUNT(*) FROM borrowers|);
my $db_exists = $prefs_count || $patrons_count;
warn "db_exists=$db_exists";
warn "use_existing_db=$use_existing_db";
if ( $db_exists && ! $use_existing_db ) {
    die "Database is not empty!";
} elsif ( !$db_exists ) {
    $use_existing_db = 0;
}
warn "use_existing_db=$use_existing_db";
$dbh->disconnect;
$ENV{KOHA_DB_DO_NOT_RAISE_OR_PRINT_ERROR} = 0;

# Populate the DB with Koha sample data
unless ( $use_existing_db ) {
    $cmd = "sudo koha-shell $instance -p -c 'PERL5LIB=$PERL5LIB perl $misc_dir/populate_db.pl -v --opac-base-url $opac_base_url --intranet-base-url $intranet_base_url --marcflavour $marcflavour'";
    ( $success, $error_code, $full_buf, $stdout_buf, $stderr_buf ) = run( command => $cmd, verbose => 1 );
    exit(1) unless $success;

    # Create a superlibrarian user
    $cmd = "sudo koha-shell $instance -p -c 'PERL5LIB=$PERL5LIB perl $misc_dir/create_superlibrarian.pl $create_superlibrarian_opts'";
    ( $success, $error_code, $full_buf, $stdout_buf, $stderr_buf ) = run( command => $cmd, verbose => 1 );
    exit(1) unless $success;

    # Insert bibliographic, authority records, and items
    $cmd = "sudo koha-shell $instance -c 'PERL5LIB=$PERL5LIB perl $misc_dir/insert_data.pl --marcflavour $marcflavour'";
    ( $success, $error_code, $full_buf, $stdout_buf, $stderr_buf ) = run( command => $cmd, verbose => 1 );
    exit(1) unless $success;

    # Insert the custom SQL queries if shared/custom.sql exists
    if ( -f "$shared_dir/custom.sql" ) {
        $cmd = "sudo koha-mysql $instance < $shared_dir/custom.sql";
        ( $success, $error_code, $full_buf, $stdout_buf, $stderr_buf ) = run( command => $cmd, verbose => 1 );
        exit(1) unless $success;
    } else {
        say "There is no custom.sql ($shared_dir/custom.sql) file, skipping."
    }
} else {
    say "Reusing existing database";
}

# Copy debian files
$cmd = "sudo perl $misc_dir/cp_debian_files.pl --instance=$instance --koha_dir=$koha_dir --gitify_dir=$gitify_dir";
( $success, $error_code, $full_buf, $stdout_buf, $stderr_buf ) = run( command => $cmd, verbose => 1 );
exit(1) unless $success;

# Setup SIP
$cmd = "PERL5LIB=$PERL5LIB perl $misc_dir/setup_sip.pl --instance=$instance";
( $success, $error_code, $full_buf, $stdout_buf, $stderr_buf ) = run( command => $cmd, verbose => 1 );
exit(1) unless $success;

# Regenerate Plack psgi files
$cmd = "PERL5LIB=$PERL5LIB perl $misc_dir/reset_plack.pl --koha_dir=$koha_dir --instance=$instance";
( $success, $error_code, $full_buf, $stdout_buf, $stderr_buf ) = run( command => $cmd, verbose => 1 );
exit(1) unless $success;

# Restart Apache
$cmd = "sudo service apache2 restart";
( $success, $error_code, $full_buf, $stdout_buf, $stderr_buf ) = run( command => $cmd, verbose => 1 );
exit(1) unless $success;

my $version = get_version();
$version =~ s|\.||g;
if ( $version >= 220600079 ) {
    $cmd = "sudo koha-shell $instance -c '(cd $koha_dir ; PATH=$PATH yarn build_js)'";
    ( $success, $error_code, $full_buf, $stdout_buf, $stderr_buf ) = run( command => $cmd, verbose => 1 );
    exit(1) unless $success;
}

# Rebuild Elastic
if ($elasticsearch) {
    my $rebuild_es_path =
      -e "$koha_dir/misc/search_tools/rebuild_elastic_search.pl"
       ? "$koha_dir/misc/search_tools/rebuild_elastic_search.pl"
       : "$koha_dir/misc/search_tools/rebuild_elasticsearch.pl"; # See "Bug 21872: Fix name of rebuild_elasticsearch.pl"
    $cmd = "sudo koha-shell $instance -p -c 'PERL5LIB=$PERL5LIB perl $rebuild_es_path -v'";
    ( $success, $error_code, $full_buf, $stdout_buf, $stderr_buf ) = run( command => $cmd, verbose => 1 );
    exit(1) unless $success;

    $cmd = qq|koha-mysql $instance -e 'UPDATE systempreferences SET value="Elasticsearch" WHERE variable="SearchEngine"'|;
    ( $success, $error_code, $full_buf, $stdout_buf, $stderr_buf ) = run( command => $cmd, verbose => 1 );
    exit(1) unless $success;
} else {
    $cmd = qq|koha-mysql $instance -e 'UPDATE systempreferences SET value="Zebra" WHERE variable="SearchEngine"'|;
    ( $success, $error_code, $full_buf, $stdout_buf, $stderr_buf ) = run( command => $cmd, verbose => 1 );
    exit(1) unless $success;
}

# Rebuild Zebra
# Assuming you can still change the search engine to Zebra even if set initially to elastic
$cmd = "sudo koha-rebuild-zebra -f -v $instance";
( $success, $error_code, $full_buf, $stdout_buf, $stderr_buf ) = run( command => $cmd, verbose => 1 );
exit(1) unless $success;

exit(0);

sub get_version {
    my $version = $Koha::VERSION;
    $version =~ s/(\d)\.(\d{2})\.(\d{2})\.(\d{3})/$1.$2$3$4/;
    return $version;
}
