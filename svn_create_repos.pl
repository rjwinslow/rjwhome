#!/usr/local/tools/perl/bin/perl
# svn_create_repos.pl - rewrite in perl of svn_create_repos.bash
# EXPERIMENTAL!!! 
use strict;
use warnings;
my $debug = 1;

use lib '/home/winslowr/bin';

use svn_create;

my $exe = (split /\//, $0)[-1];
$exe =~ s/\..*$//;

my $EDITOR = ($ENV{'EDITOR'})?$ENV{'EDITOR'}:'vi';

my $loc_box = `uname -n`;
chomp $loc_box;
if($loc_box ne 'secdevapp01.gspt.net')
    { die "$exe: you must run $exe on secdevapp01, not $loc_box\n" };

my $PERM_FILE = '';
my $NO_EDIT = 0;
my $group = '';
my $repos = '';
my @developers = ();
while(@ARGV)
    { my $arg = shift;
    if($arg =~ /^-n/i) { $NO_EDIT = 1; next };
    if($arg =~ /^-p$/i) { $PERM_FILE = shift; next };
    if($arg =~ /^-p=(.*)/i) { $PERM_FILE = $1; next };
    if(!length($group)) { $group = $arg; next };
    if(!length($repos)) { $repos = $arg; next };
    if(-d "/home/$arg") { push @developers, $arg; }
    else { warn "$arg has no home directory: ignored\n" };
    };
if(!length($group))
    { print "Please specify the group your repository should reside in:\n";
    $group = <STDIN>;
    chomp $group;
    $group =~ s{_GRP$}{};
    };
if(!svn_create::group_exists($group))
    { die "The $group group doesn't exist: run svn_create_group.pl\n" };

if(!length($repos))
    { print "What svn repository do you want to create?\n";
    $repos = <STDIN>;
    chomp $repos;
    };

while($#developers < 0)
    { print "Please enter uids of developers of the $repos repository ".
	'(blank line to finish):'."\n";
    while(my $devel = <STDIN>)
	{ chomp($devel);
	$devel =~ s/^\s*//;
	$devel =~ s/\s*$//;
	last if($devel !~ /^[a-z]/);
	my @devs = split /\s+/, $devel;
	foreach my $dev (@devs)
	    { if(!-d "/home/$dev")
		{ warn "$dev has no /home/$dev directory: ignoring\n"; next };
	    push @developers, $dev;
	    };
	};
    };

if($debug) { print "Checking group does; repos doesn't.\n" };
if(!-d "/opt/svn/${group}_GRP/reposroot")
    { die "ERROR: /opt/svn/${group}_GRP/reposroot does not exist!\n" };
if(-d "/opt/svn/${group}_GRP/reposroot/$repos")
    { die "ERROR: /opt/svn/${group}_GRP/reposroot/$repos already exists!\n" };

if($debug) { print "Setting permission file.\n" };
if(length($PERM_FILE)) { print "Using permission file $PERM_FILE\n" }
else { $PERM_FILE = &svn_create::pickAperm($group, $repos);
    if($debug) { print "Chose $PERM_FILE permissions file.\n" };
    };

my $Msg = "--------------------------------------------------------------\n".
  "        Subversion Repository Creation script\n\n".
  "        Running to setup:\n".
  "           Repo:  $repos\n".
  "        in\n           Group: $group\n\n".
  "        Adding the following users:\n           @developers\n\n".
  "--------------------------------------------------------------\n\nProceed?\n";
my $OK = svn_create::ask_user($Msg);
if($OK !~ /^y/) { die "Aborting\n" };

my $groupRoot = "/opt/svn/${group}_GRP/reposroot";
chdir($groupRoot) or die "Can't cd to $groupRoot: $!\n";
if($debug) { print "Working in $groupRoot\n" };

my $CMD = "/usr/bin/sudo /usr/bin/svnadmin create $repos";
my $result;
if($debug) { print "$exe wouldst: $CMD\n" } else {
$result = svn_create::do_command($CMD);
if(defined($result) && length($result)) { print "$CMD\n$result" };
};

$CMD = "/usr/bin/sudo /bin/chown -r apache:apache $repos";
if($debug) { print "$exe wouldst: $CMD\n" } else {
$result = svn_create::do_command($CMD);
if(defined($result) && length($result)) { print "$CMD\n$result" };
};

if($group ne 'partnercomponents')
    { print "Creating branches, tags, trunk in  http://devsvn.gspt.net/svn/".
	$group."/$repos.\n\nNOTE: At this time, enter your SVN password ".
	"if prompted.\n";
    $CMD = "/usr/bin/svn mkdir http://devsvn.gspt.net/svn/$group/$repos";
      if($debug) { print "$exe wouldst: $CMD\n" } else {
      my $response = svn_create::do_command($CMD.'trunk -m "Adding trunk"');
      if(defined($response) && length($response)) { print "$CMD\n$response" };
      $response = svn_create::do_command($CMD.'tags -m "Adding tags"');
      if(defined($response) && length($response)) { print "$CMD\n$response" };
      $response = svn_create::do_command($CMD.'branches -m "Adding branches"');
      if(defined($response) && length($response)) { print "$CMD\n$response" };
      };
    };
print "\n";

$CMD = "/usr/bin/sudo /bin/cp /opt/svn/scripts/pre-commit $repos/hooks";
if($debug) { print "$exe wouldst: $CMD\n" } else {
$result = svn_create::do_command($CMD);
if(defined($result) && length($result)) { print "$CMD\n$result" };
};

$CMD = "/usr/bin/sudo /bin/ln -s /opt/svn/scripts/pre-revprop-change $repos/hooks";
if($debug) { print "$exe wouldst: $CMD\n" } else {
$result = svn_create::do_command($CMD);
if(defined($result) && length($result)) { print "$CMD\n$result" };
};

&launch_editor($group, $repos, \@developers);

$Msg = '
# 
# ======================
# N E X T    S T E P S :
# ======================
#  
# Update FishEye: http://devsvn.gspt.net/fisheye/
#
# Edit http://confluence.gspt.net/display/ss/SVN+Repository+Information
';
$Msg .= "#     adding the $group group, and the $repos repository.\n#\n";
$Msg .= "# Please review permissions in /opt/svn/scripts/svnperms.conf.\n";
$Msg .= $group." for the $repos repository\n";

print "$Msg\n";
exit 0;
### -------------------------------------------------------------------

sub launch_editor {
my ($grp, $repo, $usersRef) = @_;

my @users = ();
push @users, @{$usersRef};

my $pBlock = ($grp eq 'partnercomponents')?
"
---------------------------------------
Add this group to svnperms.conf.$grp:
---------------------------------------

$repo-developers = @users

---------------------------------------
Add this repo to the bottom of the file:
---------------------------------------

[$repo]
".'/.* = @'."$repo-developers(add,remove,update)

":"
---------------------------------------
Add this group to svnperms.conf.$grp:
---------------------------------------

$repo-developers = @users

---------------------------------------
Add this repo to the bottom of the file:
---------------------------------------

[$repo]
".'trunk/.* = @'."$repo-developers(add,remove,update)
".'branches/.* = @'."$repo-developers(add,remove,update)
".'tags/([^/]+/)+ = *(add)'."

";
$pBlock .= "About to launch $EDITOR to edit the permissions.\n".
  "You can either copy the template above now or hit ^Z\n".
  "during your editing session to get this screen back.\n".
  "After copying the template, type 'fg' to return to $EDITOR.\n\n";

svn_create::ask_user($pBlock);
system("$EDITOR $PERM_FILE");
}

