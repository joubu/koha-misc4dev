#!/usr/bin/perl

# This file is part of Koha.
#
# Copyright 2016 KohaSuomi
# Copyright 2016 Theke Solutions
#
# Koha is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# Koha is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Koha; if not, see <http://www.gnu.org/licenses>.

use Modern::Perl;

use Koha::Database;

use File::Which;
use Getopt::Long;
use Pod::Usage;
use Template;

=head1 NAME

koha-misc4dev/koha_schema_to_openapi.pl

Script that generates skeletal OpenAPI object definitions out of 
DB schema for Koha.

=head1 SYNOPSIS

    koha_schema_to_openapi.pl --resultset 'ResultSet'

The command has to be called from the root directory for the Koha source tree.

=head1 OPTIONS

=over 8

=item B<--resultset>

DBIC schema. (mandatory)

=item B<-h|--help>

prints this help text

=head1 CAVEATS

=over 8

=item B<--Descriptions>

The generated output is missing descriptions for the attributes.

=item B<--Booleans>

Boolean attributes need to be marked as booleans in the corresponding
schema file before the command is run. Refer to the coding guidelines
for instructions: https://wiki.koha-community.org/wiki/Coding_Guidelines#DBIC_schema_files

=back

=cut

my $resultset;
my $help;

GetOptions(
    "resultset=s" => \$resultset,
    "h|help"      => \$help
);

# If we were asked for usage instructions, do it
pod2usage(1) if defined $help or !defined $resultset;

my $jq = which 'jq';
die "Required jq binary not found on path."
    unless defined $jq;

open( STDOUT, '|jq .' );

my @columns      = Koha::Database->new->schema->resultset($resultset)->result_source->columns;
my $columns_info = Koha::Database->new->schema->resultset($resultset)->result_source->columns_info;

my @properties;

foreach my $column (@columns) {
    my $type = "[\""
        . column_type_to_openapi_type( $columns_info->{$column}->{data_type},
        $columns_info->{$column}->{is_boolean} )
        . "\"";
    $type .= ",\"null\""
        if $columns_info->{$column}->{is_nullable};
    $type .= "]";
    push @properties,
        {
        name        => $column,
        type        => $type,
        description => $columns_info->{$column}->{koha_description}
            // "REPLACE WITH A PROPER DESCRIPTION"
        };
}

my $tt = Template->new( { INTERPOLATE => 1 } ) || die "$Template::ERROR\n";

my $vars = { properties => \@properties };

$tt->process( \*DATA, $vars ) || die "$Template::ERROR";

sub column_type_to_openapi_type {
    my ($column_type) = @_;

    my $mapping = {
        ############ BOOLEAN ############
        'bool'    => 'boolean',
        'boolean' => 'boolean',
        'tinyint' => 'boolean',

        ############ INTEGERS ###########
        'bigint'    => 'integer',
        'integer'   => 'integer',
        'int'       => 'integer',
        'mediumint' => 'integer',
        'smallint'  => 'integer',

        ############ NUMBERS ############
        'decimal'          => 'number',
        'double precision' => 'number',
        'float'            => 'number',

        ############ STRINGS ############
        'blob'       => 'string',
        'char'       => 'string',
        'date'       => 'string',
        'datetime'   => 'string',
        'enum'       => 'string',
        'longblob'   => 'string',
        'longtext'   => 'string',
        'mediumblob' => 'string',
        'mediumtext' => 'string',
        'text'       => 'string',
        'tinyblob'   => 'string',
        'tinytext'   => 'string',
        'timestamp'  => 'string',
        'varchar'    => 'string'
    };

    return $mapping->{$column_type} if exists $mapping->{$column_type};
}

1;

__DATA__
[% BLOCK render_property %]
"[% property.name %]": {
    "type": [% property.type %],
    "description": "[% property.description %]"
}
[% END %]
{
  "type": "object",
  "properties": {
  [%- FOREACH property IN properties -%]
    [% PROCESS render_property property=property -%][% UNLESS loop.last %],[% END %]
  [%- END -%]
  }
}

