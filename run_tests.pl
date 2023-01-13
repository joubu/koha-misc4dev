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
use File::Basename qw( dirname );
use IPC::Cmd qw( run );
use File::chdir;

use Getopt::Long;
use Pod::Usage;

our ( $instance, $db_password );
my (
    $help,                 $koha_dir,
    $intranet_base_url,    $opac_base_url,
    $koha_user,            $koha_pass,
    $node_path,            $selenium_addr,
    $selenium_port,        $prove_cpus,
    $with_coverage,        $run_all_tests,
    $run_light_test_suite, $run_elastic_tests_only,
    $run_selenium_tests_only,
);
GetOptions(
    'h|help'                  => \$help,
    'instance=s'              => \$instance,
    'db-password=s'           => \$db_password,
    'koha-dir=s'              => \$koha_dir,
    'intranet-base-url=s'     => \$intranet_base_url,
    'opac-base-url=s'         => \$opac_base_url,
    'koha-user=s'             => \$koha_user,
    'koha-pass=s'             => \$koha_pass,
    'node-path=s'             => \$node_path,
    'selenium-addr=s'         => \$selenium_addr,
    'selenium-port=s'         => \$selenium_port,
    'prove-cpus=s'            => \$prove_cpus,
    'with-coverage'           => \$with_coverage,
    'run-all-tests'           => \$run_all_tests,
    'run-light-test-suite'    => \$run_light_test_suite,
    'run-elastic-tests-only'  => \$run_elastic_tests_only,
    'run-selenium-tests-only' => \$run_selenium_tests_only,
) || pod2usage(1);

pod2usage( -verbose => 2 ) if $help;

pod2usage("One and only one run-* parameters must be provided")
  unless  $run_all_tests
  xor $run_light_test_suite
  xor $run_elastic_tests_only
  xor $run_selenium_tests_only;

pod2usage("Coverage can only be generated if --run-all-tests is passed")
  if $with_coverage && !$run_all_tests;

$instance          ||= $ENV{KOHA_INSTANCE}     || 'kohadev';
$db_password       ||= $ENV{KOHA_DB_PASSWORD}  || 'password';
$koha_dir          ||=                            '.';
$intranet_base_url ||= $ENV{KOHA_INTRANET_URL} || 'http://koha:8081';
$opac_base_url     ||= $ENV{KOHA_OPAC_URL}     || 'http://koha:8080';
$koha_user         ||= $ENV{KOHA_USER}         || 'koha';
$koha_pass         ||= $ENV{KOHA_PASS}         || 'koha';
$node_path         ||= $ENV{NODE_PATH};
$selenium_addr     ||= $ENV{SELENIUM_ADDR}     || 'selenium';
$selenium_port     ||= $ENV{SELENIUM_PORT}     || 4444;
$prove_cpus        ||= $ENV{KOHA_PROVE_CPUS};

my $create_success_file = exists $ENV{RUN_TESTS_AND_EXIT} && $ENV{RUN_TESTS_AND_EXIT} eq 'yes';

pod2usage("Cannot run tests, koha-dir does not seem to be a Koha src directory")
    unless -f "$koha_dir/Koha.pm";

my $env = {
    KOHA_TESTING        => 1,
    KOHA_NO_TABLE_LOCKS => 1,
    KOHA_INTRANET_URL   => $intranet_base_url,
    KOHA_OPAC_URL       => $opac_base_url,
    KOHA_USER           => $koha_user,
    KOHA_PASS           => $koha_pass,
    NODE_PATH           => $node_path,
    SELENIUM_ADDR       => $selenium_addr,
    SELENIUM_PORT       => $selenium_port,
    JUNIT_OUTPUT_FILE   => q{junit_main.xml},
};

$CWD = $koha_dir;

my @commands;

if ($with_coverage) {
    push @commands, q{rm -rf cover_db};
}

if ( $run_all_tests || $run_selenium_tests_only ) {
    push @commands, get_commands_to_reset_db();

    push @commands,
      build_prove_command(
        {
            env         => $env,
            prove_files => ['t/db_dependent/selenium/00-onboarding.t'],
        }
      );

    push @commands, get_commands_to_reset_db();
}
my @prove_rules = ( 'par=t/db_dependent/00-strict.t', 'seq=t/db_dependent/**.t', 'par=**' );
my @prove_opts  = ( '--timer', '--harness=TAP::Harness::JUnit', '--recurse' );
my @prove_files;

if ($run_light_test_suite) {
    @prove_files = map { chomp ; $_ } qx{find t xt -name '*.t' \\
                    -not -path "t/db_dependent/www/*" \\
                    -not -path "t/db_dependent/selenium/*" \\
                    -not -path "t/db_dependent/Koha/SearchEngine/Elasticsearch/*" \\
                    -not -path "t/db_dependent/Koha/SearchEngine/*" };
    push @prove_opts, '--shuffle';
}
elsif ($run_selenium_tests_only) {
    @prove_files = map { chomp ; $_ } qx{find t/db_dependent/selenium -name '*.t' -not -name '00-onboarding.t' | sort};
}
elsif ($run_elastic_tests_only) {

    # FIXME This list needs to be improved
    @prove_files = qw(
      t/Koha/Config.t
      t/Koha/SearchEngine
      t/db_dependent/Biblio.t
      t/db_dependent/Search.t
      t/db_dependent/Koha/Authorities.t
      t/db_dependent/Koha/Z3950Responder/GenericSession.t
      t/db_dependent/Koha/SearchEngine
      t/db_dependent/Koha_Elasticsearch.t
      t/db_dependent/SuggestionEngine_ExplodedTerms.t
      t/SuggestionEngine.t
      t/SuggestionEngine_AuthorityFile.t
      t/Koha_SearchEngine_Elasticsearch_Browse.t
    );
}
else {
    @prove_files = map { chomp ; $_ } qx{ ( find t/db_dependent/selenium -name '*.t' -not -name '00-onboarding.t' | sort ) ; ( find t xt -name '*.t' -not -path "t/db_dependent/selenium/*" | shuf ) };
}

if ( $with_coverage ) {
    $env->{PERL5OPT} = q{-MDevel::Cover=-db,/cover_db};
}

push @commands, build_prove_command(
    {
        env                 => $env,
        prove_cpus          => $prove_cpus,
        prove_rules         => \@prove_rules,
        prove_opts          => \@prove_opts,
        prove_files         => \@prove_files,
        create_success_file => $create_success_file,
    }
);

if ($with_coverage) {
    push @commands, q{mkdir cover_db},
      q{cp -r /cover_db/* cover_db},
      q{cover -report clover};
}

for my $cmd ( @commands ) {
    my ( $success, $error_code, $full_buf, $stdout_buf, $stderr_buf ) = run( command => $cmd, verbose => 1 );
    exit(1) unless $success;
}

sub build_prove_command {
    my ($params)   = @_;
    my $env        = $params->{env};
    my $prove_cpus = $params->{prove_cpus};
    my $prove_rules = $params->{prove_rules} || [];
    my $prove_opts  = $params->{prove_opts}  || [];
    my $prove_files = $params->{prove_files};
    my $create_success_files = $params->{create_success_file};
    return
        join( ' ', map { $_ . '=' . ( defined $env->{$_} ? $env->{$_} : q{} ) } keys %$env )
      . ' prove '
      . ( $prove_cpus ? "-j $prove_cpus " : "" )
      . join( ' ', map { qq{--rules='$_'} } @$prove_rules ) . ' '
      . join( ' ', @$prove_opts ) . ' '
      . join( ' ', @$prove_files ) . ' '
      . ( $create_success_file ? '&& touch testing.success' : '' );
}

sub get_commands_to_reset_db {
    return (
        qq{koha-mysql $instance -e "DROP DATABASE koha_$instance" || true}, # Don't fail if the DB does not exist
        qq{mysql -h db -u koha_$instance -p$db_password -e"CREATE DATABASE koha_$instance"},
        q{flush_memcached},
        q{sudo service apache2 restart},
        q{sudo service koha-common restart}
    );
}

=head1 NAME

run_tests.pl - Script to run Koha test files

=head1 SYNOPSIS

./run_tests.pl --instance=kohadev --db-password=password --koha-dir=/kohadevbox/koha --intranet-base-url=http://koha:8081 --opac-base-url=http://koha:8080 --koha-user=koha --koha-pass=koha --node-path=/kohadevbox/node_modules --selenium-addr=selenium --selenium-port=4444 [--prove-cpus=4] [--run-all-tests --run-light-test-suite --run-elastic-tests-only --run-selenium-tests-only] [--with-coverage]

=head1 DESCRIPTION

This script will be used by koha-testing-docker:files/run.sh to run the necessary test files on Jenkins.

However it could also be used by Koha developers to simulate easy what's happening on Jenkins.

At least one --run-* options must be provided.

=head1 OPTIONS

=over

=item B<--instance>

Provide the koha instance name, default to 'kohadev'.
Can be set using KOHA_INSTANCE.

=item B<--db-password>

The password for the koha_$instance user, default to 'password'.
Can be set using KOHA_DB_PASSWORD.

=item B<--koha-dir>

Root of the Koha source directory, default to '/kohadevbox/koha'.

=item B<--intranet-base-url>

The intranet base URL, default to 'http://koha:8081'.
Can be set using KOHA_INTRANET_URL.

=item B<--opac-base-url>

The OPAC base URL, default to 'http://koha:8080'.
Can be set using KOHA_OPAC_URL.

=item B<--koha-user>

The Koha superlibrarian user to use for some tests, default to 'koha'.
Can be set using KOHA_USER.

=item B<--koha-pass>

The password of the superlibrarian user, default to 'koha'.
Can be set using KOHA_PASS.

=item B<--node-path>

The path to the node modules directory, default to 'kohadevbox/node_modules'.
Can be set using NODE_PATH.

=item B<--selenium-addr>

The address of the selenium server, default to 'selenium'.
Can be set using SELENIUM_ADDR.

=item B<--selenium-port>

The port of the selenium server, default to '4444'.
Can be set using SELENIUM_PORT.

=item B<--prove-cpus>

Number of CPUs to use when running the prove command.
Can be set using KOHA_INSTANCE.

=item B<--run-all-tests>

Run all the tests!

=item B<--run-light-test-suite>

Run all the tests but www, selenium, and elastic tests.

=item B<--run-elastic-tests-only>

Only run the elastic tests.

=item B<--run-selenium-tests-only>

Only run the selenium tests.

=item B<--with-coverage>

Run all tests and generate a cover_db directory with code coverage metrics.
Can be set using COVERAGE.

=back

=cut
