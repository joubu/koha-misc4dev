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
use File::Basename qw( dirname );
use Cwd 'abs_path';

use C4::Installer;
use C4::Context;
use Koha::AuthUtils qw( hash_password );

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
our $VERSION = get_version();

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
my $major_version = join '', ( ( $VERSION =~ m|^3| ) ? ( split //, $VERSION )[0..2] : ( split //, $VERSION )[0..3] );
my $sql_files_dir = "$sql_dir/$lc_marcflavour/$major_version";
my $version_data_directory = $major_version;
our @records_files;
my $has_biblio_metadata = 0;
while ( not -d $sql_files_dir ) { # FIXME Hum... that smells wrong
    $version_data_directory--;

    $sql_files_dir = "$sql_dir/$lc_marcflavour/$version_data_directory";
    if ( $version_data_directory >= 1611 ) {
        if ( $version_data_directory == 1611 ) {
            if ( $VERSION >= "161200004" ) { # After 17196 removing of biblioitems.marcxml
                $sql_files_dir = "$sql_dir/$lc_marcflavour/$version_data_directory/after_17196";
                $has_biblio_metadata = 1;
            }
        } else {
            $has_biblio_metadata = 1;
        }
    }
}
@records_files = ( "$sql_files_dir/biblio.sql", "$sql_files_dir/biblioitems.sql", "$sql_files_dir/items.sql", "$sql_files_dir/auth_header.sql" );
push @records_files, "$sql_files_dir/biblio_metadata.sql" if $has_biblio_metadata;

C4::Context->preference('VOID'); # FIXME master is broken because of 174769e382df - 16520
insert_records();
insert_default_circ_rule();
configure_selfreg();
configure_selfcheckout();
configure_course_reserves();
insert_acquisition_data() if $major_version > 318;

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
    my $dbh = C4::Context->dbh;
    $dbh->do(
        q|INSERT INTO issuingrules (
        categorycode, itemtype, branchcode,
        maxissueqty
    | . ( $VERSION >= '32100035' ? ', maxonsiteissueqty' : '' ) . q|
        , issuelength
        , lengthunit
        , renewalperiod
        , reservesallowed
    | . ( $VERSION >= '160600018' ? ', holds_per_record' : '' ) . q|
    | . ( $VERSION >= '31900017'  ? ', onshelfholds'     : '' ) . q|
    | . ( $VERSION >= '31900017'  ? ', opacitemholds'    : '' ) . q|
    | . ( $VERSION >= '160600037' ? ', article_requests' : '' ) . q|
    ) VALUES (
        '*', '*', '*',
        5
    | . ( $VERSION >= '32100035' ? ', 5' : '' ) . q|
        , 5
        , 'days'
        , 5
        , 5
    | . ( $VERSION >= '160600018' ? ', 2 '     : '' ) . q|
    | . ( $VERSION >= '31900017'  ? ', 1 '     : '' ) . q|
    | . ( $VERSION >= '31900017'  ? ', "Y" '   : '' ) . q|
    | . ( $VERSION >= '160600037' ? ', "yes" ' : '' ) . q|
    )|
    );
}

sub configure_selfreg {
    C4::Context->set_preference('PatronSelfRegistration', 1);
    C4::Context->set_preference('PatronSelfRegistrationDefaultCategory', 'SELFREG');
    my $dbh = C4::Context->dbh;
    $dbh->do(q|INSERT INTO categories ( categorycode, description, enrolmentperiod, enrolmentfee, reservefee, hidelostitems, category_type
    | . ( $VERSION >= '31700004' ? ', default_privacy' : '' ) . q|
    ) VALUES ( 'SELFREG', 'Self registration', 99, 0, 0, 0, 'A'
    | . ( $VERSION >= '31700004' ? ', "default"' : '' ) . q|
    )|);
}

sub configure_selfcheckout {
    C4::Context->set_preference('WebBasedSelfCheck', 1);
    C4::Context->set_preference('AllowSelfCheckReturns', 1);
    C4::Context->set_preference('AutoSelfCheckAllowed', 1);
    C4::Context->set_preference('AutoSelfCheckID', 'self_checkout');
    C4::Context->set_preference('AutoSelfCheckPass', 'self_checkout');

    my $password = hash_password('self_checkout');

    my $dbh = C4::Context->dbh;
    $dbh->do(q|INSERT INTO borrowers ( cardnumber, userid, password, surname, categorycode, branchcode, dateexpiry, flags ) VALUES ( 'self_checkout', 'self_checkout', ?, 'Self-checkout patron', 'S', 'CPL', '2099-12-31', 0 )|, undef, $password);
    my $borrowernumber = $dbh->last_insert_id(undef, undef, 'borrowers', undef);
    if ( $VERSION >= "32100027" and $VERSION < "171200024" ) {
        $dbh->do(q|
            INSERT INTO user_permissions (borrowernumber, module_bit, code) VALUES (?, ?, ?)
        |, undef, $borrowernumber, 1, 'self_checkout' );
    } elsif ( $VERSION >= "171200024" ) {
        $dbh->do(q|
            INSERT INTO user_permissions (borrowernumber, module_bit, code) VALUES (?, ?, ?)
        |, undef, $borrowernumber, 23, 'self_checkout_module' );
    }
}

sub configure_course_reserves {
    C4::Context->set_preference('UseCourseReserves', 1);
    my $dbh = C4::Context->dbh;
    $dbh->do(q|INSERT INTO authorised_values ( category, authorised_value, lib, lib_opac ) VALUES ('DEPARTMENT', 'Department1', 'Department 1', 'Department 1')|);
    $dbh->do(q|INSERT INTO courses( department, course_number, course_name, enabled ) VALUES ('Department1', 1, 'first course', 'yes')|);
}

sub insert_acquisition_data {
    require t::lib::TestBuilder;
    my $builder = t::lib::TestBuilder->new;
    my $budget = $builder->build({ source => 'Aqbudgetperiod', value => {
    budget_period_startdate => '2016-01-01',
      budget_period_enddate => '2026-12-31',
       budget_period_active => 1,
  budget_period_description => 'Main budget',
        budget_period_total => 1000000,
    }});

    my $fund_1 = $builder->build({ source => 'Aqbudget', value => {
           budget_parent_id => undef,
                budget_code => 'Main fund',
                budget_name => 'Main fund',
              budget_amount => 1000,
              budget_encumb => 10,
           budget_period_id => $budget->{budget_period_id},
    }});
    my $fund_1_2 = $builder->build({ source => 'Aqbudget', value => {
           budget_parent_id => $fund_1->{budget_id},
                budget_code => 'Fund 1_2',
                budget_name => 'Fund 1_2',
              budget_amount => 100,
           budget_period_id => $budget->{budget_period_id},
    }});
    my $fund_2 = $builder->build({ source => 'Aqbudget', value => {
           budget_parent_id => undef,
                budget_code => 'Secondary fund',
                budget_name => 'Secondary fund',
              budget_amount => 1000,
              budget_encumb => 10,
           budget_period_id => $budget->{budget_period_id},
    }});

    C4::Context->set_preference('gist', '0|0.12|0.1965');
    my $vendor = $builder->build({ source => 'Aqbookseller', value => {
                       name => 'My Vendor',
                     active => 1,
                  listprice => 'USD',
               invoiceprice => 'USD',
                     gstreg => 0,
                 listincgst => 0,
              invoiceincgst => 0,
                   tax_rate => 0.1965,
                   discount => 10,
               deliverytime => 3,
    }});

    my $basket = $builder->build({ source => 'Aqbasket', value => {
                 basketname => 'My Basket',
                       note => 'An internal note',
             booksellernote => 'A vendor note',
               booksellerid => $vendor->{id},
               authorisedby => 51,
              deliveryplace => 'CPL',
               billingplace => 'CPL',
                  closedate => undef, # Need the undefs otherwise TestBuilder will create the FK with random data
                     branch => undef,
             contractnumber => undef,
              basketgroupid => undef,
            ( $VERSION > '32300056' ? ( is_standing   => 0 ) : () ),
    }});
}

sub get_version {
    my $version;
    eval { require Koha };
    if ( $@ ) {
        require 'kohaversion.pl';
        $version = kohaversion();
    } else {
        $version = $Koha::VERSION;
        $version =~ s|\.||g;
    }
    $version =~ s|\.||g;
    return $version;
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

Copyright 2016 Jonathan Druart

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
