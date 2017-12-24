#!/usr/bin/perl
use warnings; use strict; use open 'utf8'; use utf8;
binmode STDIN, ':utf8'; binmode STDOUT, ':utf8'; binmode STDERR, ':utf8';
use Data::Dumper;
use lib "$ENV{'ORACC'}/lib";

use ORACC::CBD::Util;
use ORACC::CBD::PPWarn;
use ORACC::CBD::Edit;
use ORACC::CBD::SuxNorm;
use ORACC::CBD::Validate;

use Getopt::Long;

# bare: no need for a header
# check: only do validation
# dry: no output files
# edit: edit cbd via acd marks and write patch script
# filter: read from STDIN, write to CBD result to STDOUT
# reset: reset cached glo and edit anyway 
# trace: print trace messages 
# vfields: only validate named fields, plus some essential ones supplied automatically

my %args = ();
GetOptions(
    \%args,
    qw/bare check dry edit filter lang:s project:s reset trace vfields:s/,
    ) || die "unknown arg";

$ORACC::CBD::PPWarn::trace = $args{'trace'};

my %ppfunc = (
    usage=>\&pp_usage,
    collo=>\&pp_collo,
    sense=>\&pp_geo,
);

my $lng = '';

unless ($args{'filter'}) {
    $args{'cbd'} = shift @ARGV;
    if ($args{'cbd'}) {
	$lng = $args{'cbd'}; $lng =~ s/\.glo$//; $lng =~ s#.*?/([^/]+)$#$1#;
    } else {
	die "cbdpp.plx: must give glossary on command line\n";
    }
} else {
    $args{'cbd'} = '<stdin>';
}

# Allow files of bare glossary bits for testing
if ($args{'bare'}) {
    $args{'cbdlang'} = 'sux' unless $args{'cbdlang'};
    $args{'project'} = 'test' unless $args{'project'};
} else {
    die "cbdpp.plx: $args{'cbd'}: can't continue without project and language\n"
	unless $args{'project'} && $args{'lang'};    
}

pp_file($args{'cbd'});

$args{'projdir'} = "$ENV{'ORACC_BUILDS'}/$args{'project'}";

my @cbd = pp_load(\%args);

if ($args{'lang'} =~ /sux|qpn/) {
    @cbd = ORACC::CBD::SuxNorm::normify($args{'cbd'}, @cbd);
}

pp_validate(\%args, @cbd);

if (pp_status()) {
    pp_diagnostics(\%args);
    die("cbdpp.plx: errors in glossary $args{'cbd'}. Stop.\n");
} else {

    if ($args{'edit'}) {
	@cbd = edit(\%args, @cbd);
	pp_diagnostics(\%args);
	exit 1 if pp_status();
    }

    unless ($args{'check'}) {
	foreach my $f (keys %ppfunc) {
	    if ($#{$ORACC::CBD::Util::data{$f}} >= 0) {
		pp_trace("cbdpp/calling ppfunc $f");
		&{$ppfunc{$f}}(\%args);
		pp_trace("cbdpp/exited ppfunc $f");
	    }
	}
    }
}

pp_trace("cbdpp/writing cbd");
pp_cbd(\%args,@cbd) unless $args{'check'};
pp_trace("cbdpp/cbd write complete");

pp_diagnostics(\%args);

################################################
#
# CBDPP Operational Functions
#

sub pp_collo {
    my $args = shift;
    my $ndir = "$$args{'projdir'}/02pub";
    system 'mkdir', '-p', $ndir;
    open(COLLO, ">$ndir/coll-$$args{'lang'}.ngm");
    foreach my $i (@{$ORACC::CBD::Util::data{'collo'}}) {
	my $e = pp_entry_of($i,@cbd);
	my $c = $cbd[$e];
	$c =~ s/^\S*//;
	$c =~ s/\].*$/\]/;
	$c =~ s/\s+\[/\[/;
	my $cc = $cbd[$i];
	$cc =~ s/\s+-(\s+|$)/ $c /;
	$cc =~ s/\s+$//;
	$cc =~ s/^\S+\s+//;
	print COLLO $cc, "\n";
	$cbd[$i] = "\000";
    }
    close(COLLO);
}

sub pp_geo {
    open(GEOS, '>pp.geos') || die "cbdpp.plx: can't write to pp.glo";
    foreach my $i (@{$ORACC::CBD::Util::data{'geos'}}) {
	print GEOS $cbd[$i], "\n";
	$cbd[$i] = "\000";
    }
    close(GEOS);
}

sub pp_usage {
    open(USAGE,'>pp.usage');
    foreach my $i (@{$ORACC::CBD::Util::data{'collo'}}) {
	print USAGE $cbd[$i], "\n";
	$cbd[$i] = "\000";
    }
    close(USAGE);
}

1;
