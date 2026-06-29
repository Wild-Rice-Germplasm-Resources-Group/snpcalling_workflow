#!/usr/bin/env perl
#!/usr/bin/perl
package zzTabprint;

#use strict;
#use warnings;
use Term::ANSIColor;

use zzIO;
require Exporter;
use Carp;
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
            zzTabprint
        )
    ]
);

@EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
@EXPORT    = qw(zzTabprint);


sub usage {
    die 'usage: zzTabprint([[1,2],[3,4]], colored?0or1, file/fh)';
}

sub zzTabprint {
    my ($ins, $with_color, $file) = @_;
    $with_color //= 1;
    my $append_space = 2;
    usage unless defined $ins;
    my $O = open_out_fh($file);
    usage() unless $with_color==0 or $with_color==1;
    if (ref($ins) ne 'ARRAY') {
        usage();
    }
    #die @$ins;
    my @len;
    my $i_max = scalar($$ins[0]->@*)-1;
    $len[$_]=0 foreach (0..$i_max);
    my $line_max = scalar(@$ins)-1;
    foreach my $i (0..$i_max) {
        foreach my $line (0..$line_max) {
            my $l = exists $$ins[$line][$i] ? length $$ins[$line][$i] : 0;
            $len[$i] = $l if ( $l >= $len[$i]);
        }
    }
    foreach my $line (0..$line_max) {
        my $final = $$ins[$line] // '';
        if ($with_color==1 and $line % 2 ==0) {
           print $O color 'blue';
        }
        foreach my $i (0..$i_max) {
            my $A = 'A' . ($len[$i] + $append_space);
            print $O pack($A, $$final[$i]);
        }
        if ($with_color==1 and $line % 2 ==0) {
            print $O color 'reset';
        }
        print $O "\n";
    }
}

1;
