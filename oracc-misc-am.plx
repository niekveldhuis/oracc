#!/usr/bin/perl
use warnings; use strict;

use Data::Dumper;

my $dir = shift @ARGV;

my %ext_map = (
    sh=>'bin_SCRIPTS',
    plx=>'bin_SCRIPTS',
    chr=>'charmap_DATA',
    xcf=>'config_DATA',
    css=>'css_DATA',
    js=>'js_DATA',
    jar=>'java_DATA',
    class=>'java_DATA',
    el=>'emacsdata_DATA',
    tex=>'texdata_DATA',
    gif=>'img_DATA',
    png=>'img_DATA',
    jpg=>'img_DATA',
    esp=>'espdata_DATA',
    rnc=>'schema_DATA',
    xsl=>'scriptdata_DATA',
    xslt=>'scriptdata_DATA',
    pm=>'#extra',
    html=>'html_DATA',
    xml=>'data_DATA',
    am=>'#ignore',
    ttf=>'#extra',
    atf=>'#ignore',
    bak=>'#ignore',
    log=>'#ignore',
    ico=>'html_DATA',
    xtl=>'data_DATA',
    zip=>'#ignore',
    );

my @files = <*>;
my %in_files = ();
my %inst_files = ();
my %known_ignore = (
    'HOWTO' => 1,
    'log' => 1,
    'oracc-am-files' => 1,
    'README' => 1,
    'TODO'=> 1,
    'x' => 1
    );

my %oracc_am_files = ();
my $verbose = 0;

if (-r 'oracc-am-files') {
    push @{$inst_files{'#ignore'}}, 'oracc-am-files';
    open(OAM, 'oracc-am-files') 
	|| die "oracc-misc-am.plx: weird: $dir/oracc-am-files is readable but can't be opened\n";
    while (<OAM>) {
	next if m/^\s*$/ || m/^\#/;
	chomp;
	my($file,$dest) = (/^(.*?)\s+(.*?)$/);
	die "$dir/oracc-am-files:$.: bad syntax\n" unless $file && $dest;
	if ($file =~ /\.in$/) {
	    warn "oracc-misc-am.plx: files listed in oracc-am-files should not end with .in\n";
	}
	$oracc_am_files{$file} = $dest;
    }
    close(OAM);
}

foreach my $f (grep /\.in$/, @files) {
    add_file($f);
}

foreach my $f (grep !/\.in$/, @files) {
    add_file($f);
}

emit_makefile_am();

#############################################################################################

sub
add_file {
    my $f = shift;
    return if $f =~ /~$/ || $f =~ /^Make/ || ! -f $f;
    my $in_flag = ($f =~ s/\.in$//);
    ++$in_files{$f} if $in_flag;
    if (!$in_flag && $in_files{$f}) {
	warn "skipping $f because it has a .in version\n"
	    if $verbose;
    } else {
	if ($oracc_am_files{$f}) {
	    my $ext = $oracc_am_files{$f};
	    if ($ext eq 'ignore') {
		warn "ignoring $dir/$f as instructed by $dir/oracc-am-files\n"
		    if $verbose;
	    } else {
		push @{$inst_files{$ext}}, $f;
		warn "processing $dir/$f with in=$in_flag and ext=$ext\n"
		    if $verbose;
	    }
	} else {
	    my ($ext) = ($f =~ m/\.([^\.]+)$/);
	    if ($ext) {
		if ($ext_map{$ext}) {
		    push @{$inst_files{$ext_map{$ext}}}, $f;
		    warn "processing $dir/$f with in=$in_flag and ext=$ext\n"
			if $verbose;
		} else {
		    warn "cannot handle extension $ext on $dir/$f\n";
		}
	    } else {
		warn "cannot handle $dir/$f: add it to oracc-am-files\n"
		    unless $known_ignore{$f};
	    }
	}
    }
}

sub
emit_makefile_am {
    if (-r "Makefile.am") {
	warn "oracc-misc-am.plx: remove $dir/Makefile.am before generating new one\n";
	return;
    }
    open(AM, ">Makefile.am"); select AM;
    print "include ../../oracc-am-rules.txt\n\n";
    foreach my $ext (keys %inst_files) {
	next if $ext eq '#extra' || $ext eq '#ignore';
	print "$ext = @{$inst_files{$ext}}\n";
    }
    foreach my $in (keys %in_files) {
	print "\n$in: $in.in\n\t\$(ORACCIFY) $in.in\n";
    }
    my @extra = ();
    foreach my $dest (keys %inst_files) {
	next if $dest eq '#ignore';
	foreach my $f (@{$inst_files{$dest}}) {
	    if ($in_files{$f}) {
		push @extra, "$f.in";
	    } else {
		push @extra, $f;
	    }
	}
    }
    if ($#extra >= 0) {
	print "\nEXTRA_DIST = \\\n";
	@extra = sort @extra;
	my $last = pop @extra;
	foreach my $f (sort @extra) {
	    print "\t$f \\\n";
	}
	print "\t$last\n";
    }
    close(AM);
}

1;
