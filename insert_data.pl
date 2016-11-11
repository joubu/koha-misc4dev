#!/usr/bin/perl

use Modern::Perl;
use Getopt::Long;
use Pod::Usage;
use File::Basename qw( dirname );
use Cwd 'abs_path';

use C4::Installer;
use C4::Context;
use Koha::IssuingRule; # Should not be needed but Koha::IssuingRules does not use it
use Koha::IssuingRules;
use Koha::Patron::Categories;

my $marcflavour = 'MARC21';
my ( $help, $verbose );

GetOptions(
    'help|?'        => \$help,
    'verbose'       => \$verbose,
    'marcflavour=s' => \$marcflavour
);

pod2usage(1) if $help;

$marcflavour = uc($marcflavour);
my $lc_marcflavour = lc $marcflavour;

if (     $marcflavour ne 'MARC21'
     and $marcflavour ne 'UNIMARC' ) {
    say "Invalid MARC flavour '$marcflavour' passed.";
    pod2usage;
}

if ( $marcflavour eq 'UNIMARC' ) {
    warn "There is no records data for UNIMARC yet"
}

our $root      = C4::Context->config('intranetdir');
our $installer = C4::Installer->new;
my $sql_dir = dirname( abs_path($0) ) . '/data/sql';
my @records_files = ( "$sql_dir/$lc_marcflavour/biblio.sql", "$sql_dir/$lc_marcflavour/biblioitems.sql", "$sql_dir/$lc_marcflavour/items.sql", "$sql_dir/$lc_marcflavour/auth_header.sql" );

C4::Context->preference('VOID'); # FIXME master is broken because of 174769e382df - 16520
insert_records();
insert_default_circ_rule();
configure_selfreg();

sub execute_sqlfile {
    my ($filepath) = @_;
    say "Inserting $filepath..."
        if $verbose;
    # FIXME There is something wrong here
    # load_sql does not return the error as expected
    my $error = $installer->load_sql($filepath);
    die $error if $error;
}

sub insert_records {
    say "Inserting records..."
        if $verbose;
    for my $file ( @records_files ) {
        execute_sqlfile( $file );
    }
}

sub insert_default_circ_rule {
    say "Inserting default circ rule..."
        if $verbose;
    Koha::IssuingRule->new(
        {
                 categorycode => '*',
                     itemtype => '*',
                   branchcode => '*',
                  maxissueqty => 5,
            maxonsiteissueqty => 5,
                  issuelength => 5,
                   lengthunit => 'days',
                renewalperiod => 5,
              reservesallowed => 5,
             holds_per_record => 2,
                 onshelfholds => 1,
                opacitemholds => 'Y',
             article_requests => 'yes',
        }
    )->store;
}

sub configure_selfreg {
    C4::Context->set_preference('PatronSelfRegistration', 1);
    C4::Context->set_preference('PatronSelfRegistrationDefaultCategory', 'SELFREG');
    Koha::Patron::Category->new(
        {
                 categorycode => 'SELFREG',
                  description => 'Self registration',
              enrolmentperiod => 99,
                 enrolmentfee => 0,
                   reservefee => 0,
                hidelostitems => 0,
                category_type => 'A',
              default_privacy => 'default',
        }
    )->store;
}

=head1 SYNOPSIS

insert_data.pl [ --marcflavour <marcflavour> ]

 Options:
   -?|--help         Brief help message
   --marcflavour m   Specify the MARC flavour to use (MARC21|UNIMARC). Defaults to MARC21.
   -v|--verbose      Be verbose

=head1 OPTIONS

=over 8

=item B<--help|-?>

Print a brief help message and exits

=item B<--marcflavour>

Lets you choose the desired MARC flavour for the sample data. Valid options are MARC21 and UNIMARC.
It defaults to MARC21.

=item B<--verbose>

Make the output more verbose.

=back

=head1 DESCRIPTION

A simple script to create a user in the Koha database with superlibrarian permissions

=cut

=head1 AUTHOR

Jonathan Druart <jonathan.druart at bugs.koha-community.org>

=head1 COPYRIGHT

Copyright 2013 BibLibre

=head1 LICENSE

This file is part of Koha.

Koha is free software; you can redistribute it and/or modify it under the
terms of the GNU General Public License as published by the Free Software
Foundation; either version 3 of the License, or (at your option) any later
version.

Koha is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along
with Koha; if not, see <http://www.gnu.org/licenses>.
