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
use Data::Dumper;

my $iterations = 5;

my @versions = qw( 16.11 17.05 17.11 18.05 18.11 19.05 19.11 20.05 20.11 );
our $koha_root = q|/kohadevbox/koha|;
my $git_remote = q|gitlab|;
our $verbose = 0;
our $kohadev = q|kohadev|;
our $output_dir = q|/tmp|;

our ( $cmd, $success, $error_code, $full_buf, $stdout_buf, $stderr_buf );
our $PERL5LIB = $ENV{PERL5LIB};

chdir $koha_root;

for my $version ( @versions ) {
    msg("Version $version", 5);
    my $branch_name = qq|perf_${version}.x|;
    $cmd = "git rev-parse --verify $branch_name";
    ( $success, $error_code, $full_buf, $stdout_buf, $stderr_buf ) = run( command => $cmd, verbose => 0 );
    $cmd = $success
        ? "git checkout $branch_name"
        : "git checkout -b $branch_name $git_remote/$branch_name";
    ( $success, $error_code, $full_buf, $stdout_buf, $stderr_buf ) = run( command => $cmd, verbose => $verbose );

    die "Fail to create a local branch ($branch_name) from repo '$git_remote'. Make sure it exists" unless $success;

    my @output = do_all_iterations();
    write_output( $version, @output );
}

sub reset_my_db {
    my $mysql_auth_file=q|/etc/mysql/koha_kohadev.cnf|;
    $cmd = qq|mysql --defaults-file=$mysql_auth_file -e"DROP DATABASE koha_kohadev"|;
    ( $success, $error_code, $full_buf, $stdout_buf, $stderr_buf ) = run( command => $cmd, verbose => $verbose );
    $cmd = qq|mysql --defaults-file=$mysql_auth_file -e"CREATE DATABASE koha_kohadev"|;
    ( $success, $error_code, $full_buf, $stdout_buf, $stderr_buf ) = run( command => $cmd, verbose => $verbose );
    $cmd = q|KOHA_ELASTICSEARCH=0 perl /kohadevbox/misc4dev/do_all_you_can_do.pl \
        --instance kohadev \
        --userid koha \
        --password koha \
        --marcflavour MARC21 \
        --koha_dir /kohadevbox/koha \
        --opac-base-url http://koha:8080 \
        --intranet-base-url http://koha:8081 \
        --gitify_dir /kohadevbox/gitify
    |;
    ( $success, $error_code, $full_buf, $stdout_buf, $stderr_buf ) = run( command => $cmd, verbose => $verbose );
    die Dumper $full_buf unless $success;
}

sub restart_memcached {
    system(q{flush_memcached});
}
sub restart_plack {
    $cmd = qq|sudo koha-plack --restart $kohadev|;
    run( command => $cmd, verbose => $verbose );
}
sub restart_apache {
    $cmd = qq|sudo service apache2 restart|;
    run( command => $cmd, verbose => $verbose );
}

sub do_all_iterations {
    msg("Reset the database", 3);
    reset_my_db();
    msg("Restart memcached", 3);
    restart_memcached();
    restart_apache();
    restart_plack();
    my ( @output, $output );
    msg("First shoot to populate caches", 3);
    do_one_iteration();
    for my $i ( 1 .. $iterations ) {
        msg("Processing Iteration $i/$iterations", 3);
        $output = do_one_iteration();
        push @output, @$output;
    }
    return @output;
}

sub do_one_iteration {
    $cmd = qq|koha-shell $kohadev -p -c "perl t/db_dependent/selenium/basic_workflow.t"|;
    ( $success, $error_code, $full_buf, $stdout_buf, $stderr_buf ) = run( command => $cmd, verbose => $verbose );
    warn Dumper $full_buf;
    die Dumper $full_buf unless $success;
    return $stderr_buf;
}

sub msg {
    my ( $msg, $level ) = @_;
    $level //= 1;
    say   "=" x $level
        . " $msg "
        . "=" x $level;
}

sub write_output {
    my ( $filename, @output ) = @_;
    my $filepath = "$output_dir/$filename.txt";
    open my $fh, '>', $filepath or die "Cannot write output to $filepath ($!)";
    print $fh join "", @output;
    close $fh;
}

exit(0);
