#!/usr/bin/perl

# This program is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Koha; if not, see <http://www.gnu.org/licenses>.
#
# This program comes with ABSOLUTELY NO WARRANTY;

use Modern::Perl;
use Getopt::Long;
use Pod::Usage;

use C4::Installer;
use C4::Context;
use C4::Members;

my $dbh = C4::Context->dbh;
my ( $branchcode )  = $dbh->selectrow_array(q|SELECT branchcode FROM branches LIMIT 1|);
my ( $categorycode ) = $dbh->selectrow_array(q|SELECT categorycode FROM categories LIMIT 1|);

die
"Not enough data in the database, library and/or patron category does not exist"
  unless $branchcode and $categorycode;

my $patron_exists = $dbh->selectrow_array(q|SELECT COUNT(*) FROM borrowers WHERE userid = "koha"|);
die "A patron with userid 'koha' already exists" if $patron_exists;
$patron_exists = $dbh->selectrow_array(q|SELECT COUNT(*) FROM borrowers WHERE cardnumber = "koha"|);
die "A patron with cardnumber '42' already exists" if $patron_exists;

my $userid   = 'koha';
my $password = 'koha';
my $help;

GetOptions(
    'help|?'   => \$help,
    'userid=s'   => \$userid,
    'password=s' => \$password
);

pod2usage(1) if $help;

AddMember(
    surname      => 'koha',
    userid       => $userid,
    cardnumber   => 42,
    branchcode   => $branchcode,
    categorycode => $categorycode,
    password     => $password,
    flags        => 1,
);

=head1 NAME

create_superlibrarian.pl - create a user in Koha with superlibrarian permissions

=head1 SYNOPSIS

create_superlibrarian.pl
  [ --userid <userid> ] [ --password <password> ]

 Options:
   -?|--help        brief help message
   --userid         specify the userid to be set (defaults to koha)
   --password       specify the password to be set (defaults to koha)

=head1 OPTIONS

=over 8

=item B<--help|-?>

Print a brief help message and exits

=item B<--userid>

Allows you to specify the userid to be set in the database

=item B<--password>

Allows you to specify the password to be set in the database

=back

=head1 DESCRIPTION

A simple script to create a user in the Koha database with superlibrarian permissions

=cut
