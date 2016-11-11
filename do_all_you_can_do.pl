use Modern::Perl;
use File::Basename qw( dirname );
use Cwd 'abs_path';
use IPC::Cmd qw( run );

my $koha_dir = '/home/vagrant/kohaclone'; # FIXME hardcoded
my $koha_devel_dir = "$koha_dir/misc/devel";
my $misc_dir = dirname( abs_path( $0 ) );

my ( $cmd, $success, $error_code, $full_buf, $stdout_buf, $stderr_buf );
my $PERL5LIB = $ENV{PERL5LIB};

$cmd = "sudo koha-shell kohadev -p -c 'PERL5LIB=$PERL5LIB perl $koha_devel_dir/populate_db.pl -v'";
( $success, $error_code, $full_buf, $stdout_buf, $stderr_buf ) = run( command => $cmd, verbose => 1 );
exit(1) unless $success;
$cmd = "sudo koha-shell kohadev -p -c 'PERL5LIB=$PERL5LIB perl $koha_devel_dir/create_superlibrarian.pl'";
( $success, $error_code, $full_buf, $stdout_buf, $stderr_buf ) = run( command => $cmd, verbose => 1 );
exit(1) unless $success;
$cmd = "sudo koha-shell kohadev -c 'PERL5LIB=$PERL5LIB perl $misc_dir/insert_data.pl'";
( $success, $error_code, $full_buf, $stdout_buf, $stderr_buf ) = run( command => $cmd, verbose => 1 );
exit(1) unless $success;
$cmd = "sudo koha-rebuild-zebra -f -v kohadev";
( $success, $error_code, $full_buf, $stdout_buf, $stderr_buf ) = run( command => $cmd, verbose => 1 );
exit(1) unless $success;
# TODO Add rebuild ES

exit(0);
