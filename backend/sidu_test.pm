package test;

=head1 NAME
test -- implements methods for regression tests

=head1 Summary
Implements test routines similar junit.

=head1 Author
hamatoma (C) 2013

=cut

use strict;

# Builds a pointer to the first different position of 2 strings.
# @param x	1st string
# @param y	2nd string
# @return	the pointer, e.g. "-----^"
sub MkPointer{
	my $x = shift;
	my $y = shift;
	my $len = 1;
	while($len < length($x) && substr($x, $len) == substr($y, $len)){
		$len++;
	}
	my $ptr = ("-" x $len) . "^";
	return $ptr;
}

#== Tests equality of two strings.
# @param prefix	id of the test
# @param x		first string
# @param y		2nd string
# @return		0: different 1: equal
sub Equal{
	my $prefix = shift;
	my $x = shift;
	my $y = shift;
	if ($x ne $y){
		if ($x !~ /\n/){
			print "Difference at $prefix:\n$x\n$y\n", 
				MkPointer($x, $y), "\n";
		} else {
			my @x = split(/\n/, $x);
			my @y = split(/\n/, $y);
			my ($ix, $max) = (0, $#x);
			$max = $#y if $#x < $#y;
			while($ix <= $max){
				if ($x[$ix] ne $y[$ix]){
					print "Difference at $prefix in line ", $ix + 1, "\n", 
						$x[$ix], "\n", $y[$ix], "\n",
						MkPointer($x[$ix], $y[$ix]), "\n";
					last;
				}
				$ix++;
			}
		}
	}
	return $x eq $y;
}

#== Tests equality of two arrays.
# @param prefix	id of the test
# @param x		first array (reference)
# @param y		2nd array (reference)
# @param sep	separator, should not part of the strings. Default: "|"
# @return		0: different 1: equal
sub EqualArray{
	my $prefix = shift;
	my $refX = shift;
	my $refY = shift;
	my $sep = shift;
	my $sepX = substr($$refX[0], -1);
	my $sepY = substr($$refY[0], -1);
	my $tailX = "";
	my $tailY = "";
	if ($sepX eq "\n" && $sepY eq "\n"){
	    ($sepX, $sepY) = ("", "");
	} elsif ($sepX eq "\n" && $sepY ne "\n"){
	    ($sepX, $sepY, $tailY) = ("", "\n", "\n");
	} elsif ($sepX ne "\n" && $sepY eq "\n"){
	    ($sepX, $sepY, $tailX) = ("\n", "", "\n");
	} else {
	   $sep = "|" unless $sep;
	   ($sepX, $sepY) = ($sep, $sep);
	}
	my $x = join($sepX, @$refX) . $tailX;
	my $y = join($sepY, @$refY) . $tailY;
	return Equal($prefix, $x, $y);
}

#== 
# Tests equality of two hashes.
# @param prefix	id of the test
# @param x		first hash (reference)
# @param y		2nd hask (reference)
# @param sep	separator, should not part of the strings. Default: "|"
# @return		0: different 1: equal
sub EqualHash{
	my $prefix = shift;
	my $refX = shift;
	my $refY = shift;
	my $sep = shift;
	my (@x, @y);
	for (sort keys %$refX){
		my $val = $$refX{$_};
		$val =~ s/\s+$//;
		$val =~ s/\t/ /g;
		push(@x, "$_=>$val");
	} 
	for (sort keys %$refY){
		my $val = $$refY{$_};
		$val =~ s/\s+$//;
		$val =~ s/\t/ /g;
		push(@y, "$_=>" . $val);
	} 
	return EqualArray($prefix, \@x, \@y, $sep);
}
#===
# Builds a hash from a string.
# @param x		string to convert. Starts with a separator, e.g. ";a=>1;b=>3"
# @return		the hash
sub toHash{
	my $x = shift;
	my %hash;
	my $sep = substr($x, 0, 1);
	$x = substr($x, 1);
	my @x = split(/$sep/, $x);
	foreach(@x){
		my @y = split(/=>/, $_);
		$hash{$y[0]} = $y[1];
	}
	return \%hash;
}


return 1;
