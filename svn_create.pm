#!/usr/local/tools/perl/bin/perl
# svn_create.pm - perl module for use in svn repository creation
use strict;
use warnings;

package svn_create;

use POSIX qw( strftime );

my @EXPORT = qw( group_exists pickAperm get_work_dir Cleanup );

my $exe = (split /\//, $0)[-1];
$exe =~ s/\..*$//;
my $tStamp = strftime('%Y%m%d_%H%M%S',localtime(time));


# ########################
# ## Methods
# ########################

my $work_tmp;
sub get_work_dir {

$work_tmp = $ENV{'HOME'}.'/'.$exe.$$.'_'.$tStamp;

mkdir($work_tmp) or die "$0: can't create $work_tmp: $!\n";
return $work_tmp
}

sub Cleanup {
    chdir($ENV{'HOME'}) or die "$0: can't get HOME; please remove $work_tmp\n";
    my $CMD = "/bin/rm -rf $work_tmp";
    my $result = `$CMD`;
    if(defined($result) && length($result)) { die "$CMD\n$result" };
}

sub sig_handler {
my($sig) = @_;

print "Caught a SIG$sig -- shutting down\n";
&Cleanup;
exit
}

my $Group;
sub set_group {
my ($grp) = @_;
$Group = $grp;
}
 
sub group_exists {
my ($group) = @_;

$group = (defined($group))?$group:$Group;
my $CNF = '/etc/httpd/conf.d/subversion.conf';
open(CNF,$CNF) or die "$0: can't read $CNF: $!\n";
my $groupIs = 0;
while(<CNF>)
    { if(m{<Location\s+/svn/$group/}) { $groupIs = 1 }};
close CNF;

return $groupIs
}

sub ask_user {
my ($Message) = @_;

$Message = (defined($Message) && length($Message))?$Message:
  'Bail or <Enter> to proceed:';
print $Message;
my $resp = <STDIN>; chomp $resp;

return $resp
}

sub do_command {
my ($CMD, $Message) = @_;

if(defined($Message) && length($Message)) { print $Message };

$CMD .= ' 2>&1';
my $result = `$CMD`;
return $result
}

sub create_svn_perms {
my ($group, @repos) = @_;

$group = (defined($group))?$group:$Group;
open(GCN,"> svnperms.conf.$group") or
  die "$0: can't write svnperms.conf.$group: $!\n";

print GCN "#\n# $group conf file - regulates access to all repos under ".
  "http://devsvn.gspt.net/svn/$group\n# For more information, please see: ".
  'http://confluence.gspt.net/display/ss/SVN+Repository+Information'.
  "\n#\n#\n# ".'[groups]'."\n\n";

foreach my $repo (@repos)
    { print GCN "$repo-developers = " };
print "Please enter uids of developers of the $group group ".
  '(blank line to finish):';

while(my $devel = <STDIN>)
    { chomp($devel);
    $devel =~ s/^\s*//;
    last if($devel !~ /^[a-z]/);
    my @devs = split /\s+/, $devel;
    foreach my $dev (@devs)
	{ if(!-d "/home/$dev")
	    { warn "$dev has no /home/$dev directory: ignoring\n"; next };
	print GCN "$dev ";
	};
    };
print GCN "\n";

print GCN "\n# --------------\n\n";
foreach my $repo (@repos)
    { print GCN  <<EOF
# 
# [$repo]
# trunk/.* = \@$repo-developers(add,remove,update)
# tags/([^/]+/)+ = build(add)
# branches/.* = \@$repo-developers(add,remove,update)

EOF
    };
close GCN;
}

sub pickAperm {
my ($group, $repos) = @_;

my $wd = $ENV{'PWD'};
my $gRoot = "/opt/svn/${group}_GRP/reposroot";
chdir($gRoot) or die "Can't cd to $gRoot: $!\n";
my $permFile = '';
my %perm_files = ();
my $FND = '/usr/bin/sudo /usr/bin/find . -name "svnperms.conf" -type l -ls';
open(FND,"$FND |") or die "$0: can't $FND: $!\n";
while(my $line = <FND>)
    { my $file = (split /\s+/, $line)[-1];
    $perm_files{$file}++;
    };
close FND;
my @p_files = (keys %perm_files);
if($#p_files == 0) { chdir($wd); return $p_files[0] };
if($#p_files > 0)
    { print "Found more than one perm file for /opt/svn/${group}_GRP:\n";
    while(!length($permFile))
	{ print "Which permissions file should be used for $repos?\n";
	my $num = 1;
	foreach my $pf (@p_files)
	    { print "$num)  $pf\n"; $num++ };
	my $pick = <STDIN>;
	chomp $pick;
	$pick--;
	next if($pick > $#p_files || $pick < 0);
	$permFile = $p_files[$pick];
	};
    }
else { die "Cannot find existing perm files for /opt/svn/${group}_GRP" };
chdir($wd);
return $permFile
}

sub edit_svn_conf {
my ($group) = @_;

$group = (defined($group))?$group:$Group;

my $SVC = '/etc/httpd/conf.d/subversion.conf';
# make a backup of the current subversion.conf file
my $CMD = "/usr/bin/sudo /bin/cp $SVC $SVC.$tStamp";
my $result = `$CMD`;
if(defined($result) && length($result)) { print "$CMD\n$result" };

# append a record for this new group to subversion.conf
open(CNF,">> $SVC") or die "$0: can't append to $SVC: $!\n";
print CNF "\n".'RewriteRule ^/svn/'.$group.'$ /svn/'.$group.'/ [R]'."\n";
print CNF '<Location /svn/'.$group.'/>'."\n   DAV svn\n";
print CNF '   # SVNPathAuthz off'."\n";
print CNF '   SVNParentPath /opt/svn/'.$group.'_GRP/reposroot/'."\n";
print CNF '   SVNListParentPath On'."\n";
print CNF '   # Control access via LDAP'."\n";
print CNF '   AuthBasicProvider ldap'."\n";
print CNF '   AuthLDAPURL "ldap://secdevnet.gspt.net/ou=gsi,dc=gspt,dc=net"'.
  "\n";
print CNF '   AuthzLDAPAuthoritative Off'."\n";
print CNF '   Require ldap-group cn=cvs,ou=Group,ou=gsi,dc=gspt,dc=net'."\n";
print CNF '   AuthLDAPGroupAttributeIsDN off'."\n";
print CNF '   AuthLDAPGroupAttribute memberUid'."\n";
print CNF '   AuthType Basic'."\n";
print CNF '   AuthName "Access to GSI'."'s $group library SVN Repository\"\n";
print CNF '   # AuthzSVNAccessFile /opt/svn/'.$group.'_GRP/security/svnauthz';
print CNF "\n".'</location>'."\n";
close CNF;
}

sub add_group2viewvc {
my ($group, $Message) = @_;

$group = (defined($group))?$group:$Group;

my $VVC = '/usr/local/tools/viewvc/viewvc.conf';
if(defined($Message) && length($Message)) { print $Message };

open(VVC, '+<',$VVC) or die "$exe: can't update $VVC: $!\n";
my @ents = <VVC>;
foreach my $idx (0 .. $#ents)
    { if($ents[$idx] =~ m{^root_parents\s+=\s+/opt/svn/})
	{ $ents[$idx] .= ' ' x 15;
	$ents[$idx] .= "/opt/svn/${group}_GRP/reposroot : svn,\n";
	};
    };
seek(VVC,0,0) or die "Can't seek start of $VVC: $!\n";
print VVC @ents or die "Can't write $VVC: $!\n";
truncate(VVC, tell(VVC)) or die "Can't resize $VVC: $!\n";
close VVC or die "Can't close $VVC: $!\n";;
}

1;
