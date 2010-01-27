#!/usr/bin/perl
use strict;
use warnings;

foreach my $arg (@ARGV)
    { if($arg =~ /\.[jw]ar$/) { print &get_ver($arg)."\n" };
    };
exit 0;

sub get_ver {
my $war = shift;
$war =~ m{(\d{1,2}\.\d{1,2}\.\d{1,2}-b-\d{1,2}).*\.[jw]ar};
return $1
}

