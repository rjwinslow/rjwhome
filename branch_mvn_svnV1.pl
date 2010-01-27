#!/usr/local/tools/perl/bin/perl
use strict;
use warnings;
my $debug = 0;
my $exe = (split /\//, $0)[-1];

=head1 NAME

branch_mvn_svn.pl - create a branch of a maven svn repository, or a patch of a maven svn branch.

=head1 SYNOPSIS

C<< branch_mvn_svn.pl [ -patch ] http://<URL> <branch_version> <parent_version> <ticket_no> <dev1> [ <dev2> ... ] >>

=cut

my $Usage = "$exe: Usage: $exe [-patch] <baseURL> <version> <parent_version> ".
  "<ticket_num> <developer1> [<dev2> ...]\n";
$Usage .= "  $exe -h or --help for more detail\n".
  "    <baseURL> must end /trunk or /branches/...\n".
  "    -patch is used to create a patch branch of an existing branch\n".
  "    <version> and <parent_version> must look like <number>.<number>\n".
  "      or <number>.<number>.<number> and <parent_version> may have a\n".
  "      trailing \"-SNAPSHOT\" string.\n".
  "    <ticket_num> is a six or seven digit ticket #\n".
  "    one or more developers must be given access to new branch.\n";

=head1 DESCRIPTION

Optional arguments:

=over 8

=item
-h or --help   show long helper documentation and exit

=item
-p or --patch    create a patch branch for some branch

=back

Required arguments: 

=over 8

=item
1) URL of trunk or branch from which to branch,

=item
2) version number of new branch,

=item
3) parent version (in pom.xml),

=item
4) ticket number of trouble ticket which requested the new branch (for commital messages),

=item
5) one or more developer uids with access to the new branch.

=back

All arguments may be specified on the command line, where the branch version
must precede the parent version.  Other arguments are discerned by their
formats.  Arguments not specified on the command line are prompted for.

Parent version, to be more specific, is the version of legacy_parent 
associated with the requested branch.

This tool may be used to create private branches.  In that case, the
version information shouldn't be specified on the command line (where it's
checked closely for format).  Version checking is loosened during interactive
version gathering. Specify exactly the same version string twice to override
version checking.

When the -p or --patch arguments occur, a branch whose name is the first two
numbers of the branch version followed by the string "-patch" is created
from the base branch. If the base URL is a branch, -p assumes the first two
numbers of the branch name will be the base of the patch name.

Developer uids must always be the last arguments on the command line when they
are specified on the command line.

=cut

# gather command line arguments
my $URL = '';
my $version = '';
my $p_version = '';
my $TicketNo;
my $patch_flag = 0;
my @developers = ();
my $pd = '/usr/local/tools/perl/bin/pod2text';
foreach my $arg (@ARGV)		# from the command line,
    { if($arg =~ m{^http://devsvn.gspt.net/svn/[^/]+/[^/]+/})
	{ $URL = $arg;
	next
	};
    if($arg =~ /^-{1,2}pa?t?c?h?$/)
	{ $patch_flag = 1;
	next
	};
    if($arg =~ /^-{1,2}he?l?p?/) { my $H = "$pd $0"; print `$H`; exit };
    if($arg =~ /^\d{6,7}$/) { $TicketNo = $arg; next };
    if(&versionOK($arg))
	{ if(!length($version))
	    { $version = $arg }
	elsif(!length($p_version)) { $p_version = $arg }
	else { my $Msg = "Too many versions: branch version is $version,\n";
	    $Msg .= "parent version is $p_version: ignoring $arg\n";
	    warn $Msg;
	    };
	next
	};
    if(&versionOK($arg))
	{ $p_version = $arg
	};
    if($arg =~ /^debug=(\d)/i) { $debug = $1; next };
    if(-d "/home/$arg") { push @developers, $arg }
    else { warn "$exe: Unrecognized argument: $arg; ignored\n" };
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

if($patch_flag && length($URL) && $URL =~ m{/branches/(\d{1,2}\.\d{1,2})})
    { if(!length($version)) { $version = "$1-patch" }; };
my $versionErr =
 "Version $version format error:\n".
 "The branch version must be 2 or 3 numbers seperated by periods\n";
my $verHold = '';
while(!&versionOK($version))
    { if(length($version))
	{ warn $versionErr;
	if(!length($verHold)) { $verHold = $version }
	elsif($verHold eq $version)
	    { warn "WARNING! assuming this request is for a private branch\n".
		"Using illegal version format $verHold as version\n";
	    last
	    };
	};
    print "Please enter the desired branch version:\n";
    $version = <STDIN>;
    chomp $version;
    $version =~ s/\s+//g;
    };
if($patch_flag && $version =~ /^(\d{1,2}\.\d{1,2})\.?/)
    { $version = "$1-patch" };

my $PversionErr =
 "Parent version $p_version format error:\n".
 "The parent version must be 2 or 3 numbers seperated by periods,\n".
 "optionally followed by the string \"-SNAPSHOT\"\n";
while($p_version !~ /^\d{1,2}\.\d{1,2}$/)
    { last if($p_version =~ /^\d{1,2}\.\d{1,2}\.\d{1,2}$/);
    last if($p_version =~ /\d\.\d{1,2}-SNAPSHOT$/);
    if(length($p_version))
	{ warn $PversionErr;
	};
    print "Please enter legacy_parent version:\n";
    $p_version = <STDIN>;
    chomp $p_version;
    $p_version =~ s/\s+//g;
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
# confirm that the requested branch doesn't already exist
my $CMD = '/usr/bin/svn ls '.$branch.' 2>&1';
my $result = `$CMD`;
if(!defined($result) || $result !~ / non-existent in that rev/)
    { die "$exe: $branch already exists\n" };

# all required parameters have been collected and validated
# advise of our intention and get consent
print "Ready to branch $URL\n   to $branch\n     for Ticket $TicketNo ".
  "for developers: @developers\nEnter Yes or OK to proceed\n";
my $OK = <STDIN>;
chomp $OK;
unless($OK =~ /ye?s?/i || $OK =~ /ok/i) { exit };

# fetch the trunk (or branch) on which to base the new branch
my $TMP = '';		# first create a temporary directory to hold the branch
if(-d '/tmp/scripts'.$$)
    { die "$exe: giving up: /tmp/scripts$$ directory exists\n" }
else { $TMP = "/tmp/scripts$$" };
# check out the permissions files for each svn group of repositories
# first, fetch the Shared Services group config file
$CMD = "/usr/bin/svn co http://devsvn.gspt.net/svn/operations/".
  "shared_services/svn_configuration/trunk $TMP";
$result = `$CMD`;
if($result !~ /Checked out revision \d/)
    { die "$exe: Failed to fetch shared_services/svn_configuration: $result" };

# edit the svn permissions file for the requested group
# give myself access to the requested repository for pom.xml processing
if($debug) { print "Editing svnperms.conf.$group to give $ENV{'USER'} access ".
  "to pom.xml\n" };
my $CNF = "$TMP/svnperms.conf.$group";
# this in place edit is OK because svnperm.conf files are small
open(CNF,'+<',$CNF) || die "$exe: can't update $CNF: $!\n";
my @CNF = <CNF>;
# $finalLine holds the line to be used in the last commit of the
# svnperm.conf file for this group. The one written now also includes temporary
# (for the time the script runs) permissions for the person who runs this tool
my $finalLine = '';
my $finalIndex = -1;	# holds point in file where $finalLine goes
foreach my $lidx (0 .. $#CNF)
    { if($CNF[$lidx] =~ m{\[$repos\]})
	{ $finalLine = $CNF[$lidx];
	$finalIndex = $lidx;
	$CNF[$lidx] .= '/.* = '.$ENV{'USER'}.'(add,remove,update)'."\n";
	$CNF[$lidx] .= "branches/$version/.* = ";
	$finalLine .= "branches/$version/.* = ";
	$CNF[$lidx] .= join ',', @developers;
	$finalLine .= join ',', @developers;
	$CNF[$lidx] .= '(add,update,remove)'."\n";
	$finalLine .= '(add,update,remove)'."\n";
	};
    };
if($debug)
    { print "Added:\n---\n".$CNF[$finalIndex].
	"---\n   to svnperms.conf.$group in $TMP\n"
    };
seek(CNF,0,0) || die "$exe: seek on $CNF failed: $!\n";
print CNF @CNF;
truncate(CNF,tell(CNF)) or die "$exe: truncation of $CNF failed: $!\n";;
close(CNF) or die "$exe: closure of $CNF failed: $!\n";
# commit the temporary changes to permissions for this repository
$CMD = "/usr/bin/svn commit -m \"Ticket $TicketNo; Preparing $branch\" $CNF";
$result = `$CMD`;
if($result !~ /Committed revision \d/)
    { die "$exe: can't commit $CNF: $result" };

# new branches for old
print "Branching $URL to $branch\n--------\n";
my $comment = '"'."Ticket $TicketNo; Creating branch $version".'"';
$CMD = "/usr/bin/svn copy  -m $comment $URL $branch";
$result = ($debug)?'':`$CMD`;
if(defined($result) && $result !~ /Committed revision \d/) 
    { print "$CMD\n$result" };

# now edit the pom.xml for the new branch
my $PMI = $URL;
$PMI .= ($URL =~ m{/$})?'pom.xml':'/pom.xml';
print "Fetch $PMI\n-----------\n";
my $branch_dir;
if(-d "/tmp/BRANCH$$")
    { die "$exe: giving up: /tmp/BRANCH$$ exists\n" }
else { $branch_dir = "/tmp/BRANCH$$" };
# since the new branch is a copy (by svn) of $URL, either of the following
# should work except when debugging - we choose to checkout from $branch
# normally as a belt-and-suspenders check of the svn copy
$CMD = ($debug)?"/usr/bin/svn co $URL $branch_dir":
		"/usr/bin/svn co $branch $branch_dir";
$result = `$CMD`;
if($debug) { print "$CMD\n";
    my @result = split m{\n}, $result;
    my $idx = $#result - 5;
    for ($idx, $idx <= $#result, $idx++)
	{ print $result[$idx]."\n" };
    };
if(defined($result) && length($result)) {} else { print "$CMD\nFailed!\n" };

# the following commital finalizes the branch just copied above
$comment = '"'."Ticket $TicketNo; Updating $branch/pom.xml".'"';
$CMD = "/usr/bin/svn commit -m $comment $branch_dir";
if($debug) { $result = '  Did NOT actually commit'."\n" }
else { $result = `$CMD` };
if(defined($result) && length($result)) { print "$CMD\n$result" };

my $SPM = "$branch_dir/pom.xml";
if(!-f $SPM)
    { print "$branch contains no pom.xml file; assuming private branch.\n".
	"WARNING: pom.xml NOT edited WARNING\n";
    }
else { &edit_pom($SPM) };

# remove permissions for myself for this repository
open(CNF,'+<',$CNF) || die "$exe: can't update $CNF: $!\n";
$CNF[$finalIndex] = $finalLine;
seek(CNF,0,0);
print CNF @CNF;
truncate(CNF,tell(CNF)) or die "$exe: truncation of $CNF failed: $!\n";;
close(CNF) or die "$exe: closure of $CNF failed: $!\n";
# commit the changes to permissions for this repository
$comment = '"'."Ticket $TicketNo; Finalizing $branch".'"';
$CMD = "/usr/bin/svn commit -m $comment $CNF";
if($debug) { print "$CMD\n"; $result = "Committed revision 0NOT!!\n" }
else { $result = `$CMD` };
if($result !~ /Committed revision \d/)
    { die "$exe: can't commit $CNF: $result" };

# clean up 
$CMD = '/bin/rm -rf '.$TMP;
$result = `$CMD`;
if(defined($result) && length($result)) { print "$CMD\n$result" };

$CMD = '/bin/rm -rf '.$branch_dir;
$result = `$CMD`;
if(defined($result) && length($result)) { print "$CMD\n$result" };

exit 0;

sub versionOK {
my ($ver) = @_;

if($patch_flag) { $ver =~ s/-patch$// };
$ver =~ s/-SNAPSHOT$//;
if($ver =~ /^\d{1,2}\.\d{1,2}$/) { return 1 }
elsif($ver =~ /^\d{1,2}\.\d{1,2}\.\d{1,2}$/) { return 1 }
else { return 0 };
}

sub edit_pom {
my ($PMI) = @_;		# $PMI holds input pom.xml file

open(POM,$PMI) ||
  die "$exe: can't read $PMI: $!\n";
my @lines = <POM>;	# collect input data into lines array
close POM;

my $POM = '/tmp/pom.xml';	# $POM is temporary edited file
open(POM,"> $POM") or die "$0: can't write $POM: $!\n";
my $needVersion = 1;	# flag noting that main version not yet recorded
my $editsDone = 0;	# we need to update the main pom version and parent ver
my $skipTo = '';
my $inParent = 0;
# the following editing is done the 'standard' way most of the time, but in
# reverse when working on the certain repositories.  The <parent> section
# follows the main <version> declaration for most repos, but precedes it
# for the legacy_parent repo (and a few others) - editing of <version>
#sections is regulated by a combination of $needVersion and $inParent
# values.  $editsDone just confirms that each section was updated and is
# independant (sort of) of the rest.
foreach my $line (@lines)
    { if($line =~ /<parent>/)
	{ $needVersion = 0;	# flag don't need main version 'til </parent>
	$inParent++;		# flag next <version> seen is parent version
	};
    if($inParent)
	{ if($line =~ s{<version>.+</version>}{<version>$p_version</version>})
	    { $editsDone++;	# count parent version update
	    };
	};
    if($line =~ m{</parent>}) { $inParent = 0; $needVersion = 1; };
    if(length($skipTo) && $line !~ /$skipTo/) { next };
    if(length($skipTo) && $line =~ /$skipTo/) { $skipTo = ''; next };
    if($needVersion)
	{ my $newVersion = '<version>'.$version;
	$newVersion .= ($patch_flag)?'':
	  ($version =~ /-SNAPSHOT$/)?'':'-SNAPSHOT';
	$newVersion .= '</version>';
	if($line =~ s{<version>.+</version>}{$newVersion})
	    { $editsDone++;	# count main version update
	    $needVersion = 0;	# and flag main version collected
	    };
	};
    if($line =~ /<scm>/)	# replace <scm> section with new one
	{ print POM "  <scm>\n    <connection>scm:svn:$base</connection>\n".
	    "    <developerConnection>scm:svn:$branch</developerConnection>\n".
	    "    <url>$base</url>\n  </scm>\n";
	$skipTo = '</scm>';	# ignore remainder of <scm> section
	next
	};
    print POM $line;
    }; close POM;
if($editsDone != 2) { warn "$exe: pom.xml editing FAILED; check $POM\n" };
$CMD = "/bin/mv /tmp/pom.xml $branch_dir";
if($debug)
    { $result = "  Did NOT mv; diff /tmp/pom.xml vs $branch_dir/pom.xml\n" }
else { $result = `$CMD` };
if(defined($result) && length($result)) { print "$CMD\n$result" };

$comment = '"'."Ticket $TicketNo; Updating $branch/pom.xml".'"';
$CMD = "/usr/bin/svn commit -m $comment $branch_dir";
if($debug) { $result = "  Did NOT actually commit pom.xml\n" }
else { $result = `$CMD` };
if(defined($result) && length($result)) { print "$CMD\n$result" };
}

=head1 COPYRIGHT

Copyright (c) 2009 by GSI Commerce, Inc. All Rights Reserved.

=head1 AUTHOR

Ralph Winslow, rjwinslow@rjwinslow.com

