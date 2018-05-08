package ORACC::CBD::Sigs;

require Exporter;
@ISA=qw/Exporter/;

@EXPORT = qw/sigs_from_glo/;

use warnings; use strict; use open 'utf8'; use utf8;

use Data::Dumper;
use ORACC::CBD::PPWarn;
use ORACC::CBD::Forms;

use lib "$ENV{'ORACC'}/lib";
use ORACC::L2GLO::Util;

my $COF_NONE = 0;
my $COF_HEAD = 1;
my $COF_TAIL = 2;

my $basesig = '';
my @compound_parts = ();
my %cof_lines = ();
my $coresig = '';
my %coresigs = ();
my $currsig = '';
my $in_sense = '';
my @instsigs = ();
my $out = '';
my $lang = '';
my $project = `oraccopt`;

my @sigs_cofs = ();
my @sigs_coresigs = ();
my @sigs_psus = ();
my @sigs_simple = ();

my %sig = ();
my $sigs_glo_file = '';

my @cof_template_heads = ();
my @cof_template_tails = ();
my %cof_heads = ();
my %cof_tails = ();
my $compound = 0;
my $compound_cfgw = '';
my %compounds = ();
my $curr_cfgw = '';
my $current_first_base = '';
my $debug_type = '';
my $debug_arg = '';
my %default_senses = ();
my @externals = ();
my %externals = ();
my $found_simple_sig = 0;
my %noprintsigs = ();
my $parts_line = 0;
my %partsigs = ();
my %parts_map = ();
my %printsigs = ();
my $simple = 0;
my $verbose = 0;
my $cof_verbose = 0;
my $psu_verbose = 0;
my $rank = 0;
my $entrybang = '';

my $load_simple_counter = 0;

my $simple_loaded = 0;
my %simple;

my $ignorable = '(?:\(to be\)|a|to|the|\s)*?';
my $finalparens = '(?:\s+\(.*?\)\s*)?';

#$verbose = $psu_verbose = 1;

my %data = ();
my $trace = 0;
my @global_cbd = ();

######################################################################################

sub sigs_from_glo {
    sigs_simple(@_);
    sigs_cofs();
    sigs_psus(@_);
    sigs_dump();
}

######################################################################################

sub sigs_simple {
    my($args,@cbd) = @_;
    %data = %ORACC::CBD::Util::data;
    $trace = $ORACC::CBD::PPWarn::trace;
    @global_cbd = @cbd;
    ($project,$lang) = @$args{qw/project lang/};

    my $nsense = 0;
    
    for (my $i = 0; $i <= $#cbd; ++$i) {
	next if $cbd[$i] =~ /^\000$/ || $cbd[$i] =~ /^\#/;
	pp_line($i+1);

	local($_) = $cbd[$i];

#	warn "input: $_\n" if $verbose;

	if (s/^\@entry\*?(!?)\s+//) {
	    $curr_cfgw = $_; $curr_cfgw =~ s/\s*$//;
	    $compound = $in_sense = 0;
	    @instsigs = ();
	    $basesig = undef;
	    $coresig = undef;
	    $nsense = 0;
	    $entrybang = $1 || '';
	    @compound_parts = ();
	    $parts_line = 0;
	    $current_first_base = '';
	    %sig = ();
	    @sig{qw/cf gw pos/} = /^(.*?)\s+\[(.*?)\]\s*(\S+)\s*$/;
	    if ($sig{'cf'}) {
		$basesig = "$sig{'cf'}\[$sig{'gw'}\]$sig{'pos'}";
	    } else {
		pp_warn("(sigs) bad syntax in \@entry; entry ignored");
		do { ++$i; } 
		while ($cbd[$i] !~ /^\@end\s+entry/ && $i < $#cbd);
	    }
	} elsif (/^\@end\s+entry/) {
	    unless (defined $coresig) {
		pp_warn("(sigs) undefined coresig--bad entry\n");
		next;
	    }
	    #
	    # NOT GOOD ENOUGH: should emit sig for each primary base, and should
	    # check sigs to see if they already included it, supplying it if not.
	    #
	    if (!$compound && $simple && !$found_simple_sig && $current_first_base) {
		my $lang = ($lang =~ /^qpn/ ? $ORACC::CBD::qpn_base_lang : $lang);
		my $instsig1 = "\@$project'}\%$lang:$current_first_base=";
		my $xsig = "\$$sig{'cf'}/$current_first_base#~";
		++$noprintsigs{ "$instsig1$coresig\t0\n" };
	    }

	    $curr_cfgw = '';
	    
	} elsif (s/^\@parts\s+//) {

	    do { ++$i; } 
	    while ($cbd[$i] !~ /^\@end\s+entry/ && $i < $#cbd);

	} elsif (/^\@sense(!?)/) {

	    my $sensebang = $1 || '';

	    if (!$nsense && $ORACC::CBD::Forms::external) {

		my @f = forms_by_cfgw($curr_cfgw);
		if ($#f >= 0) {
#		    warn "processing $#f+1 external forms for $curr_cfgw\n";
		    foreach my $f (@f) {
			# $$f[3] is just the form line after @form; there is
			# no provision for ! on external forms yet so the first
			# arg is always empty
			my $f3 = $$f[3];
			$f3 =~ s/^(\S+)\s*//;
			my $orth = $1;
			sigs_form('',$orth,$f3);
		    }
		}
	    }
		
	    ++$nsense;

	    $in_sense = 1;
	    $rank = 0;
	    @sig{qw/epos sense/} = /\s+([A-Z]\S*)\s+(.*?)\s*$/;
	    if (!$sig{'epos'}) {
		pp_warn("(sigs) no POS in SENSE");
		/\s(.*?)\s*$/;
		$sig{'sense'} = $1;
		$sig{'epos'} = $sig{'pos'};
	    }
	    
#	    if (!defined $default_senses{$basesig}) {
#		$default_senses{$basesig} = [ $sig{'sense'} , $sig{'epos'} ];
#	    }
	    
	    $coresig = "$sig{'cf'}\[$sig{'gw'}//$sig{'sense'}\]$sig{'pos'}'$sig{'epos'}";
	    ++$coresigs{$coresig};

	    if ($#instsigs >= 0) {
		foreach my $instsig (@instsigs) {
		    if ($$instsig[0] =~ s/^!//) {
			$rank = 4;
		    }
		    if ($sensebang) {
			$rank |= 2;
		    } elsif ($nsense == 1) {
			$rank |= 1;
		    }
			
		    ++$printsigs{ "$$instsig[0]$coresig$$instsig[1]\t$rank\n" };
		    $found_simple_sig = 1;
		}
	    } else {
		unless ($sig{'cf'} =~ / /) {
		    if ($current_first_base) {
			my $lang = ($lang =~ /^qpn/ ? 'sux' : $lang);
			my $instsig0 = "\@$project\%$lang:$current_first_base";
			++$printsigs{ "$instsig0=$coresig\$$sig{'cf'}/$current_first_base#~\t0\n" };
			$found_simple_sig = 1;
		    }
		}
	    }
	    
	} elsif (/\@bases\s+(\S+)/) {

	    #
	    # Need to index primary bases here and autogenerate sigs for all of them
	    #
	    
	    $current_first_base = $1;
	    $current_first_base =~ s/;$//;
	    $current_first_base =~ s/^\*//;
	    
	} elsif (s/^\@form(!?)\s+(\S+)//) {

	    sigs_form($1,$2,$_) unless
		$ORACC::CBD::Forms::external;

	}
    }

    @sigs_simple = sort (keys %printsigs, keys %noprintsigs);
    @sigs_coresigs = sort keys %coresigs;
}

sub sigs_form {
    my $formbang = $_[0] || '';
    $sig{'form'} = $_[1];
    local($_) = $_[2];
    my @cof_tails = ();
    my $cof = $COF_NONE;
    my $cof_part = '';
    my $cof_sig = '';
    my $cof_core = '';
    my $cof_template = '';
    
    $formbang = '!' if $entrybang;
    
    @sig{qw/norm morph morph2 base cont stem root/} = ();
    
    my $cof_nth = 0;
    
    if (s/\s+\%(\S+)//) {
	$sig{'lang'} = $1;
	$sig{'lang'} =~ s#/n$#-949# if $sig{'lang'};
    } else {
	$sig{'lang'} = $lang;
    }
    
    if (/\$\(/) {
#	warn "COF: $_\n" if $verbose;
	
	if (/(^|\s)\$[^\(\s]+?\[/) {
	    pp_warn("(sigs) COF head should not have CF[GW]POS form; use only NORM");
	}
	
	my $cof_epos = $sig{'epos'} || $sig{'pos'};
	if ($coresig) {
	    # this happens if the COF FORM occurs within a @sense
	    $cof_core = $coresig;
	} else {
	    # this is a COF FORM before any @sense
	    $cof_core 
		= "$sig{'cf'}\[$sig{'gw'}//$sig{'gw'}\]$sig{'pos'}'$cof_epos";
	    $cof_template = "$sig{'cf'}\[$sig{'gw'}//\]$sig{'pos'}'";
	}
	
	my @cofvals = ();
	
	if (/^\s*\$\(/) {
	    $cof = $COF_TAIL;
	    s/^\s*//;
	    my @d = (m/\s+(\$\(?)/g);
	    for ($cof_nth = 2, my $i = 0; $i <= $#d; ++$i) {
		if ($d[$i] =~ /^\$\(/) {
		    ++$cof_nth;
		} else {
		    last;
		}
	    }
	    warn "COF TAIL: $_\n" if $verbose;
	} else {
	    $cof = $COF_HEAD;
	    $cof_nth = 1;
	    warn "COF HEAD: $_\n" if $verbose;
	}
	
	# get the form/sig belonging to the current word
	my $tmp = $_;
	$tmp =~ s/\$\(.*?\)//g;
	$tmp =~ s/^\s*(.*?)\s*$/$1/;
	$tmp =~ s/\s+/ /g;
	$tmp =~ s/^/ /;
	
	$_ = $cof_part = $tmp;
	
    } else {
	$cof_part = '';
    }
    s/^/ /; # so "/BASE" etc get trapped in initial position
    $sig{'norm'} = $1 if s/\s+\$(\S+)//;
    $sig{'morph2'} = $1 if s/\s+\#\#(\S+)//;
    $sig{'morph'} = $1 if s/\s+\#(\S+)//;
    $sig{'base'} = $1 if s/\s+\/(\S+)//;
    $sig{'cont'} = $1 if s/\s+\+(\S+)//;
    $sig{'stem'} = $1 if s/\s+\*(\S+)//;
    
    if (s/\s\@(\S+)//) {
	my $rws = $1;
	if (defined $ORACC::L2GLO::Util::rws_map{$rws}) {
	    $sig{'lang'} = $ORACC::L2GLO::Util::rws_map{$rws};
	    if ($rws eq 'EG' 
		&& ($lang && $lang ne 'sux')) {
		$sig{'lang'} = 'sux';
	    } else {
		pp_warn("(sigs) unknown RWS code \@$rws has been ignored");
	    }
	}
    }
    
    if ($sig{'form'}) {
	my $instsig1 = "\@$project\%$lang:$sig{'form'}=";
	my $instsig2 = '';
	foreach my $field (@ORACC::L2GLO::Util::instfields) {
	    $instsig2 .= "$ORACC::L2GLO::Util::fieldchars{$field}$sig{$field}" 
		if $sig{$field};
	}
	
	if ($cof == $COF_HEAD) {
	    $instsig2 .= '!0x01';
	} elsif ($cof == $COF_TAIL) {
	    $instsig2 .= sprintf("\!0x%02d", $cof_nth);
	}
	
	if ($in_sense) {
	    my $srank = $rank;
	    if ($formbang) {
		$srank |= 4;
	    }
	    ++$printsigs{ "$instsig1$coresig$instsig2\t$srank\n" };
	} else {
	    $found_simple_sig = 1;
	    push @instsigs, [ $formbang.$instsig1, $instsig2 ];
	}
	
    }
}

######################################################################

sub sigs_cofs {
    my %cofs = ();
    my $i = 0;
    foreach my $c (@sigs_simple) {
	++$i;
	local($_) = $c;
	if (/\!0x/) {
	    chomp;
	    #	s/\t.*$//; # not sure what this was doing but it makes COF with RANK fail
	    # so move instead to not anchoring the following regex with $, this means it can
	    # have fields beyond rank without breaking anything (don't think this can happen
	    # though)
	    my($pre,$key,$sig,$nth,$rank) = (/^(.*?):(.*?)=(.*?)\!0x0*(\d+)\t(\d+)/);
	    if ($pre) {
		my $index = $nth - 1;
		my $v = '';
		my ($lang) = ($pre =~ /\%(.*?)$/);
		if ($index) {
		    $v = "$pre:=$sig";
		} else {
		    $v = "$pre:$key=$sig";
		}
		push @{${$cofs{"$lang\:$key"}}[$index]}, $v;
	    } else {
		pp_file('<simple sigs list>');
		pp_line($i);
		pp_warn "(cof) syntax error: $_";
	    }
	}
    }
    foreach my $c (keys %cofs) {
	my @parts = @{$cofs{$c}};
	permute(@parts);
    }
}

# an array of arrays; the first contains the heads, the remainder
# tails.  We join the first two lists, then call recursively to 
# join additional ones.
sub
permute {
    my @parts = @_;
    my @newheads = ();
    foreach my $h (@{$parts[0]}) {
	foreach my $t (@{$parts[1]}) {
	    push @newheads, "$h\&\&$t";
	}
    }
    shift @parts; shift @parts;
    if ($#parts >= 0) {
	permute( [@newheads] , @parts);
    } else {
	foreach (@newheads) {
	    push @sigs_cofs, "$_\t0\n";
	}
    }
}

######################################################################

my %psu_cfs = ();
my %psu_simple = ();
my @psu_parts = ();

my %e = ();
my $err_glo = '';
my $glo = '';
my @parts_errors = ();
my $psu_parts = '';
my @entries_parts_lines = ();

my %validated_parts_lines = ();
my %bad_parts_lines = ();

my @no_sense_forms = ();
my @sense_forms = ();

sub sigs_psus {
    my($args,@cbd) = @_;
    $err_glo = $$args{'file'};
    psu_index_coresigs();
    psu_index_simple();
    psu_glo(@cbd);
    psu_dump();
}

sub psu_index_coresigs {
    foreach my $c (@sigs_coresigs) {
	my($cf,$gw) = ($c =~ m#^(.*?)\[(.*?)//#);
	$c =~ s/\!0x.*$//;
	push @{${$psu_cfs{$cf}}{$gw}}, $c;
    }
}

sub psu_index_simple {
    foreach my $s (@sigs_simple) {
	local($_) = $s;
	s/\t.*$//;
	m#=(.*?)\$#;
	my $keysig = $1;
	s/\!0x.*$//; # is this the right time to kill COF markers? Or before keysig assignment?
	if (defined $keysig) {
	    push(@{$simple{$keysig}}, $_);
	}
    }
    open(S,'>simple.dump');
    print S Dumper \%simple;
    close(S);
}

sub psu_glo {
    my $i = 0;
    my $nsense = 0;
    foreach my $c (@_) {
	local($_) = $c;
	++$i; pp_line($i);
	pp_file($err_glo);
	if (m/^\@entry\s+(.*?)\s*\[(.*?)\]\s*(\S+)\s*$/) {
	    @e{qw/cf gw pos/} = ($1,$2,$3);
	    $compound = ($e{'cf'} =~ / /);
	    $in_sense = $nsense = 0;
	    @no_sense_forms = ();
	    if ($compound) {
		$curr_cfgw = "$e{'cf'} \[$e{'gw'}\] $e{'pos'}";
	    }
	} elsif (/^\@parts/) {
	    $psu_parts = $_;
	    $psu_parts =~ s/^\@parts\s+//;
	    chomp $psu_parts;
	    push @entries_parts_lines, [ pp_line() , $_ ];
	} elsif (/^\@form/ && $compound) {
	    if ($in_sense) {
		my $formlang = '';
		if (s/\s\%([a-z]\S+)//) {
		    $formlang = $1 || '';
		}
		do_psu($formlang || $lang, $_);
	    } else {
		push @no_sense_forms, $_;
	    }
	} elsif (/^\@sense/ && $compound) {
	    if ($nsense == 0 && $ORACC::CBD::Forms::external) {
		@no_sense_forms = forms_by_cfgw($curr_cfgw);
	    }
	    $in_sense = 1;
	    my($epos,$sense) = (/\s(\S+)\s+(.*?)\s*$/);
	    if ($epos) {
		@e{qw/epos sense/} = ($epos,$sense);
		foreach my $f (@no_sense_forms) {
		    my $formlang = '';
		    my $f3 = $$f[3];
		    if ($f3 =~ s/\s\%([a-z]\S+)//) {
			$formlang = $1;
		    }
		    do_psu($formlang || $lang, $f3);
		}
	    } else {
		chomp;
		bad("malformed SENSE: $_");
	    }
	} elsif (/^\@end\s+entry/) {
	    $compound = 0;
	    %e = ();
	    @entries_parts_lines = ();
	}
    }
}

####################################################################

sub bad {
    pp_warn "(psu) ", @_;
}

sub bad2 {
    my($lnum,@err) = @_;
    pp_line($lnum);
    pp_warn "(psu) ", @err;
}

sub
do_psu {
    my($psulang,$formline) = @_;
    warn "do_psu: psulang=$psulang; formline=$formline" if $verbose;
    $formline =~ s/^\@form\s+//;
#    my ($forms, $norms) = ($formline =~ /^(\S+)\s*(\S.*)\s*$/);
    my ($forms, $rest) = ($formline =~ /^(\S+)\s*(.*)\s*$/);
    unless ($forms) {
	bad("syntax error, no forms in \@forms line");
    }

    my $psu_form = $forms; $psu_form =~ s/_0/ /g; $psu_form =~ tr/_/ /;
    
    my @forms = ($forms ? split(/_/,$forms) : ());
    my @rest = grep defined&&length, (split(/\s+/, $rest));
    my @norms = map { s/^\$//; $_ } grep (/^\$/, @rest);  # split(/(?:^|\s+)\$/,$norms);
    if ($#norms < 0) {
	@norms = ('*')x($#forms+1);
    }

    if ($#forms < $#norms && $#forms > 1 && $#norms > 1 && $forms[0] ne '*') {
	bad("PSU $psu_parts FORM $formline: please use '_0' to indicate empty FORM elements\n");
	return;
    } elsif ($#forms < $#norms) {
	if ($forms[0] eq '*') {
	    push(@forms, '*') while $#forms < $#norms;
	} else {
	    push(@forms, '0') while $#forms < $#norms;
	}
    }

    ## This is necessary to match the parts but should not be used as the output form of a PSU;
    ## use the version computed in f2_sig.c instead
    
    # rewrite '0' entries in @forms
    my $last_non_zero_i = 0;
    for (my $i = 0; $i <= $#forms; ++$i) {
	if ($forms[$i] eq '0') {
	    $forms[$i] = $last_non_zero_i;
	} else {
	    $last_non_zero_i = $forms[$i];
	}
   }

    my $matched_parts = 0;
#    foreach my $p (@{$e{'parts'}}) {
    foreach my $p (@entries_parts_lines) {
	my ($res_p,@matches) = parts_match(\@forms, \@norms, $psulang, $p);
	if ($#matches > 0) {
	    print_psu_sig(\%e, $psu_form, $res_p, @matches);
	    ++$matched_parts;
	    last;
	}
    }
    unless ($matched_parts) {
	if ($#parts_errors >= 0) {
	    bad(@parts_errors)
		unless $#parts_errors == 0 && $parts_errors[0] eq '#nowarn#';
	} else {
	    bad("unknown parts processing failure");
	    warn Dumper \%e;
	    warn "====\n";
	}
    }
    @parts_errors = ();
}

sub
find_in_coresigs {
    my($cf,$xgw) = @_;
    if (defined ${$psu_cfs{$cf}}{$xgw}) {
	return $xgw;
    } elsif (defined $psu_cfs{$cf}) {
	foreach my $gw (keys %{$psu_cfs{$cf}}) {
	    my @sigs = @{${$psu_cfs{$cf}}{$gw}};
	    foreach my $s (@sigs) {
		my $qxgw = quotemeta($xgw);
		if ($s =~ m#//[^\]]*$qxgw#) {
		    # warn "matched $cf\[$xgw] in $s\n";
		    return $s;
		}
	    }
	}
    }
#    warn "never matched $cf\[$xgw\]\n"; ## don't need this as it gets reported later
    undef;
}

sub
match_sense {
    my($sense,@sigs) = @_;
    my $qs = quotemeta($sense);
    my @m = grep(m#//.*?$qs.*?\]#, @sigs);
    if ($#m < 0) {
	@m = grep(m#\[.*?$qs.*?//#, @sigs);
    }
    if ($#m > 0) {
	my %s = ();
	foreach my $s (@m) {
	    my $tmp = $s;
	    $tmp =~ s#^.*?//(.*?)\].*$#$1#;
	    ++$s{$tmp};
	}
	if (scalar keys %s > 1) {
	    my @new_m = ();
	    foreach my $s (@m) {
		if ($s =~ m#//$qs\]# || $s =~ m#\[$qs//#) {
		    push @new_m, $s;
		}
	    }
	    if ($#m < 0) {
		bad("$sense matches more than one sense: ", join(', ', keys %s));
	    } else {
		@m = @new_m;
	    }
	}
    }
    @m;
}

sub
parts_match {
    my ($forms_ref, $norms_ref, $psulang, $parts_line_ref) = @_;
    my @forms = @$forms_ref;
    my @norms = @$norms_ref;
    my @parts_data = ();
    my $partskey = "$psulang\:$$parts_line_ref[1]";

    my $parts_ref = $validated_parts_lines{$partskey};
    if (!$parts_ref) {
	if ($bad_parts_lines{$partskey}) {
	    @parts_errors = ('#nowarn#');
	    return ();
	}
	if ((@parts_data = validate_parts($psulang, @$parts_line_ref))) {
	    $validated_parts_lines{$partskey} = [ @parts_data ];
	} else {
	    ++$bad_parts_lines{$partskey};
	    @parts_errors = ('#nowarn#');
	    return ();
	}	
    } else {
	@parts_data = @$parts_ref;
    }

    if ($#forms > $#parts_data) {
	push @parts_errors, "`@forms' has too many forms for $psu_parts";
	return ();
    }

    if ($#norms != $#parts_data) {
	my $nnorms = $#parts_data + 1;
	push @parts_errors, "`@norms' should have $nnorms members; missing '\$' in \@form line?";
	return ();
    }

    my $matched = 1;
    my @matched_candidates = ();
    # Iterate over the parts of the compound, i.e., @forms/@norms/@parts 
    # and look for a FORM/NORM match--we already know the @candidates match
    # as far as SENSE.  Just stop at the first match and take that; we 
    # don't care about ambiguity because there shouldn't be any.
    for (my $i = 0; $i <= $#forms; ++$i) {
	if (!$parts_data[$i]) {
	    push @parts_errors, "PSU $psu_parts: no parts data for form $forms[$i]"
		unless $#parts_errors == 0;
	    return ();
	}
	my ($pt, $csig, @candidates) = @{$parts_data[$i]}; chomp @candidates;
	my $this_form_matched = 0;
	my @tmp_matches = ();
	my $pass_1 = 1;
      match_pass_1:
	{
	    for (my $j = 0; $j <= $#candidates; ++$j) {
		my($form,$norm) = ($candidates[$j] =~ m#:(.*?)=.*?\$(.*?)(?:$|[/+\#\@])#);
		if ($form && $form eq $forms[$i] 
		    && ($norm eq '*' || $norms[$i] eq '*' || 
		    $norm eq $norms[$i])) {
		    if ($pass_1) {
			if ($candidates[$j] =~ /\%$psulang\:/) {
			    warn "pass_1_matched $form eq $forms[$i]/$norm eq $norms[$i] in $candidates[$j]\n"
				if $verbose;
			    $this_form_matched = 1;
			    $matched_candidates[$i] = $candidates[$j];
			    last match_pass_1;
			}
		    } else {
			warn "pass_2_matched $form eq $forms[$i]/$norm eq $norms[$i] in $candidates[$j]\n"
			    if $verbose;
			$this_form_matched = 1;
			$matched_candidates[$i] = $candidates[$j];
			last match_pass_1;
		    }
		}
	    }
	    if ($pass_1) {
		$pass_1 = 0;
		goto match_pass_1;
	    }
	}

	unless ($this_form_matched) {
	    $matched = 0;
	    push @parts_errors, "no form/norm match on '$forms[$i]' = simple sig '$csig\$$norms[$i]' in `$psulang.glo'"
		unless $#parts_errors == 0;
	    last;
	}
    }
    return ( [@parts_data] , @matched_candidates );
}

sub
print_psu_sig {
    my ($eref, $psuform, $res_ref, @sigs) = @_;
    my @p = ();
    foreach my $r (@$res_ref) {
	push @p, $$r[0];
    }
    my $psusig = join('++', @sigs);
    push (@sigs_psus, 
	  "{$psuform = @p += $$eref{'cf'}\[$$eref{'gw'}//$$eref{'sense'}\]$$eref{'pos'}'$$eref{'epos'}}"
	  .'::'.$psusig."\t0\n");
    push (@psu_parts, "@p\t".$psusig."\n");
}

sub
validate_parts {
    my($psulang, $lnum, $p) = @_;
    my $status = 0;
    $p =~ s/^\@parts\s+//;
    $p =~ s/\s[\%\#\@\/\+]\S+/ /g;
    $p =~ s/\s+/ /g;
    $p =~ s/(\]\S+)\s+/$1\cA/g;
    my @parts = grep defined&&length, split(/\cA/,$p);
    my @ret = ();
    foreach my $pt (@parts) {
	my($cf,$gw) = ($pt =~ /^(.*?)\[(.*?)(?:\/\/|\])/);
	my($pos,$epos) = ('','');
	my $sense = '';
	if (($gw = find_in_coresigs($cf,$gw))) {
	    if ($gw =~ /\[/) { # the return was a matched coresig, not a simple GW
		my($xgw,$xsense,$xpos,$xepos) = ($gw =~ m#^.*?\[(.*?)//(.*?)\](.*?)'(.*?)#);
		if ($pos && $pos != $xpos && $pos != $xepos) {
		    bad2($lnum,"$pt has wrong POS or EPOS in `$psulang.glo'");
		    $status = 1;
		} else {
		    # Now it will be as though the part contained a full coresig
		    ($gw,$sense,$pos,$epos) = ($xgw,$xsense,$xpos,$xepos);
		}
	    } else {
		if ($pt =~ /\](.*?)'([A-Za-z\/]+)/) {
		    ($pos,$epos) = ($1,$2);
		} else {
		    $pt =~ /\]([A-Za-z\/]+)/;
		    $pos = $1;
		}
	    }

	    my @pt_matches = @{${$psu_cfs{$cf}}{$gw}};
	    if ($epos) {
		bad2($lnum,"if you give EPOS in \@parts you must also give POS")
		    unless $pos;
		my @pos_matches = grep(/\]$pos'$epos/, @pt_matches);
		if ($#pos_matches < 0) {
		    bad2($lnum,"$pt has wrong POS or EPOS in `$psulang.glo'");
		} else {
		    @pt_matches = @pos_matches;
		}
	    } else {
		my $qpos = quotemeta($pos);
		my @pos_matches = grep(/\]$qpos\'/, @pt_matches);
		if ($#pos_matches < 0) {
		    @pos_matches = grep /\].*?\'$qpos$/, @pt_matches;
		    if ($#pos_matches < 0) {
			bad2($lnum,"$pt has wrong POS in `$psulang.glo'");
		    } else {
			$epos = $pos;
			$pos_matches[0] =~ /\](.*?)'/;
			$pos = $1;
		    }
		} else {
		    @pt_matches = @pos_matches;
		}
	    }
	    if ($pt =~ m#//(.*?)\]#) {
		$sense = $1;
	    } else {
		$sense = $gw;
	    }
	    my @sense_matches = match_sense($sense, @pt_matches);
	    if ($#sense_matches < 0) {
		bad "$pt should match a SENSE of $cf\[$gw\] in `$psulang.glo' but doesn't";
	    } else {
		@pt_matches = @sense_matches;
	    }
	    
	    # Now create the canonical base sig for the part; we require 
	    # at least CF[GW] so we may have to supply SENSE/POS/EPOS

	    unless ($sense && $pos && $epos) {
#		warn "pt_matches[0] = $pt_matches[0]\n";
		$pt_matches[0] =~ m#//(.*?)\](.*?)'([A-Za-z/]+)#;
		$sense = $1 unless $sense;
		$pos = $2 unless $pos;
		$epos = $3 unless $epos;
	    }
	    $epos = $pos unless $epos;

	    my $csig = "$cf\[$gw//$sense\]$pos'$epos";
#	    warn "csig = $csig\n";
	    my @simple_matches = ();
	    foreach my $ptm (@pt_matches) {
		if ($ptm && $simple{$ptm}) {
		    push(@simple_matches, @{$simple{$ptm}});
		} else {
		    if ($ptm) {
			warn "l2p1-psus.plx: XXXno match for $ptm in 01tmp/l2p1-simple.sig\n";
		    } else {
			chomp;
			warn "01tmp/l2p1-simple.sig:$.: l2p1-psus.plx: undefined part in $_\n";
		    }
		}
	    }
	    push @ret, [ $pt , $csig , @simple_matches ];
	} else {
	    bad2($lnum,"$pt does not match a known CF[GW] in `$psulang.glo'");
	    $status = 1;
	}
    }
    if ($status) {
	();
    } else {
	@ret;
    }
}

sub psu_dump {
    open(P, ">01bld/$lang/parts.map");
    print P @psu_parts;
    close(P);
}

######################################################################

sub sigs_dump {
    mkdir -p "01bld/$lang";
    $sigs_glo_file = "01bld/$lang/from_glo.sig";
    open(SIGS, ">$sigs_glo_file");
    print SIGS "\@fields sig rank\n";
    print SIGS @sigs_simple;
    print SIGS @sigs_cofs;
    print SIGS @sigs_psus;
    close(SIGS);
    
    open(CORESIGS, ">01bld/$lang/coresigs.txt");
    print CORESIGS join("\n", @sigs_coresigs), "\n";
    close(CORESIGS);
}

1;
