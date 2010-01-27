#!/usr/local/tools/perl/bin/perl
# svn_create_group.pl - rewrite in perl of svn_create_group.bash
# EXPERIMENTAL!!! - primarily written to add edit of viewvc.conf and the
# opportunity to specify users of each repository added
use strict;
use warnings;
my $debug = 1;

use lib '/home/winslowr/bin';
use svn_create;

my $exe = (split /\//, $0)[-1];
$exe =~ s/\..*$//;

my $Work_tmp = svn_create::get_work_dir;
chdir($Work_tmp) or die "Can't cd to $Work_tmp: $!\n";

# ########################
# ## Functions
# ########################

sub Usage {
die "$exe.pl - Create a new SVN group and repositories within the group.\n".
  "Usage:\t$exe.pl <GROUP> <REPO> [<REPO2 .. <REPOn>]\n";
}
 
# ########################
# ## MAIN
# ########################
# 
# #Cleanup on interrupt or termination

# trap "Cleanup" 2 3 15
$SIG{INT} = 'sig_handler';
$SIG{HUP} = 'sig_handler';
$SIG{QUIT} = 'sig_handler';

if($#ARGV < 1) { die &Usage };
my $group = shift(@ARGV);
svn_create::set_group($group);
 
if(!-d '/opt/svn/scripts')
    { die "ERROR: /opt/svn/scripts does not exist!\n".
	"You must run this script on the SVN server (secdevapp01).\n\n";
    };

my $loc_box = `uname -n`;
chomp $loc_box;
if($loc_box ne 'secdevapp01.gspt.net')
    { die "$exe: you must run $exe on secdevapp01, not $loc_box\n" };

if(svn_create::group_exists($group))
    { die "ERROR: $group already exists\nCan't create a group twice.\n\n";
    };

my @repos = @ARGV;

my $Msg = '--------------------------------------------------------------'."\n".
  '        Subversion Group Creation script'."\n\n".
  '        Running to setup:'."\n".
  '           Group: '."$group\n\n".
  '        Adding the following repositories:'."\n";
foreach my $repo (@repos) { $Msg .= "\t\t$repo\n" }; $Msg .=
  '--------------------------------------------------------------'."\n\n";

$Msg .= "Do you want to continue (Y/N)? ";
my $resp = svn_create::ask_user($Msg);
if($resp !~ /^y/i) { die "Aborting with no actions taken ...\n" };

$Msg = "Creating template permissions files for $group and $repos[0] ...\n";
my $CMD = '/usr/bin/svn co http://devsvn.gspt.net/svn/operations/'.
  'shared_services/svn_configuration/trunk '.$Work_tmp;

my $result = svn_create::do_command($CMD, $Msg);
if($result !~ /Checked out revision /) { die "$CMD\n$result" };

svn_create::create_svn_perms($group, @repos);

# #  check in perms file
$CMD = "svn add svnperms.conf.$group; ".
    "svn ci -m\"Adding svnperms.conf.$group\"  svnperms.conf.$group";
if($debug) { $result = "\n\n\n\n".'Checked in revision 1'."\n\n\n" }
else { $result = svn_create::do_command($CMD) };
if($result !~ /Checked in revision \d/) { warn "$CMD\n$result" };

print "Adding new group to Apache ...\n".
  "Enter your SUDO password if prompted ...\n";

svn_create::edit_svn_conf($group);

$Msg = "Restarting Apache ...\n";
$CMD = "/usr/bin/sudo /usr/sbin/apachectl restart";
if($debug) { $result = 'Debugging, so skipped'."\n" }
else { $result = do_command($CMD, $Msg) };
if(defined($result) && length($result)) { print "$CMD\n$result" };

$Msg = "Creating group $group root /opt/svn/${group}_GRP/reposroot ...\n";
$CMD = "/usr/bin/sudo mkdir -p /opt/svn/${group}_GRP/reposroot";
$result = svn_create::do_command($CMD, $Msg);
if(defined($result) && length($result)) { print "$CMD\n$result" };

foreach my $repo (@repos)
    { print "Please enter developers for the $repo repository:\n";
    my @developers = ();
    my $devel;
    while(($devel = <STDIN>) =~ /^[a-z]/)
	{ chomp $devel;
	push @developers, (split /\s+/, $devel);
	print "Please enter developers for the $repo repository:\n";
	};
    $CMD = "/gsice/scripts/svn_create_repo.bash -n -p ".
	"/opt/svn/scripts/svnperms.conf.$group $group $repo @developers";
    if($debug) { $result = "Debugging; did not call\n" }
    else { $result = `$CMD` };
    if(defined($result) && length($result)) { print "$CMD\n$result" };
    };

# add this group to viewvc.conf
$Msg = "Updating viewvc.conf ...\n";
svn_create::add_group2viewvc($group, $Msg);

my $Message = '
# 
# ======================
# N E X T    S T E P S :
# ======================
#  
# Update FishEye: http://devsvn.gspt.net/fisheye/
#
# Edit http://confluence.gspt.net/display/ss/SVN+Repository+Information
';
$Message .= "#     adding the $group group, and the @repos repositories.\n#\n";
$Message .= "# Please review permissions in /opt/svn/scripts/svnperms.conf.\n";
$Message .= $group." for these repos:\n";

foreach my $Repo (@repos) { $Message .= "\t$Repo\n" };
print "$Message\n";

&Cleanup;
exit 0;
