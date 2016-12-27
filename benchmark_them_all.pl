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

my $iterations = 5;

my @versions = qw( 16.11 );
our $koha_root = q|/home/vagrant/kohaclone|;
my $git_remote = q|Joubu|;
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
    write_output( $version . '', @output );

    @output = do_all_iterations( "with_plack" );
    write_output( $version . '_plack', @output );

    @output = do_all_iterations( undef, "with_memcached" );
    write_output( $version . '_memcached', @output );

    @output = do_all_iterations( "with_plack", "with_memcached" );
    write_output( $version . '_plack_and_memcached', @output );
}

sub reset_my_db {
    $cmd = qq|mysql -u koha_$kohadev -ppassword -e"DROP DATABASE koha_$kohadev"|;
    ( $success, $error_code, $full_buf, $stdout_buf, $stderr_buf ) = run( command => $cmd, verbose => $verbose );
    $cmd = qq|mysql -u koha_$kohadev -ppassword -e"CREATE DATABASE koha_$kohadev"|;
    ( $success, $error_code, $full_buf, $stdout_buf, $stderr_buf ) = run( command => $cmd, verbose => $verbose );
    $cmd = q|perl /home/vagrant/koha-misc4dev/do_all_you_can_do.pl|;
    ( $success, $error_code, $full_buf, $stdout_buf, $stderr_buf ) = run( command => $cmd, verbose => $verbose );
}

sub restart_memcached {
    $cmd = q|sudo service memcached restart|;
    run( command => $cmd, verbose => $verbose );
}
sub stop_memcached {
    $cmd = q|sudo service memcached stop|;
    run( command => $cmd, verbose => $verbose );
}
sub restart_plack {
    $cmd = qq|sudo koha-plack --restart $kohadev|;
    run( command => $cmd, verbose => $verbose );
}
sub restart_apache {
    $cmd = qq|sudo service apache2 restart|;
    run( command => $cmd, verbose => $verbose );
}

sub enable_plack {
    $cmd = qq|sudo cp $koha_root/debian/templates/plack.psgi /etc/koha/sites/kohadev/plack.psgi|;
    ( $success, $error_code, $full_buf, $stdout_buf, $stderr_buf ) = run( command => $cmd, verbose => $verbose );
    `sudo perl -p -i -e s#/usr/share/koha/intranet/cgi-bin#/home/vagrant/kohaclone# /etc/koha/sites/kohadev/plack.psgi`;
    `sudo perl -p -i -e s#/usr/share/koha/lib#/home/vagrant/kohaclone# /etc/koha/sites/kohadev/plack.psgi`;
    $cmd = qq|sudo koha-plack --enable kohadev|;
    ( $success, $error_code, $full_buf, $stdout_buf, $stderr_buf ) = run( command => $cmd, verbose => $verbose );
    restart_plack();
    restart_apache();
}
sub disable_plack {
    $cmd = qq|sudo koha-plack --disable kohadev|;
    ( $success, $error_code, $full_buf, $stdout_buf, $stderr_buf ) = run( command => $cmd, verbose => $verbose );
    restart_apache();
}

sub do_all_iterations {
    my ( $with_plack, $with_memcached ) = @_;
    msg( ( $with_plack ? "With Plack" : "Without Plack" ) . ( $with_memcached ? " With Memcached" : " Without Memcached"), 4);
    msg("Reset the database", 3);
    #reset_my_db();
    msg( ( $with_memcached ? "Restart memcached" : "Stop memcached" ), 3);
    $with_memcached ? restart_memcached() : stop_memcached();
    msg( ( $with_plack ? "Enable Plack" : "Disable Plack" ), 3);
    $with_plack ? enable_plack() : disable_plack();
    my ( @output, $output );
    msg("First shoot to populate caches", 3);
    do_one_iteration();
    for my $i ( 1 .. $iterations ) {
        msg("Processing Iteration $i/$iterations" . ( $with_plack ? " (plack)" : "" ) . ( $with_memcached ? " (memcached)" : "" ), 3);
        $output = do_one_iteration();
        push @output, @$output;
    }
    return @output;
}

sub do_one_iteration {
    $cmd = qq|sudo koha-shell $kohadev -p -c "PERL5LIB=$PERL5LIB perl t/db_dependent/selenium/basic_workflow.t"|;
    ( $success, $error_code, $full_buf, $stdout_buf, $stderr_buf ) = run( command => $cmd, verbose => $verbose );
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
