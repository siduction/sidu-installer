#! /usr/bin/perl

use strict;

my $input;
$input = shift if $#ARGV >= 0;
$input = "fw-detect -v|" unless $input;

my ($module, $ok, @missing, $missing);
if (open(FW, $input)){
	while(<FW>){
		chomp;
		if (/^Driver:\s(\S+)/){
			$module = $1;
			push(@missing, $missing) if $missing;
			$missing = "";
		} elsif (/^Firmware\sis\sokay/){
			$ok .= "|$module";
			$missing = "";
			$module = "";
		} elsif (/^(apt-get install|modprobe)/){
			$missing = $module unless $missing;
			$missing .= "|$_";
		}
	}
}
push(@missing, $missing) if $missing;
print "+$ok\n" if $ok;
print join("\n", @missing), "\n" if $#missing >= 0;
exit 0;

