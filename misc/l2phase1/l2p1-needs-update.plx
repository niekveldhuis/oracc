#!/usr/bin/perl
use warnings; use strict;

my $g2 = `oraccopt . g2`;

my $from_glos_sig = '01bld/from-glos.sig';
my $sig_date = (stat($from_glos_sig))[9];
my $status = 1; # default to not needing update

if ($g2 eq 'yes') {
    foreach my $g (<00lib/*.glo>) {
	my $glo_date = undef;
	my $tmp = $g; $tmp =~ s/00lib/01tmp/;
	$glo_date = (stat($g))[9];
	my $tmp_date = (stat($tmp))[9];
	if (!defined($tmp_date) || $glo_date > $tmp_date) {
	    system 'cbdpp.plx', $g;
	    $status = 0;
	    next;
	} else {
	    $g = $tmp;
	    $glo_date = (stat($g))[9];
	}
	if (!-z $g
	    && (!defined($sig_date) || $glo_date > $sig_date)) {
	    $status = 0;
	}
    }
} else {
    foreach my $g (<00lib/*.glo>) {
	my $glo_date = undef;
	if ($g =~ m#/(?:sux|qpn)#) {
	    my $norm = "$g.norm";
	    $norm =~ s/00lib/01bld/;
	    $glo_date = (stat($g))[9];
	    my $norm_date = (stat($norm))[9];
	    if (!defined($norm_date) || $glo_date > $norm_date) {
		system 'l2p1-sux-norm.plx', $g;
		$status = 0;
		next;
	    } else {
		$g = $norm;
		$glo_date = (stat($g))[9];
	    }
	} else {
	    $glo_date = (stat($g))[9];
	}
	if (!-z $g
	    && (!defined($sig_date) || $glo_date > $sig_date)) {
	    $status = 0;
	}
    }
}

exit($status);
