use strict;
use Data::Dumper;
use Bio::KBase::Utilities::ScriptThing;
use Carp;

#
# This is a SAS Component
#

=head1 NAME

er-get-entity-Variant

=head1 SYNOPSIS

er-get-entity-Variant [-c N] [-a] [--fields field-list] < ids > table.with.fields.added

=head1 DESCRIPTION

Each subsystem may include the designation of distinct
variants.  Thus, there may be three closely-related, but
distinguishable forms of histidine degradation.  Each form
would be called a "variant", with an associated code, and all
genomes implementing a specific variant can easily be accessed.

Example:

    er-get-entity-Variant -a < ids > table.with.fields.added

would read in a file of ids and add a column for each field in the entity.

The standard input should be a tab-separated table (i.e., each line
is a tab-separated set of fields).  Normally, the last field in each
line would contain the id. If some other column contains the id,
use

    -c N

where N is the column (from 1) that contains the id.

This is a pipe command. The input is taken from the standard input, and the
output is to the standard output.

=head2 Related entities

The Variant entity has the following relationship links:

=over 4
    
=item IsDescribedBy Subsystem

=item IsImplementedBy SSRow


=back

=head1 COMMAND-LINE OPTIONS

Usage: er-get-entity-Variant [arguments] < ids > table.with.fields.added

    -a		    Return all available fields.
    -c num          Select the identifier from column num.
    -i filename     Use filename rather than stdin for input.
    --fields list   Choose a set of fields to return. List is a comma-separated list of strings.
    -a		    Return all available fields.
    --show-fields   List the available fields.

The following fields are available:

=over 4    

=item role_rule

a space-delimited list of role IDs, in alphabetical order, that represents a possible list of non-auxiliary roles applicable to this variant. The roles are identified by their abbreviations. A variant may have multiple role rules.

=item code

the variant code all by itself

=item type

variant type indicating the quality of the subsystem support. A type of "vacant" means that the subsystem does not appear to be implemented by the variant. A type of "incomplete" means that the subsystem appears to be missing many reactions. In all other cases, the type is "normal".

=item comment

commentary text about the variant


=back

=head1 AUTHORS

L<The SEED Project|http://www.theseed.org>

=cut


our $usage = <<'END';
Usage: er-get-entity-Variant [arguments] < ids > table.with.fields.added

    -c num          Select the identifier from column num
    -i filename     Use filename rather than stdin for input
    --fields list   Choose a set of fields to return. List is a comma-separated list of strings.
    -a		    Return all available fields.
    --show-fields   List the available fields.

The following fields are available:

    role_rule
        a space-delimited list of role IDs, in alphabetical order, that represents a possible list of non-auxiliary roles applicable to this variant. The roles are identified by their abbreviations. A variant may have multiple role rules.
    code
        the variant code all by itself
    type
        variant type indicating the quality of the subsystem support. A type of "vacant" means that the subsystem does not appear to be implemented by the variant. A type of "incomplete" means that the subsystem appears to be missing many reactions. In all other cases, the type is "normal".
    comment
        commentary text about the variant
END



use Bio::KBase::CDMI::CDMIClient;
use Getopt::Long;

#Default fields

my @all_fields = ( 'role_rule', 'code', 'type', 'comment' );
my %all_fields = map { $_ => 1 } @all_fields;

my $column;
my $a;
my $f;
my $i = "-";
my @fields;
my $help;
my $show_fields;
my $geO = Bio::KBase::CDMI::CDMIClient->new_get_entity_for_script('c=i'		 => \$column,
								  "all-fields|a" => \$a,
								  "help|h"	 => \$help,
								  "show-fields"	 => \$show_fields,
								  "fields=s"	 => \$f,
								  'i=s'		 => \$i);
if ($help)
{
    print $usage;
    exit 0;
}

if ($show_fields)
{
    print STDERR "Available fields:\n";
    print STDERR "\t$_\n" foreach @all_fields;
    exit 0;
}

if ($a && $f) 
{
    print STDERR "Only one of the -a and --fields options may be specified\n";
    exit 1;
} 
if ($a)
{
    @fields = @all_fields;
}
elsif ($f) {
    my @err;
    for my $field (split(",", $f))
    {
	if (!$all_fields{$field})
	{
	    push(@err, $field);
	}
	else
	{
	    push(@fields, $field);
	}
    }
    if (@err)
    {
	print STDERR "er-get-entity-Variant: unknown fields @err. Valid fields are: @all_fields\n";
	exit 1;
    }
} else {
    print STDERR $usage;
    exit 1;
}

my $ih;
if ($i eq '-')
{
    $ih = \*STDIN;
}
else
{
    open($ih, "<", $i) or die "Cannot open input file $i: $!\n";
}

while (my @tuples = Bio::KBase::Utilities::ScriptThing::GetBatch($ih, undef, $column)) {
    my @h = map { $_->[0] } @tuples;
    my $h = $geO->get_entity_Variant(\@h, \@fields);
    for my $tuple (@tuples) {
        my @values;
        my ($id, $line) = @$tuple;
        my $v = $h->{$id};
	if (! defined($v))
	{
	    #nothing found for this id
	    print STDERR $line,"\n";
     	} else {
	    foreach $_ (@fields) {
		my $val = $v->{$_};
		push (@values, ref($val) eq 'ARRAY' ? join(",", @$val) : $val);
	    }
	    my $tail = join("\t", @values);
	    print "$line\t$tail\n";
        }
    }
}
__DATA__