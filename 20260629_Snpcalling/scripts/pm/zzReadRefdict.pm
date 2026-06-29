#!/usr/bin/perl


package zzReadRefdict;

use strict;
use Carp;

require Exporter;
use File::Basename;
require Bio::SeqIO;

use vars qw(
  @ISA
  %EXPORT_TAGS
  @EXPORT_OK
  @EXPORT
);

@ISA = qw(Exporter);

%EXPORT_TAGS = (
    'all' => [
        qw(
            zzReadRefdict
            zzReadRef
            zzReadRefLen
        )
    ]
);

@EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
@EXPORT    = qw(zzReadRefdict zzReadRef zzReadRefLen);

my $picard = '/share/home/yzwl_zhengzy/software/picard/picard.2.21.5.jar';

sub zzReadRefdict($) {
	my $ref= $_[0];
	my %len;
	my $ref_basename = basename($ref);
	my $ref_header;
	if ( $ref_basename =~/^(.*)\.fa$/ ) {
		$ref_header = dirname($ref). "/$1.dict";
	} elsif ( $ref_basename =~/\.dict$/ ) {
		$ref_header = $ref;
	} else {
		confess "$ref nether in .fa nor .dict\n";
	}

	open (F,"$ref_header") or confess "cant open header file(.dict): $ref_header, have you index the ref.fa by samtools faidx ? $!";
	while (<F>) {
		chomp;
		if (/\@SQ\s+SN\:(\S+)\s+LN\:(\d+)/){
			$len{$1}=$2;
		}
	}
	close F;
	return %len;
}

sub zzReadRef($) {
    my $ref = shift or confess;
    my %ret;
    my $seqio_object = Bio::SeqIO->new(-file => $ref);
    while (my $seq = $seqio_object->next_seq) {
        $ret{ $seq->id } = $seq->seq();
    }
    return \%ret;
}


sub zzReadRefLen($){
    my $ref = shift or confess;
    my $dict = "$ref.dict";
    if (-e $dict) {
        return zzReadRefdict($dict);
    }
    say STDERR "$dict not exists, try to build !";
    system("java -jar $picard CreateSequenceDictionary R=$ref O=$dict") and confess "build ref Dictionaryfailed! ";
    return zzReadRefdict($dict);
}


sub zzReadRefLen_bioperl($){
    my $ref = shift or confess;
    my %ret;
    my $seqio_object = Bio::SeqIO->new(-file => $ref);
    while (my $seq = $seqio_object->next_seq) {
        $ret{ $seq->id } = $seq->length();
    }
    return %ret;
}

1;
