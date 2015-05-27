#!/usr/local/bin/perl -w
# --- pre-preprocessor for C code ---
# preprocess C files before the C preprocessor acts,
# in order to correctly cut
# #ifdef / #else / #endif preprocessor directives
# so multiple C versions can be extracted from the 
# very same C source, based on a variable passed as argument
# Also, delete specially crafted C comments: ////
#
# by circulosmeos, May 2015. 
# http://circulosmeos.wordpress.com
# Licensed under GPL v3

use strict;

my $PROCESS_PREPROCESSOR_VARIABLE=1;
my $PROCESS_COMMENTS=1;
my $DEBUG=1;

# .................................................

my ($i, $line, $state, $count, $readThisLine);

# .................................................
# arguments:
if ( ($#ARGV+1)<4 ) {
	die "\npppc.pl file.source file.output VARIABLE {0|1}\n\n";
}

my $fIn = shift;
my $fOut = shift;
my $VARIABLE = shift;
my $VARIABLE_VALUE= shift;

if ($VARIABLE_VALUE!~/^[\"\']?([01])[\"\']?$/) {
	die "third argument must be 0 (false) or 1 (true)\nProcess stopped\n";
} else {
	$VARIABLE_VALUE=$1;
}

open fIn, '<', $fIn || 
	die "Error: couldn't open '$fIn'\nProcess stopped\n";

open fOut, '>', $fOut || 
	die "Error: couldn't open '$fOut'\nProcess stopped\n";

$readThisLine='';
$count=0;
$state=0;
	# $state machine:
	# 0: waiting for #ifdef
	# 1: extracting #ifdef lines until #else/#endif
	# 2: waiting #endif (or #else !), deleting lines in between
	# 3: extracting #else lines until # endif
while ($readThisLine ne '' or $line=<fIn>) {
	
	print $i++, " $state : $line" if ($DEBUG==1);

	if ($readThisLine ne '') {
		$line = $readThisLine;
		$readThisLine = '';
	}

	if ($PROCESS_COMMENTS == 1) {
		if ($line =~ m#^(.*?)\s*////.*$#) {
			# erase comments marked with "////"
			print $i, " X : $1\n" if ($DEBUG==1);
			if ( length($1)>0 ) {
				$line = $1. "\n";
			} else {
				next; # there's no line to process, in fact.
			}
			# and continue (as $line/$1 can be a preprocessor directive!)
		}
	}

	if ($PROCESS_PREPROCESSOR_VARIABLE == 0) {
		print fOut $line;
		next;
	}

	# #ifdef $VARIABLE
	if ( $line=~/^\#ifdef $VARIABLE/ ) {
		$count=0;
		if ($VARIABLE_VALUE == 1) {
			$state=1;
		} else {
			$state=2;
		}
		next;
	}

	# $state == 0
	# 0: waiting for #ifdef
	if ( $state == 0 ) {
		print fOut $line;
		next;
	}

	# count other possible preprocessor #ifdef/#else/#endif 
	# different from $VARIABLE
	if ( $state == 1 || $state == 2 || $state == 3) {
		if ( $line =~ /^#ifn?def/ ) {
			$count++;
		}
		# only if $count==0 this #else is for #ifdef $VARIABLE
		if ( $line =~ /^#else/ && $count == 0) { 
			$count--;
		}
		if ( $line =~ /^#endif/ ) {
			$count--;
		}
	}

	# $state == 1
	# 1: extracting #ifdef lines until #else/#endif
	if ( $state == 1 ) {
		if ( $count<0 ) { # #else/#endif of "#ifdef $VARIABLE"
			$count=0;
			if ( $line =~ /^#else/ ) {
				$state=2;
			}
			else {
				$state=0;
			}
		} else {
			print fOut $line;
		}
		next;
	}

	# $state == 2
	# 2: waiting #endif (or #else !), deleting lines in between
	if ( $state == 2 ) {
		if ($line =~ /^#else/) { # end of "#ifdef $VARIABLE", beginning of #else
			$count=0;
			$state=3;
		}
		if ( $count<0 ) { # end of "#ifdef $VARIABLE"
			$count=0;
			$state=0;
			$line = <fIn>;
			# if next line is empty, just get rid of it for code clarity
			if ( $line !~ /^[\s]*$/ ) {
				# but if it isn't empty, process it!
				$readThisLine = $line;
			}
		}
		next;
	}

	# $state == 3
	# 3: extracting #else lines until # endif
	if ( $state == 3 ) {
		if ( $count<0 ) { # end of "#ifdef $VARIABLE"
			$count=0;
			$state=0;
			#$line = <fIn>;
			# if next line is empty, just get rid of it for code clarity
			#if ( $line !~ /^[\s]*$/ ) {
			#	# but if it isn't empty, process it!
			#	$readThisLine = $line;
			#}
		} else {
			print fOut $line;
		}
		next;
	}

}

close fIn;
close fOut;
