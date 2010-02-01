# certlib.pl - Library routines for cert.pl, critpath.pl, etc.
# Copyright 2008-2009 by Sol Swords 
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, write to the Free Software Foundation, Inc., 675 Mass
# Ave, Cambridge, MA 02139, USA.
#
# NOTE.  This file is not part of the standard ACL2 books build process; it is
# part of an experimental build system that is not yet intended, for example,
# to be capable of running the whole regression.  The ACL2 developers do not
# maintain this file.  Please contact Sol Swords <sswords@cs.utexas.edu> with
# any questions/comments.


use strict;
use warnings;
use File::Basename;
use File::Spec;
use Cwd;
use Cwd 'abs_path';
use FindBin qw($RealBin);


my $BASE_PATH = abs_canonical_path(".");


sub human_time {

# human_time(secs,shortp) returns a string describing the time taken in a
# human-friendly format, e.g., 5.6 minutes, 10.3 hours, etc.  If shortp is
# given, then we use, e.g., "min" instead of "minutes."

    my $secs = shift;
    my $shortp = shift;

    if (!$secs) {
	return "???";
    }

    if ($secs < 60) {
	return sprintf("%.1f %s", $secs, $shortp ? "sec" : "seconds");
    }

    if ($secs < 60 * 60) {
	return sprintf("%.1f %s", ($secs / 60.0), $shortp ? "min" : "minutes");
    }

    return sprintf("%.2f %s", ($secs / (60 * 60)), $shortp ? "hr" : "hours");
}


# sub rm_dotdots {
#     my $path = shift;
#     while ($path =~ s/( |\/)[^\/\.]+\/\.\.\//$1/g) {}
#     return $path;
# }


sub rel_path {
    my $base = shift;
    my $path = shift;
    if (substr($path,0,1) eq "/") {
	return $path;
    } else {
	return "$base/$path";
    }
}


sub rec_readlink {
    my $path = shift;
    while (-l $path) {
	$path = readlink $path;
    }
    return $path;
}


sub abs_canonical_path {
    my $path = shift;
    my $abspath = File::Spec->rel2abs(rec_readlink($path));
    my ($vol, $dir, $file) = File::Spec->splitpath($abspath);
    my $absdir = abs_path($dir);
    if ($absdir) {
	return File::Spec->catpath($vol, $absdir, $file);
    } else {
	print "Warning: canonical_path: Directory not found: " . $dir . "\n";
	return 0;
    }
}


sub canonical_path {
    my $abs_path = abs_canonical_path(shift);
    if ($BASE_PATH) {
	return File::Spec->abs2rel($abs_path, $BASE_PATH);
    } else {
	return $abs_path;
    }
}


sub short_cert_name {

# Given a path to some ACL2 book, e.g., foo/bar/baz/blah.cert, we produce 
# a shortened version of the name, e.g., "baz/blah.cert".  Usually this is 
# enough to identify the book, and keeps the noise of the path down to a 
# minimum.

    my $certfile = shift;

    # Ordinary case for foo/bar/baz/blah.cert
    $certfile =~ m/^.*\/([^\/]*\/[^\/]*)$/;
    my $shortcert = $1;

    # Special case for, e.g., foo.cert:
    if (!$shortcert) {
	$shortcert = $certfile;
    }

    return $shortcert;
}


sub get_cert_time {

# Given a .cert file, gets the total user + system time recorded in the
# corresponding .time file.  If not found, prints a warning and returns 0.

    my $path = shift;
    my $warnings = shift;

    $path =~ s/\.cert$/\.time/;
    
    if (open (my $timefile, "<", $path)) {
	while (my $the_line = <$timefile>) {
	    my $regexp = "^([0-9]*\\.[0-9]*)user ([0-9]*\\.[0-9]*)system";
	    my @res = $the_line =~ m/$regexp/;
	    if (@res) {
		return 0.0 + $res[0] + $res[1];
	    }
	}
	push(@$warnings, "Corrupt timings in $path\n");
	return 0;
    } else {
	push(@$warnings, "Could not open $path\n");
	return 0;
    }
}


sub makefile_dependency_graph {

# makefile_dependency_graph(makefile-name)
#
# Records a dependency graph between cert files by looking through the Makefile
# and adding an entry for each line matching *.cert : *.cert.

    my $mkpath = shift;
    my %deps = ();

    open (my $mkfile, "<", $mkpath) or die "Failed to open makefile $mkpath\n";
    my $regexp = "^(.*\\.cert)[\\s]*:[\\s]*(.*\\.cert)";
    while (my $teh_line = <$mkfile>) {
	my @res = $teh_line =~ m/$regexp/;
	if (@res) {
	    push(@{$deps{$res[0]}}, $res[1]);
	}
    }

    return %deps;
}



sub make_costs_table_aux {

# make_costs_table_aux(file, deps, costs, warnings) -> cost
# May modify costs and warnings.
#
# Inputs:
#
#  - Certfile is a string, the name of the file to get the cost for.
#
#  - Deps is a reference to a dependency graph such as is generated by
#    makefile_dependency_graph.
# 
#  - Costs is a reference to the table of costs which we are constructing.

    my $certfile = shift;
    my $deps = shift;
    my $costs = shift;
    my $warnings = shift;

    if ($costs->{$certfile}) {
	return $costs->{$certfile};
    }

    my $certtime = get_cert_time($certfile, $warnings);
    my $certdeps = $deps->{$certfile};

    my $most_expensive_dep_total = 0;
    my $most_expensive_dep = 0;

    if ($certdeps) {
	foreach my $dep (@{$certdeps}) {
	    if ($dep =~ /\.cert$/) {
		my $this_dep_costs = make_costs_table_aux($dep, $deps, $costs, $warnings);
		my $this_dep_total = $this_dep_costs->{"totaltime"};
		if ($this_dep_total > $most_expensive_dep_total) {
		    $most_expensive_dep = $dep;
		    $most_expensive_dep_total = $this_dep_total;
		}
	    }
	}
    }
    my %entry = ( "shortcert" => short_cert_name($certfile),
		  "selftime" => $certtime, 
		  "totaltime" => $most_expensive_dep_total +
		                 ($certtime ? $certtime : 0.000001), 
		  "maxpath" => $most_expensive_dep );

    $costs->{$certfile} = \%entry;
    return $costs->{$certfile};
}


sub make_costs_table {

# make_costs_table (topfile, deps) -> (costs_table, warnings)

# For each cert file in the dependency graph, records a maximum-cost
# path, the path's cost, and the cert's own cost.

    my $certfile = shift;
    my $deps = shift;
    my %costs = ();
    my @warnings = ();
    my $maxcost = make_costs_table_aux($certfile, $deps, \%costs, \@warnings);
    return (\%costs, \@warnings);
}



sub warnings_report {

# warnings_report(warnings, htmlp) returns a string describing any warnings
# which were encountered during the generation of the costs table, such as for
# missing .time files.

    my $warnings = shift;
    my $htmlp = shift;

    unless (@$warnings) {
	return "";
    }

    my $ret;

    if ($htmlp) {
	$ret = "<dl class=\"critpath_warnings\">\n"
	     . "<dt>Warnings</dt>\n";
	foreach (@$warnings) {
	    chomp($_);
	    $ret .= "<dd>$_</dd>\n";
	}
	$ret .= "</dl>\n\n";
    }

    else  {
	$ret = "Warnings:\n\n";
	foreach (@$warnings) {
	    chomp($_);
	    $ret .= "$_\n";
	}
	$ret .= "\n\n";
    }

    return $ret;
}



sub critical_path_report {

# critical_path_report(file,costs,htmlp) returns a string describing the
# critical path for file according to the costs_table, either in TEXT or HTML
# format per the value of htmlp.

    my $file = shift;
    my $costs = shift;
    my $htmlp = shift;

    my $ret;

    if ($htmlp) {
	$ret = "<table class=\"critpath_table\">\n"
	     . "<tr class=\"critpath_head\">"
	     . "<th>Critical Path</th>" 
	     . "<th>Time</th>"
	     . "<th>Cumulative</th>"
	     . "</tr>\n";
    }
    else {
	$ret = "Critical Path\n\n"
	     . sprintf("%-50s %10s %10s\n", "File", "Cumulative", "Time");
    }

    while ($file) 
    {
	my $filecosts = $costs->{$file};
	my $shortcert = $filecosts->{"shortcert"};
	my $selftime = $filecosts->{"selftime"};
	my $cumtime = $filecosts->{"totaltime"};

	my $selftime_pr = $selftime ? human_time($selftime, 1) : "[Error]";
	my $cumtime_pr = $cumtime ? human_time($cumtime, 1) : "[Error]";
   
	if ($htmlp) {
	    $ret .= "<tr class=\"critpath_row\">"
	 	 . "<td class=\"critpath_name\">$shortcert</td>"
		 . "<td class=\"critpath_self\">$selftime_pr</td>"
		 . "<td class=\"critpath_total\">$cumtime_pr</td>"
		 . "</tr>\n";
	}
	else {
	    $ret .= sprintf("%-50s %10s %10s\n", $shortcert, $cumtime_pr, $selftime_pr);
	}

	$file = $filecosts->{"maxpath"};
    }

    if ($htmlp) {
	$ret .= "</table>\n\n";
    }
    else {
	$ret .= "\n\n";
    }

    return $ret;
}
	
sub classify_book_time {
    
# classify_book_time(secs) returns "low", "med", or "high".

    my $time = shift;

    return "err" if !$time;
    return "low" if ($time < 30);
    return "med" if ($time < 120);
    return "high";
}


sub individual_files_report {

# individual_files_report(costs,htmlp) returns a string describing the
# self-times of each file in the costs_table, either in either TEXT or HTML
# format, per the value of htmlp.

    my $costs = shift;
    my $htmlp = shift;
#    my %lines = ();
#    my $name;

#     foreach $name ( keys %$costs) {
#  	my $entry = $costs->{$name};
#  	my $shortcert = $entry->{"shortcert"};
# # 	my $selftime = $entry->{"selftime"};
# # 	my $totaltime = $entry->{"totaltime"};
# # 	my $maxpath = $entry->{"maxpath"};
# #	$lines{$shortcert} = $entry;
#     }

    my @sorted = reverse sort { ($costs->{$a}->{"totaltime"} + 0.0) <=> ($costs->{$b}->{"totaltime"} + 0.0) } keys(%{$costs});
    my $ret;
    if ($htmlp) 
    {
	$ret = "<table class=\"indiv_table\">\n"
	     . "<tr class=\"indiv_head\"><th>All Files</th> <th>Cumulative</th> <th>Self</th></tr>\n";
    } else {
	$ret = "Individual File Times\n\n";

    }


    foreach my $name (@sorted)
    {
	my $entry = $costs->{$name};
	my $short = $entry->{"shortcert"};
	my $cumul = $entry->{"totaltime"} ? human_time($entry->{"totaltime"}, 1) : "[Error]";
	my $time = $entry->{"selftime"} ? human_time($entry->{"selftime"}, 1) : "[Error]";
	my $depname = $entry->{"maxpath"} ? $costs->{$entry->{"maxpath"}}->{"shortcert"} : "[None]";
	my $timeclass = classify_book_time($entry->{"selftime"});

	if ($htmlp)
	{
	    $ret .= "<tr class=\"indiv_row\">";
	    $ret .= "<td class=\"indiv_file\">";
	    $ret .= "  <span class=\"indiv_file_name\">$short</span><br/>";
	    $ret .= "  <span class=\"indiv_crit_dep\">--> $depname</span>";
	    $ret .= "</td>";
	    $ret .= "<td class=\"indiv_cumul\">$cumul</td>";
	    $ret .= "<td class=\"indiv_time_$timeclass\">$time</td>";
	    $ret .= "</tr>\n";
	} else {
	    $ret .= sprintf("%-50s %10s %10s  --->  %-50s\n",
			    $short, $cumul, $time, $depname);
	}
    }
    
    if ($htmlp)
    {
	$ret .= "</table>\n\n";
    } else {
	$ret .= "\n\n";
    }

    return $ret;
}   






my $debugging = 0;
my $clean_certs = 0;
my $print_deps = 0;
my $all_deps = 0;
my %dirs = ( "SYSTEM" => $RealBin );

sub certlib_set_opts {
    my $opts = shift;
    $debugging = $opts->{"debugging"};
    $clean_certs = $opts->{"clean_certs"};
    $print_deps = $opts->{"print_deps"};
    $all_deps = $opts->{"all_deps"};
}

sub lookup_colon_dir {
    my $name = uc(shift);
    my $local_dirs = shift;

    my $dirpath = ($local_dirs && $local_dirs->{$name})
	|| $dirs{$name} ;
    return $dirpath;
}

sub get_include_book {
    my $base = shift;
    my $the_line = shift;
    my $local_dirs = shift;

    my $regexp = "^[^;]*\\(include-book[\\s]*\"([^\"]*)\"(?:.*:dir[\\s]*:([^\\s)]*))?";
    my @res = $the_line =~ m/$regexp/i;
    if (@res) {
	if ($res[1]) {
	    my $dirpath = lookup_colon_dir($res[1], $local_dirs);
	    unless ($dirpath) {
		print "Error: Unknown :dir entry $res[1] for $base\n";
		print_dirs($local_dirs) if $debugging;
		return 0;
	    }
	    return canonical_path(rel_path($dirpath, "$res[0].cert"));
	} else {
	    my $dir = dirname($base);
	    return canonical_path(rel_path($dir, "$res[0].cert"));
	}
    }
    return 0;
}

sub get_depends_on {
    my $base = shift;
    my $the_line = shift;
    my $local_dirs = shift;

    my $regexp = "\\(depends-on[\\s]*\"([^\"]*)\"(?:.*:dir[\\s]*:([^\\s)]*))?";
    my @res = $the_line =~ m/$regexp/i;
    if (@res) {
	if ($res[1]) {
	    my $dirpath = lookup_colon_dir($res[1], $local_dirs);
	    unless ($dirpath) {
		print "Error: Unknown :dir entry $res[1] for $base\n";
		print_dirs($local_dirs) if $debugging;
		return 0;
	    }
	    return canonical_path(rel_path($dirpath, "$res[0]"));
	} else {
	    my $dir = dirname($base);
	    return canonical_path(rel_path($dir, "$res[0]"));
	}
    }
    return 0;
}


# Possible more general way of recognizing a Lisp symbol:
# ((?:[^\\s\\\\|]|\\\\.|(?:\\|[^|]*\\|))*)
# - repeatedly matches either: a non-pipe, non-backslash, non-whitespace character,
#                              a backslash and subsequently any character, or
#                              a pair of pipes with a series of intervening non-pipe characters.
# For now, stick with a dumber, less error-prone method.


sub get_ld {
    my $base = shift;
    my $the_line = shift;
    my $local_dirs = shift;

    # Check for LD commands
    my $regexp = "^[^;]*\\(ld[\\s]*\"([^\"]*)\"(?:.*:dir[\\s]*:([^\\s)]*))?";
    my @res = $the_line =~ m/$regexp/i;
    if (@res) {
	if ($res[1]) {
	    my $dirpath = lookup_colon_dir($res[1], $local_dirs);
	    unless ($dirpath) {
		print "Error: Unknown :dir entry $res[1] for $base\n";
		print_dirs($local_dirs) if $debugging;
		return 0;
	    }
	    return canonical_path(rel_path($dirpath, $res[0]));
	} else {
	    my $dir = dirname($base);
	    return canonical_path(rel_path($dir, $res[0]));
	}
    }
    return 0;
}

sub get_add_dir {
    my $base = shift;
    my $the_line = shift;
    my $local_dirs = shift;

    # Check for ADD-INCLUDE-BOOK-DIR commands
    my $regexp = "^[^;]*\\(add-include-book-dir[\\s]+:([^\\s]*)[\\s]*\"([^\"]*)\\/\"";
    my @res = $the_line =~ m/$regexp/i;
    if (@res) {
	my $name = uc($res[0]);
	my $basedir = dirname($base);
	$local_dirs->{$name} = canonical_path(rel_path($basedir, $res[1]));
	print "Added local_dirs entry " . $local_dirs->{$name} . " for $name\n" if $debugging;
	print_dirs($local_dirs) if $debugging;
	return 1;
    }
}


sub newer_than {
    my $file1 = shift;
    my $file2 = shift;
    return ((stat($file1))[9]) > ((stat($file2))[9]);
}

sub excludep {
    my $prev = shift;
    my $dirname = dirname($prev);
    while ($dirname ne $prev) {
	if (-e rel_path($dirname, "cert_pl_exclude")) {
	    return 1;
	}
	$prev = $dirname;
	$dirname = dirname($dirname);
    }
    return 0;
}



sub print_dirs {
    my $local_dirs = shift;
    print "dirs:\n";
    while ( (my $k, my $v) = each (%{$local_dirs})) {
	print "$k -> $v\n";
    }
}

sub scan_ld {
    my $fname = shift;
    my $deps = shift;
    my $local_dirs = shift;

    print "scan_ld $fname\n" if $debugging;

    if ($fname) {
	push (@{$deps}, $fname);
	open(my $ld, "<", $fname);
	while (my $the_line = <$ld>) {
	    my $incl = get_include_book($fname, $the_line, $local_dirs);
	    my $depend =  $incl || get_depends_on($fname, $the_line, $local_dirs);
	    my $ld = $depend || get_ld($fname, $the_line, $local_dirs);
	    my $add = $ld || get_add_dir($fname, $the_line, $local_dirs);
	    if ($incl) {
		push(@{$deps}, $incl);
	    } elsif ($depend) {
		push(@{$deps}, $depend);
	    } elsif ($ld) {
		push(@{$deps}, $ld);
		scan_ld($ld, $deps, $local_dirs);
	    }
	}
	close($ld);
    }
}

sub scan_book {
    my $fname = shift;
    my $deps = shift;
    my $local_dirs = shift;

    print "scan_book $fname\n" if $debugging;

    if ($fname) {
	# Scan the lisp file for include-books.
	open(my $lisp, "<", $fname);
	while (my $the_line = <$lisp>) {
	    my $incl = get_include_book($fname, $the_line, $local_dirs);
	    my $dep = $incl || get_depends_on($fname, $the_line, $local_dirs);
	    my $add = $dep || get_add_dir($fname, $the_line, $local_dirs);
	    if ($incl) {
		push(@{$deps},$incl);
	    } elsif ($dep) {
		push(@{$deps}, $dep);
	    }
	}
	close($lisp);
    }
}
    

    
    


sub add_deps {
    my $target = shift;
    my $seen = shift;
    my $run_sources = shift;

    if (exists $seen->{$target}) {
	# We've already calculated this file's dependencies.
	return;
    }

    if ($target !~ /\.cert$/) {
	foreach my $run (@{$run_sources}) {
	    &$run($target);
	}
	$seen->{$target} = 0;
	return;
    }

    if (excludep($target)) {
	return;
    }

    print "add_deps $target\n" if $debugging;

    my $local_dirs = {};
    my $base = $target;
    $base =~ s/\.cert$//;
    my $pfile = $base . ".p";
    my $lispfile = $base . ".lisp";

    # Clean the cert and out files if we're cleaning.
    if ($clean_certs) {
	my $outfile = $base . ".out";
	my $timefile = $base . ".time";
	unlink($target) if (-e $target);
	unlink($outfile) if (-e $outfile);
	unlink($timefile) if (-e $timefile);
    }

    # First check that the corresponding .lisp file exists.
    if (! -e $lispfile) {
	print "Error: Need $lispfile to build $target.\n";
	return;
    }

    $seen->{$target} = [ $lispfile ];
    my $deps = $seen->{$target};

    # If a corresponding .acl2 file exists or otherwise if a
    # cert.acl2 file exists in the directory, we need to scan that for dependencies as well.
    my $acl2file = $base . ".acl2";
    if (! -e $acl2file) {
	$acl2file = rel_path(dirname($base), "cert.acl2");
	if (! -e $acl2file) {
	    $acl2file = 0;
	}
    }

    # Scan the .acl2 file first so that we get the add-include-book-dir
    # commands before the include-book commands.
    scan_ld($acl2file, $deps, $local_dirs);
    
    # Scan the lisp file for include-books.
    scan_book($lispfile, $deps, $local_dirs);
    
    # If there is an .image file corresponding to this file or a
    # cert.image in this file's directory, add a dependency on the
    # ACL2 image specified in that file.
    my $imagefile = $base . ".image";
    if (! -e $imagefile) {
	$imagefile = rel_path(dirname($base), "cert.image");
	if (! -e $imagefile) {
	    $imagefile = 0;
	}
    }

    if ($imagefile) {
	open(my $im, "<", $imagefile);
	my $line = <$im>;
	if ($line) {
	    if (substr($line,-1,1) eq "\n") {
		chop $line;
	    }
	    my $image = canonical_path(rel_path(dirname($base), $line));
	    if (! -e $image) {
		$image = substr(`which $line`,0,-1);
	    }
	    if (-e $image) {
		push(@{$deps}, canonical_path($image));
	    }
	}
    }

    if ($print_deps) {
	print "Dependencies for $target:\n";
	foreach my $dep (@{$deps}) {
	    print "$dep\n";
	}
	print "\n";
    }

    # Run the recursive add_deps on each dependency.
    foreach my $dep  (@{$deps}) {
	add_deps($dep, $seen, $run_sources);
    }
    

    # If this target needs an update or we're in all_deps mode, we're
    # done, otherwise we'll delete its entry in the dependency table.
    unless ($all_deps) {
	my $needs_update = (! -e $target);
	if (! $needs_update) {
	    foreach my $dep (@{$deps}) {
		if ((-e $dep && newer_than($dep, $target)) || $seen->{$dep}) {
		    $needs_update = 1;
		    last;
		}
	    }
	}
	if (! $needs_update) {
	    $seen->{$target} = 0;
	}
    }

}
