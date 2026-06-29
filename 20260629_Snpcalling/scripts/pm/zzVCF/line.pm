#!/usr/bin/perl
package zzVCF::line;

use strict;
use warnings;
use zzIO;
use v5.10;
use Carp;

sub new {
	my ($class, %args) = @_;
	chomp $args{line};
	my $self={
		line => $args{line},
		#line => $args[0],
	};
	bless($self, $class || ref($class));
	return $self;
}

sub get_line {
	my ( $self, %args ) = @_;
	return $self->{line};
}

sub get_split {
	my ( $self, %args ) = @_;
	return $self->{split} if exists $self->{split};
	my @ret = split/\t/,$self->{line};
	$self->{split} = \@ret;
	return $self->{split};
}

# 0 chr
sub get_chr {
	my ( $self ) = @_;
	return $self->{chr} if exists $self->{chr};
	$self->{chr} = $self->get_split()->[0];
	return $self->{chr};
}

# 1 pos
sub get_pos {
	my ( $self ) = @_;
	return $self->{pos} if exists $self->{pos};
	$self->{pos} = $self->get_split()->[1];
	return $self->{pos};
}


# 2 id
sub get_id {
	my ( $self ) = @_;
	return $self->{id} if exists $self->{id};
	$self->{id} = $self->get_split()->[2];
	return $self->{id};
}

# 3 ref
sub get_ref {
	my ( $self ) = @_;
	return $self->{ref} if exists $self->{ref};
	$self->{ref} = $self->get_split()->[3];
	return $self->{ref};
}

# 4 alt
sub get_alts {
	my ( $self ) = @_;
	return $self->{alts} if exists $self->{alts};
	$self->{alts} = [ $self->get_ref,  split ',', $self->get_split()->[4] ];
	return $self->{alts};
}

# 5 qual
sub get_qual {
	my ( $self ) = @_;
	return $self->{filter} if exists $self->{filter};
	$self->{filter} = $self->get_split()->[5];
	return $self->{filter};
}

# 6 filter
sub get_filter {
	my ( $self ) = @_;
	return $self->{filter} if exists $self->{filter};
	$self->{filter} = $self->get_split()->[6];
	return $self->{filter};
}

# 7 info
sub get_pos_info {
	my ( $self, %args ) = @_;
	return $self->{pos_info} if exists $self->{pos_info};
	my $split = $self->get_split();
	my @a = split ';',$$split[7];
	my %ret;
	foreach my $a (@a) {
		my @b = split '=',$a;
		$ret{$b[0]} = exists $b[1] ? $b[1] : undef;
	}
	$self->{pos_info} = \%ret;
	return $self->{pos_info};
}

# 8 format
sub get_id_info_format {
	my ( $self, %args ) = @_;
	return $self->{id_info_format} if exists $self->{id_info_format};
	my $split = $self->get_split();
	my @format=split(':',$$split[8]);
	$self->{id_info_format} = \@format;
	return $self->{id_info_format};
}

# 9..
sub get_id_info {
	my ( $self, %args ) = @_;
	return $self->{id_info} if exists $self->{id_info};
	my $split = $self->get_split();
	my @ret;
	my $format = $self->get_id_info_format();
	foreach my $i (9..@$split-1) {
		my @a_one=split(':',$$split[$i]);
		my %t;
		foreach my $item_n (1..@$format-1) { # not contain GT
			$t{ $$format[$item_n] } = $a_one[$item_n];
		}
		push @ret,\%t;
	}
	$self->{id_info} = \@ret;
	return $self->{id_info};
}



sub get_alleles {
	my ( $self, %args ) = @_;
	return $self->{alleles} if exists $self->{alleles};
	my $split = $self->get_split();
	my @ret;
	foreach my $i (9..@$split-1) {
		$$split[$i] =~ /^(.)[\/\|](.)/ or confess;
		push @ret,[$1,$2];
		#push @ret,($1+$2);
	}
	$self->{alleles} = \@ret;
	return $self->{alleles};
}




#############
#############
#############

# 0 chr
sub set_chr {
	my ( $self, $new ) = @_;
	$self->{change}->{chr}=$new and return 1;
	return 0;
}

# 1 pos
sub set_pos {
	my ( $self, $new ) = @_;
	$self->{change}->{pos}=$new and return 1;
	return 0;
}


# 2 id
sub set_id {
	my ( $self, $new ) = @_;
	$self->{change}->{id}=$new and return 1;
	return 0;
}

# 3 ref
sub set_ref {
	my ( $self, $new ) = @_;
	$self->{change}->{ref}=$new and return 1;
	return 0;
}

# 4 alt
sub set_alts {
	my ( $self, $new ) = @_;
	$self->{change}->{alts}=$new and return 1;
	return 0;
}

# 5 qual
sub set_qual {
	my ( $self, $new ) = @_;
	$self->{change}->{qual}=$new and return 1;
	return 0;
}

# 6 filter
sub set_filter {
	my ( $self, $new ) = @_;
	$self->{change}->{filter}=$new and return 1;
	return 0;
}

# 7 info
sub set_pos_info {
	my ( $self, $new ) = @_;
	$self->{change}->{pos_info}=$new and return 1;
	return 0;
}

# 8 format
sub set_id_info_contain {
	my ( $self, $new ) = @_;
	$self->{change}->{pos}=$new and return 1;
	return 0;
}

# 9..
sub set_id_info {
	my ( $self, $new ) = @_;
	$self->{change}->{id_info}=$new and return 1;
	return 0;
}


sub set_alleles {
	my ( $self, $new ) = @_;
	$self->{change}->{alleles}=$new and return 1;
	return 0;
}

#####

sub get_fix_line {
	my ( $self, %args ) = @_;
	my $split = $self->get_split();
	my @ret;
	$ret[0] = exists $self->{change}->{chr} ? $self->{change}->{chr} : $$split[0];
	$ret[1] = exists $self->{change}->{pos} ? $self->{change}->{pos} : $$split[1];
	$ret[2] = exists $self->{change}->{id} ? $self->{change}->{id} : $$split[2];
	$ret[3] = exists $self->{change}->{ref} ? $self->{change}->{ref} : $$split[3];
	$ret[4] = exists $self->{change}->{alts} ? 
		join ',', @{$self->{change}->{alts}} : $$split[4];
	$ret[5] = exists $self->{change}->{qual} ? $self->{change}->{qual} : $$split[5];
	$ret[6] = exists $self->{change}->{filter} ? $self->{change}->{filter} : $$split[6];
	$ret[7] = $self->get_fix_pos_info;
	$ret[8] = exists $self->{change}->{format} ? 
		join ':', @{$self->{change}->{format}} : $$split[8];
	push @ret,@{ $self->get_fix_ids }; # 9..
	return join "\t",@ret;
}


sub get_fix_pos_info {
	my ( $self, %args ) = @_;
	my $split = $self->get_split();
	my $ret;
	if ( exists $self->{change}->{pos_info} ) {
		my $info = $self->{change}->{pos_info};
		my @t;
		foreach my $item (%$info) {
			push @t, (defined $$info{$item} ? "$item=$$info{$item}" : "$item");
		}
		$ret = join ';', @t;
	} else {
		$ret = $$split[7];
	}
	return $ret;
}

sub get_fix_ids {
	my ( $self, %args ) = @_;
	my $split = $self->get_split();
	my @ret;
	return [@$split[9..@$split-1]] unless (exists $self->{change}->{id_info} or exists $self->{change}->{alleles});
	#say STDERR "change both id_info and alleles!!! " if (exists $self->{change}->{id_info} and exists $self->{change}->{alleles});
	my $id_info = exists $self->{change}->{id_info} ? $self->{change}->{id_info} : $self->get_id_info;
	my $alleles = exists $self->{change}->{alleles} ? $self->{change}->{alleles} : $self->get_alleles;
	confess "the count of id_info and alleles not equal!! "
		if ( @$id_info != @$alleles );
	foreach my $i (0..@$alleles-1) {
		$ret[$i]=join '/', @{$$alleles[$i]};
	}
	my $format = exists $self->{change}->{format} ?  @{$self->{change}->{format}} : $self->get_id_info_format;
	foreach my $i (0..@$id_info-1) {
		my @t;
		foreach my $item_n (1..@$format-1) {
			push @t, (defined $$id_info[$i]{$$format[$item_n]} ? "$$id_info[$i]{$$format[$item_n]}" : confess"id_info[$i]{$$format[$item_n]}");
		}
		if (@t) {
			$ret[$i] .= ':';
			$ret[$i] .= join ':', @t;
		}
	}
	return \@ret;
}



1;


##  VCF:
##   0    1   2  3    4   5      6     7    8      9...
## CHROM POS ID REF  ALT QUAL FILTER INFO FORMAT   ...

