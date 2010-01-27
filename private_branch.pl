#!/usr/local/tools/perl/bin/perl
# private_branch.pl - create a branch of a maven svn repository.
#   Required arguments:  URL of trunk or branch from which to branch,
#      vresion number of new branch.
# All arguments may be specified on the command line, where the branch version
#  must precede the parent version.  Other arguments are discerned by their
#  formats.  Arguments not specified on the command line are prompted for.
use strict;
use warnings;
my $debug = 0;
my $exe = (split /\//, $0)[-1];
my $Usage = "$exe: Usage: $exe <baseURL> <version> ".
  "<developer1> [<dev2> ...]\n";
$Usage .= "    <baseURL> must end /trunk or /branches/...\n";
$Usage .=
  "    <version> may ba any string\n";
$Usage .= "    one or more developers must be given access to new branch.\n";

print "Notify requestor that no merges will be done\n";
# gather required arguments
my $URL = '';
my $version = '';
my $TicketNo;
my @developers = ();
foreach my $arg (@ARGV)		# from the command line,
    { if($arg =~ m{^http://devsvn.gspt.net/svn/[^/]+/[^/]+/})
	{ $URL = $arg;
	next
	};
    if($arg =~ /^\d{6,7}$/) { $TicketNo = $arg; next };
    if($arg =~ /^debug=(\d)/i) { $debug = $1; next };
    if($arg =~ /^[A-Z]\S+$/)
	{ if(!length($version)) { $version = $arg }
	else { warn "Too many versions: branch version is $version: ignoring $arg\n" };
	next
	};
    push @developers, $arg;
    };
# assure presence of all required arguments
while($URL !~ m{/trunk/?$})
    { last if($URL =~ m{/branches/\d{1,2}\.\d{1,2}/?$});
    last if($URL =~ m{/branches/\d{1,2}\.\d{1,2}\.\d{1,2}/?$});
    last if($URL =~ m{/branches/\d{1,2}\.\d{1,2}\.\d{1,2}-SNAPSHOT/?$});
    last if($URL =~ m{/branches/\d{1,2}\.\d{1,2}-SNAPSHOT/?$});
    warn "$Usage\nNo base URL seen; must end with trunk or branch.\n";
    print "Please enter the trunk or branch base URL to branch:\n";
    $URL = <STDIN>;
    chomp $URL;
    };

while(!length($version))
    { print "Please enter the desired branch version:\n";
    $version = <STDIN>;
    chomp $version;
    };

opendir(HOM,'/home') or die "$exe: can't read /home directory: $!\n";
my @homies = grep /^[a-z]/, readdir HOM;
closedir HOM;
while($#developers < 0)
    { print "You must specify at least one developer.\n";
    print "Enter one developer per line, and an empty line to terminate.\n";
    while(length(my $devel = <STDIN>))
	{ chomp $devel;
	$devel =~ s/\s//g;	# strip all spaces from UIDs
	last if(!length($devel));
	if($devel =~ /^[a-z]/)
	    { my $match = 0;
	    foreach my $DEV (@homies) { if($devel eq $DEV) { $match++; last }};
	    if(!$match)
		{ warn "$exe: $devel has no /home/$devel directory: Ignoring\n";
		next;
		};
	    push @developers, $devel;
	    }
	else { warn "Ignoring illegal developer name $devel\n" };
	};
    };

# while a trouble ticket number is typically six digits, anything is currently
# acceptable as a ticket number
if(!$TicketNo)
    { print "Please enter ticket number for svn commital message.\n";
    $TicketNo = <STDIN>;
    chomp $TicketNo;
    };

# set up the target branch name; extract group and repository names
# for use throughout
my $branch = $URL;
$branch =~ s{/trunk/?}{/};	# strip trunk or branch portion so we can
$branch =~ s{/branches/.*}{/};	# easily
my $base = $branch;
# extract the group & repository names
my ($group, $repos) = (split m{/}, $base)[-2,-1];
# establish the new branch name
$branch .= "branches/$version";

# advise of our intention and get consent
print "Ready to branch $URL\n   to $branch\n     for Ticket $TicketNo ".
  "for developers: @developers\nEnter Yes or OK to proceed\n";
my $OK = <STDIN>;
chomp $OK;
unless($OK =~ /ye?s?/i || $OK =~ /ok/i) { exit };

# new branches for old
my $result;
print "Branching $URL to $branch\n--------\n";
my $CMD = "/usr/bin/svn copy  -m \"Ticket $TicketNo; Creating branch $version\" $URL $branch";
if($debug) { print "$CMD\n" } else { $result = `$CMD` };

exit 0;
