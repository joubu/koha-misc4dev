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

use Koha::AuthUtils;
use Koha::Patrons;

my $instance   = 'kohadev';
my $help;

GetOptions(
    'help|?'     => \$help,
    'instance=s' => \$instance,
);

my ($userid, $password) = ('term1', 'term1');

my $cmd = "sudo cp /etc/koha/SIPconfig.xml /etc/koha/sites/$instance/SIPconfig.xml";
run( command => $cmd, verbose => 1 );

# Create a sip user term1/term1 with circulate permissions
my $perl_code = <<EOF;
exit(1) if Koha::Patrons->find({ userid => '$userid' });
Koha::Patron->new({
    surname      => 'koha_sip',
    cardnumber   => 'koha_sip',
    userid       => '$userid',
    categorycode => 'S',
    branchcode   => 'CPL',
    flags        => 2,
})->store->update({password =>Koha::AuthUtils::hash_password('$password')});
EOF

$perl_code =~ s|\s+| |g;
$cmd = sprintf(q{sudo koha-shell %s -p -c 'PERL5LIB=%s perl -MKoha::Patrons -le "%s"'}, $instance, $ENV{PERL5LIB}, $perl_code);
run( command => $cmd, verbose => 1 );

run( command => "sudo koha-sip --stop $instance", verbose => 1 );
run( command => "sudo koha-sip --start $instance", verbose => 1 );
exit(0);

=head1 NAME

setup_sip.pl - create a sip user (term1, term1) in Koha with superlibrarian permissions

=head1 SYNOPSIS

setup_sip.pl --instance <instance>

 Options:
   -?|--help        brief help message
   --instance       specify the koha instance (default to 'kohadev')

=head1 OPTIONS

=over 8

=item B<--help|-?>

Print a brief help message and exits

=item B<--instance>

Allows you to specify the koha instance name

=back

=head1 DESCRIPTION

A simple script to create a SIP user and copy the .xml SIP config file.

=cut
