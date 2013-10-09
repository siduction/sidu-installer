#! /usr/bin/perl

use strict;
use basic;
use test;

&TestAll;
exit 0;

sub TestAll{
    &TestScramble();
}

sub TestScramble{
    my ($x, $y, $z);
    $x = "a0!";
    $y = &Basic::Scramble($x, "!");
    $z = &Basic::UnScramble($y);
    die "different:\n$x\n$z" if $x ne $z;
    $x = "b7mQwHy"; 
    $y = Basic::UnScramble($x);
    die if $y ne "Ab0";
    $x = "8nB<njhc2QNP='8P+`d9_U<04!%I";
    $y = Basic::UnScramble($x);
    die unless $x ne "All you n33d is s3cret! ";
}