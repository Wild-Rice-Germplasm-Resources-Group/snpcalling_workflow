#!/usr/bin/perl

package zzVCF;

require strict;
require warnings;
use zzIO;
use v5.10;
require zzVCF::line;
use Carp;

sub new {
	my ($class, $args) = @_;
	my %args = %$args;
	confess 'zzVCF::new usage : $args{vcf} or $args{fh} or $args{force}' unless 
		exists $args{vcf} or exists $args{fh} or exists $args{force};
	my $in = $args{vcf};
	my $fh = exists $args{fh} ? $args{fh} : open_in_fh($args{vcf});
	my $self={
		_file_path => $args{vcf},
		_fh => $fh,
	};
	bless($self, $class || ref($class));
	return $self;
}

sub fresh_fh() {
	my ($class, $args) = @_;
	my $last_line = tell $self->{_fh};
	seek( $self->{_fh}, 0, 0 ) or say STDERR "ERROR: seek error0, might cause by pipeline filehandle\n\n";
	return $last_line;
}

sub file_path {
	my ( $self ) = @_;
	say $self->{_file_path};
}

sub get_commits {
	my ( $self ) = @_;
	return $self->{commits} if exists $self->{commits};
	my @commits;
	my $last_line = tell $self->{_fh};
	seek( $self->{_fh}, 0, 0 ) or say STDERR "ERROR: seek error1, might cause by pipeline filehandle\n\n";
	while ( my $line = readline( $self->{_fh} ) ) {
		chomp $line;
		if ($line=~/^##/) {
			push @commits, $line;
			next;
		} elsif ($line=~/^#/) {
			seek($self->{_fh}, $last_line, 0) or say STDERR "ERROR: seek error2, might cause by pipeline filehandle\n\n";
			$self->{commits} = \@commits;
			$self->{header} = [split(/\t/,$line)];
			return \@commits;
		} else {
			confess $line;
		}
		confess "$line";
	}
	confess;
}

sub get_header {
	my ( $self ) = @_;
	return $self->{header} if exists $self->{header};
	my $raw_header =  $self->{raw_header} // $self->_seek_header() // confess;
	my @h = split(/\t/, $raw_header);
	$self->{header} = \@h;
	return \@h;
}

sub _seek_header {
	my ( $self ) = @_;
	my $last_line = tell $self->{_fh};
	seek($self->{_fh}, 0, 0) or say STDERR "ERROR: seek error3, might cause by pipeline filehandle\n\n";
	while ( my $line = readline( $self->{_fh} ) ) {
		chomp $line;
		if ($line=~/^#/) {
			next if $line=~/^##/;
			$self->{raw_header} = $line;
			seek($self->{_fh}, $last_line, 0) or say STDERR "ERROR: seek error4, might cause by pipeline filehandle\n\n";
			return $line;
		}
		confess "no header line : $line";
	}
}


sub get_ids {
	my ( $self ) = @_;
	return $self->{ids} if exists $self->{ids};
	my $t = $self->get_header();
	$self->{ids} = [@{$t}[9..@$t-1]];
	return $self->{ids};
}

sub get_id_count {
	my ( $self ) = @_;
	return $self->{id_count} if exists $self->{id_count};
	$self->{id_count} = scalar @{$self->get_ids};
	return $self->{id_count};
}

sub next_pos {
	my ( $self, %args ) = @_;
	while ( my $line = readline( $self->{_fh} ) ) {
		chomp $line;
		next if $line =~ /^#/;
		next unless $line;
		my %params=(line => $line);
		return zzVCF::line->new(%params);
		#return zzVCF::line->new($line);
	}
	return undef;
}



1;



