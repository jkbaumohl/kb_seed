#!/usr/bin/env perl

#
# This is a SAS component.
#

#########################################################################
# Copyright (c) 2003-2008 University of Chicago and Fellowship
# for Interpretations of Genomes. All Rights Reserved.
#
# This file is part of the SEED Toolkit.
#
# The SEED Toolkit is free software. You can redistribute
# it and/or modify it under the terms of the SEED Toolkit
# Public License.
#
# You should have received a copy of the SEED Toolkit Public License
# along with this program; if not write to the University of Chicago
# at info@ci.uchicago.edu or the Fellowship for Interpretation of
# Genomes at veronika@thefig.info or download a copy from
# http://www.theseed.org/LICENSE.TXT.
#########################################################################

use strict;
use warnings;

use SeedUtils;
use WriteEMBL;
use gjoseqlib;

use Data::Dumper;

$0 =~ m/([^\/]+)$/;
my $self = $1;

my $usage = qq(usage: $self  LocusTag_Prefix  SEED_OrgDir > genbank.output);

my ($locus_tag_prefix, $org_dir) = @ARGV;

$org_dir =~ s/\/$//;
if (!-d $org_dir) {
    die "Organism directory $org_dir does not exist" unless (-d $org_dir);
}

my $taxon_ID;
if ($org_dir =~ m/(\d+)\.\d+/) {
    $taxon_ID = $1;
}
else {
    die qq(Organism directory $org_dir does not end in a taxonomy ID (e.g., \'123456.7\'));
}


my $genome;
if (open(GENOME, "<$org_dir/GENOME")) {
    $genome = <GENOME>;
    chomp $genome;
    close(GENOME);
}
else {
    die "could not read-open $org_dir/GENOME";
}


my $taxonomy;
if (open(TAXONOMY, "<$org_dir/TAXONOMY")) {
    @_ = <TAXONOMY>;  chomp @_;
    $taxonomy =  join("", @_);
    $taxonomy =~ s/\s+/ /sgo;
    close(TAXONOMY);
}
else {
    die "could not read-open $org_dir/TAXONOMY";
}


my $strain;
if ((not $strain) && ($genome =~ m/^\S+\s+\S+\s+(.*)/)) {
    $strain = $1;
}


my $defline;
if (not $defline) {
    $defline = $genome;
}


my $project;
if (open(PROJECT, "<$org_dir/PROJECT")) {
    @_ = <PROJECT>;  chomp @_;
    $project =  join("", @_);
    $project =~ s/\s+/ /go;
    close(PROJECT);
}
else {
    die "could not read-open $org_dir/PROJECT";
}


use constant FID    =>  0;
use constant LOCUS  =>  1;
use constant CONTIG =>  2;
use constant LEFT   =>  3;
use constant RIGHT  =>  4;
use constant LEN    =>  5;
use constant STRAND =>  6;
use constant TYPE   =>  7;
use constant FUNC   =>  8;
use constant EC_NUM =>  9;

opendir(ORG_DIR, $org_dir) || die "Could not opendir $org_dir";
my @contig_files = map { "$org_dir/$_" } grep { m/^contigs\d*$/ } readdir(ORG_DIR);
closedir(ORG_DIR) || die "Could not closedir $org_dir";

my $EC_of = {};
my $function_of = {};
foreach my $assgn (qw(assigned_functions proposed_non_ff_functions proposed_functions)) {
    my $file = qq($org_dir/$assgn);
    if (-s $file) {
	my $fh;
	my $line;
	open($fh, qq(<$file)) || die qq(Could not read-open file \'$file\');
	while (defined($line = <$fh>)) {
	    chomp $line;
	    my ($fid, $func) = split /\t/, $line;
	    
	    my @ECs = ();
	    while ($func =~ s/\(EC\s+([^\)]+)\)//) {
		push @ECs, $1;
	    }
	    $EC_of->{$fid} = [@ECs]; 
	    
	    $func =~ s/\s+/ /sgo;
	    $func =~ s/^\s+//sgo;
	    $func =~ s/\s+$//sgo;
	    if ($func) { $function_of->{$fid} = $func; }
	}
	close($fh);
    }
}

my ($seq_of,  $len_of)  = &load_fasta(@contig_files);
my ($peg_seq, $peg_len) = &load_fasta("$org_dir/Features/peg/fasta");

my @tbls = ("$org_dir/Features/peg/tbl");
if (-s "$org_dir/Features/rna/tbl")  { push @tbls, "$org_dir/Features/rna/tbl"; }

my ($tbl) = &load_tbls($function_of, $EC_of, @tbls);


use Time::localtime;
my $time = localtime;
my $date = sprintf "%02d-%3s-%04d"
    , $time->mday
    , (qw(JAN FEB MAR APR MAY JUN JUL AUG SEP OCT NOV DEC))[$time->mon]
    , (1900+$time->year);

foreach my $contig (sort keys %$len_of)
{
    my $tmp;
    &WriteEMBL::form_header($contig, $len_of->{$contig}, q(linear), q(WGS),
			    $date, $defline, q(),
			    $genome, $strain, $taxonomy, $taxon_ID);
    
    my $features = $tbl->{$contig};
    foreach my $feature (@$features) {
	
	my $locus;
	if ($feature->[STRAND] eq '+') {
	    $locus = "$feature->[LEFT]\.\.$feature->[RIGHT]";
        }
	else {
	    $locus = "complement($feature->[LEFT]\.\.$feature->[RIGHT])";
        }
	
	my $feature_num;
	if ($feature->[FID] =~ m/\.(\d+)$/) {
	    $feature_num = $1;
	}
	else {
	    die qq(Could not extract feature-number from FIG=\'$feature->[FID]\');
	}
	
	my $ltag;
        if ($feature->[TYPE] eq 'peg') {
	    $ltag = $locus_tag_prefix . &zero_pad(4, $feature_num);
	    
	    &WriteEMBL::form_feature(q(gene), $locus, $ltag);
	    &WriteEMBL::form_feature(q(CDS), $locus, $ltag);
	    
            if ($feature->[FUNC]) {
		&WriteEMBL::form_multiline('product', $feature->[FUNC]);
	    }
	    
	    if ($feature->[EC_NUM]) {
		foreach my $EC_num (@ { $feature->[EC_NUM] }) {
		    &WriteEMBL::form_multiline(q(EC_number), $EC_num);
		}
	    }
	    
	    &WriteEMBL::form_multiline('translation', $peg_seq->{$feature->[FID]});
	}
	elsif ($feature->[TYPE] eq 'rRNA') {
	    $ltag = $locus_tag_prefix . q(_r) . &zero_pad(3, $feature_num);
	    
	    &WriteEMBL::form_feature(q(gene), $locus, $ltag);
	    &WriteEMBL::form_feature(q(rRNA), $locus, $ltag);
	    
            if ($feature->[FUNC]) {
		&WriteEMBL::form_multiline('product', $feature->[FUNC]);
	    }
	}
	elsif ($feature->[TYPE] eq 'tRNA') {
	    $ltag = $locus_tag_prefix . q(_r) . &zero_pad(3, $feature_num);
	    
	    &WriteEMBL::form_feature(q(gene), $locus, $ltag);
	    &WriteEMBL::form_feature(q(tRNA), $locus, $ltag);
	    
            if ($feature->[FUNC]) {
		&WriteEMBL::form_multiline('product', $feature->[FUNC]);
	    }
	}
	elsif ($feature->[TYPE] eq 'misc_RNA') {
	    $ltag = $locus_tag_prefix . q(_r) . &zero_pad(3, $feature_num);
	    
	    &WriteEMBL::form_feature(q(gene), $locus, $ltag);
	    &WriteEMBL::form_feature(q(misc_RNA), $locus, $ltag);
	    
            if ($feature->[FUNC]) {
		&WriteEMBL::form_multiline('product', $feature->[FUNC]);
	    }
	}
	else {
	    warn "Skipping unknown feature: ", join(", ", @$feature), "\n";
	}
	
	print STDOUT $^A;
	$^A = q();
    }
    
    $tmp = $seq_of->{$contig};
    &WriteEMBL::write_contig(\$tmp);
    
    print "//\n";
}





sub load_fasta {
    my (@files) = @_;
    my ($file, $id, $seq, $len);
    
    my $seq_of = {};
    my $len_of = {};
    
    foreach $file (@files)
    {
	print STDERR "Loading $file\n" if $ENV{VERBOSE};
	
	open (FILE, "<$file") or die "could not read-open $file";
	while (($id, undef, $seq) = &gjoseqlib::read_next_fasta_seq(\*FILE))
	{
	    $len = $len_of->{$id} = length($seq);
#	    print STDERR "\tSeq $id ($len chars)\n";
	    
	    if (($seq =~ tr/acgtACGT//) > 0.9*$len) {
		$seq  =~ tr/A-Z/a-z/;
	    } else {
		$seq  =~ tr/a-z/A-Z/;
	    }
	    $seq_of->{$id} = $seq;
	}
	close(FILE) or die "could not close $file";
    }
    
    return ($seq_of, $len_of);
}


sub load_tbls {
    my ($function_of, $EC_of, @files) = @_;
    my ($file, $entry, $fid, $locus, $alias, $contig, $left, $right, $len, $strand, $type, $func);
    my $x;
    my $tbl = {};
    
    foreach $file (@files)
    {
	print STDERR "Loading $file ...\n" if $ENV{VERBOSE};
	
	open(TBL, "<$file") || die "Could not read-open $file";
	while (defined($entry = <TBL>))
	{
	    chomp $entry;
	    
	    ($fid, $locus, $alias) = split /\t/, $entry;
	    $fid  =~ m/^[^\|]+\|\d+\.\d+\.([^\.]+)/;
	    $type =  $1;
	    
	    if ((($contig, $left, $right, $len, $strand) = &from_locus($locus)) 
		&& defined($contig) && $contig
		&& defined($left)   && $left
		&& defined($right)  && $right
		&& defined($len)    && $len
		&& defined($strand) && $strand
		)
	    {
		if (not defined($tbl->{$contig})) { $tbl->{$contig} = []; }
		$x = $tbl->{$contig};
		
		$func = undef;
		if ($type eq 'peg') {
		    $func = $function_of->{$fid} || q();
		}
		elsif ($type eq 'rna') {
		    $func = $function_of->{$fid} || q();
		    if (($func !~ m/\S+/o) && $alias) {
			$func = $alias;
		    }
		    
		    if ($func =~ m/tRNA/o) {
			$type = 'tRNA';
		    }
		    elsif ($func =~ m/ribosomal/io) {
			$type = 'rRNA';
		    }
		    else {
			$type = 'misc_RNA';
		    }
		}
		else {
		    warn "$fid has unknown feature type $type";
		    next;
		}
		
		my $ECs = $EC_of->{$fid};
		push @$x, [ $fid, $locus, $contig, $left, $right, $len, $strand, $type, $func, $ECs ];
	    }
	    else {
		warn "INVALID ENTRY in $file:\t$entry\n";
	    }
	}
	close(TBL) || die "Could not close $file";
    }
    
    foreach $contig (keys %$tbl)
    {
	$x  = $tbl->{$contig};
	@$x = sort by_locus @$x;
    }
    
    return $tbl;
}


sub from_locus
{
    my ($locus) = @_;
    
    if ($locus =~ m/^(\S+)_(\d+)_(\d+)$/)
    {
	return ($1
	       , &min($2, $3)
	       , &max($2, $3)
	       , (1+abs($3-$2))
	       , (($2 < $3) ? '+' : '-')
	       );
    }
    else {
	die "Invalid locus $locus";
    }
    
    return ();
}


sub zero_pad {
    my ($width, $num) = @_;
    return ((q(0) x ($width - length($num))) . $num);
}


sub by_locus {
    my (undef, undef, $A_contig, $A_left, $A_right, $A_len, $A_strand) = @$a;
    my (undef, undef, $B_contig, $B_left, $B_right, $B_len, $B_strand) = @$b;
    
    return (  ($A_contig cmp $B_contig) 
	   || ($A_left <=> $B_left)
	   || ($B_len  <=> $A_len)
	   || ($A_strand cmp $B_strand)
	   );
}
