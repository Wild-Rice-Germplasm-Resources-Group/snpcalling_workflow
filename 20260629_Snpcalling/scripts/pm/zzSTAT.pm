#!/usr/bin/perl
package zzSTAT;

#use strict;
#use warnings;

require Exporter;
require threads;
require threads::shared;
use Carp;

sub new {
  my ($class, @args) = @_; # interval items
  confess 'no interval ' unless ($args[0]);
  confess 'no items ' if scalar @args <= 1;
  foreach my $i (1..$#args) {
    ref($args[$i]) eq 'SCALAR' or confess "some item's ref not SCALAR ";
  }
  
  my $self={
    _interval => shift @args,
    _items => \@args,
  };
  bless($self, $class || ref($class));
  return $self;
}


sub start {
  my ( $self ) = @_;
  if ( exists $self->{_thread} and $self->{_thread}->is_running ) {
    print("stats_thread is running, can't start again.\n");
    return undef;
  }
  my @items = @{$self->{_items}};
  threads::shared::share($_) foreach @items;
  $self->{_thread} = threads->create( \&zzSTAT_printer, $self->{_interval}, @items );
  $self->{_thread}->detach();
  return 1;
}

sub stop {
  my ( $self ) = @_;
  $self->{_thread}->kill('KILL');
  sleep 1;
  while(1) {
    unless( $self->{_thread}->is_running ) {
      #delete $self->{_thread};
      last;
    }
    sleep 1;
  }
  
}

sub zzSTAT_printer {
  $SIG{'KILL'} = sub { threads->exit(); };
  my ($interval, @items) = @_;
  while (1) {
    sleep $interval;
    print "$$_  " foreach @items;
    print"!\n";
  }
}

1;
