#!/usr/bin/perl -w
# nagios: +epn
#
# This plugin uses the Cisco Environmental Monitor MIB to check
# stats about their environment/chassis sensors
#
############################## sgichk_cisco_chassis ##############
my $Version='1.0';
# Date : Apr 14, 2012
# Author  : Brent Bice
# Help : http://nagios.manubulon.com
# Licence : GPL - http://www.fsf.org/licenses/gpl.txt
# Contrib : Patric Proy, J. Jungmann, S. Probst, R. Leroy, M. Berger
# TODO : 
#################################################################
#
# Help : ./sgichk_cisco_chassis.pl -h
#
use strict;
use Net::SNMP;
use Getopt::Long;

############### BASE DIRECTORY FOR TEMP FILE ########
my $o_base_dir="/tmp/tmp_Nagios_int.";
my $file_history=200;   # number of data to keep in files.

# Nagios specific

my $TIMEOUT = 15;
my %ERRORS=('OK'=>0,'WARNING'=>1,'CRITICAL'=>2,'UNKNOWN'=>3,'DEPENDENT'=>4);

# SNMP Datas

my $envmon_table='.1.3.6.1.4.1.9.9.13.1';
my $temp_state_table= $envmon_table . '.3.1.6';
my $temp_descr_table = $envmon_table . '.3.1.2';
my $temp_value_table = $envmon_table . '.3.1.3';
my $volt_state_table= $envmon_table . '.2.1.7';
my $volt_descr_table = $envmon_table . '.2.1.2';
my $volt_value_table = $envmon_table . '.2.1.3';
my $fan_state_table= $envmon_table . '.4.1.3';
my $fan_descr_table = $envmon_table . '.4.1.2';
my $pwr_state_table= $envmon_table . '.5.1.3';
my $pwr_descr_table = $envmon_table . '.5.1.2';
my %states=(1=>'Normal',
   2=>'Warning',
   3=>'Critical',
   4=>'Shutdown',
   5=>'notPresent',
   6=>'notFunctioning'
);

my %status=(1=>'UNKNOWN',2=>'OTHER',3=>'OK',4=>'WARNING',5=>'FAILED');

# Globals


# Standard options
my $o_host = 		undef; 	# hostname
my $o_port = 		161; 	# port
my $o_help=		undef; 	# wan't some help ?
my $o_verb=		undef;	# verbose mode
my $o_version=		undef;	# print version
my $o_warn_opt=		undef;  # warning options
my $o_crit_opt=		undef;  # critical options
my @o_warn=		undef;  # warning levels of perfcheck
my @o_crit=		undef;  # critical levels of perfcheck

my $o_timeout=  undef; 		# Timeout (Default 5)
# SNMP Message size parameter (Makina Corpus contrib)
my $o_octetlength=undef;
# Login options specific
my $o_community = 	undef; 	# community
my $o_version2	= undef;	#use snmp v2c
my $o_login=	undef;		# Login for snmpv3
my $o_passwd=	undef;		# Pass for snmpv3
my $v3protocols=undef;	# V3 protocol list.
my $o_authproto='md5';		# Auth protocol
my $o_privproto='des';		# Priv protocol
my $o_privpass= undef;		# priv password

# functions

sub p_version { print "sgichk_cisco_chassis version : $Version\n"; }

sub print_usage {
    print "Usage: $0 [-v] -H <host> -C <snmp_community> [-2] | (-l login -x passwd [-X pass -L <authp>,<privp>)  [-p <port>] [-o <octet_length>] [-t <timeout>] [-V]\n";
}

sub isnnum { # Return true if arg is not a number
  my $num = shift;
  if ( $num =~ /^(\d+\.?\d*)|(^\.\d+)$/ ) { return 0 ;}
  return 1;
}

sub help {
   print "\nSNMP Network Interface Monitor for Nagios version ",$Version,"\n";
   print "GPL licence, (c)2004-2007 Patrick Proy\n\n";
   print_usage();
   print <<EOT;
-v, --verbose
   print extra debugging information (including interface list on the system)
-h, --help
   print this help message
-H, --hostname=HOST
   name or IP address of host to check
-C, --community=COMMUNITY NAME
   community name for the host's SNMP agent (implies v1 protocol)
-l, --login=LOGIN ; -x, --passwd=PASSWD, -2, --v2c
   Login and auth password for snmpv3 authentication 
   If no priv password exists, implies AuthNoPriv 
   -2 : use snmp v2c
-X, --privpass=PASSWD
   Priv password for snmpv3 (AuthPriv protocol)
-L, --protocols=<authproto>,<privproto>
   <authproto> : Authentication protocol (md5|sha : default md5)
   <privproto> : Priv protocole (des|aes : default des) 
-P, --port=PORT
   SNMP port (Default 161)
-o, --octetlength=INTEGER
  max-size of the SNMP message, usefull in case of Too Long responses.
  Be carefull with network filters. Range 484 - 65535, default are
  usually 1472,1452,1460 or 1440.     
-t, --timeout=INTEGER
   timeout for SNMP in seconds (Default: 5)   
-V, --version
   prints version number
Note : when multiple interface are selected with regexp, 
       all be must be up (or down with -i) to get an OK result.
EOT
}

# For verbose output
sub verb { my $t=shift; print $t,"\n" if defined($o_verb) ; }

sub check_options {
    Getopt::Long::Configure ("bundling");
	GetOptions(
   	'v'	=> \$o_verb,		'verbose'	=> \$o_verb,
        'h'     => \$o_help,    	'help'        	=> \$o_help,
        'H:s'   => \$o_host,		'hostname:s'	=> \$o_host,
        'p:i'   => \$o_port,   		'port:i'	=> \$o_port,
        'C:s'   => \$o_community,	'community:s'	=> \$o_community,
	'2'	=> \$o_version2,	'v2c'		=> \$o_version2,		
	'l:s'	=> \$o_login,		'login:s'	=> \$o_login,
	'x:s'	=> \$o_passwd,		'passwd:s'	=> \$o_passwd,
	'X:s'	=> \$o_privpass,		'privpass:s'	=> \$o_privpass,
	'L:s'	=> \$v3protocols,		'protocols:s'	=> \$v3protocols,   
        't:i'   => \$o_timeout,    	'timeout:i'	=> \$o_timeout,
	'o:i'   => \$o_octetlength,    	'octetlength:i' => \$o_octetlength
    );
    if (defined ($o_help) ) { help(); exit $ERRORS{"UNKNOWN"}};
    if (defined($o_version)) { p_version(); exit $ERRORS{"UNKNOWN"}};
    if ( ! defined($o_host) ) # check host
	{ print_usage(); exit $ERRORS{"UNKNOWN"}}

    # check snmp information
    if ( !defined($o_community) && (!defined($o_login) || !defined($o_passwd)) )
	{ print "Put snmp login info!\n"; print_usage(); exit $ERRORS{"UNKNOWN"}}
	if ((defined($o_login) || defined($o_passwd)) && (defined($o_community) || defined($o_version2)) )
	{ print "Can't mix snmp v1,2c,3 protocols!\n"; print_usage(); exit $ERRORS{"UNKNOWN"}}
	if (defined ($v3protocols)) {
	  if (!defined($o_login)) { print "Put snmp V3 login info with protocols!\n"; print_usage(); exit $ERRORS{"UNKNOWN"}}
	  my @v3proto=split(/,/,$v3protocols);
	  if ((defined ($v3proto[0])) && ($v3proto[0] ne "")) {$o_authproto=$v3proto[0];	}	# Auth protocol
	  if (defined ($v3proto[1])) {$o_privproto=$v3proto[1];	}	# Priv  protocol
	  if ((defined ($v3proto[1])) && (!defined($o_privpass))) {
	    print "Put snmp V3 priv login info with priv protocols!\n"; print_usage(); exit $ERRORS{"UNKNOWN"}}
	}
	if (defined($o_timeout) && (isnnum($o_timeout) || ($o_timeout < 2) || ($o_timeout > 60))) 
	  { print "Timeout must be >1 and <60 !\n"; print_usage(); exit $ERRORS{"UNKNOWN"}}
	if (!defined($o_timeout)) {$o_timeout=5;}

    #### octet length checks
    if (defined ($o_octetlength) && (isnnum($o_octetlength) || $o_octetlength > 65535 || $o_octetlength < 484 )) {
		print "octet lenght must be < 65535 and > 484\n";print_usage(); exit $ERRORS{"UNKNOWN"};
    }	
}
    
########## MAIN #######

check_options();

# Check gobal timeout if snmp screws up
if (defined($TIMEOUT)) {
  verb("Alarm at $TIMEOUT + 5");
  alarm($TIMEOUT+5);
} else {
  verb("no timeout defined : $o_timeout + 10");
  alarm ($o_timeout+10);
}

$SIG{'ALRM'} = sub {
 print "No answer from host\n";
 exit $ERRORS{"UNKNOWN"};
};

# Connect to host
my ($session,$error);
if ( defined($o_login) && defined($o_passwd)) {
  # SNMPv3 login
  if (!defined ($o_privpass)) {
  verb("SNMPv3 AuthNoPriv login : $o_login, $o_authproto");
    ($session, $error) = Net::SNMP->session(
      -hostname   	=> $o_host,
      -version		=> '3',
      -port      	=> $o_port,
      -username		=> $o_login,
      -authpassword	=> $o_passwd,
      -authprotocol	=> $o_authproto,
      -timeout          => $o_timeout
    );  
  } else {
    verb("SNMPv3 AuthPriv login : $o_login, $o_authproto, $o_privproto");
    ($session, $error) = Net::SNMP->session(
      -hostname   	=> $o_host,
      -version		=> '3',
      -username		=> $o_login,
      -port      	=> $o_port,
      -authpassword	=> $o_passwd,
      -authprotocol	=> $o_authproto,
      -privpassword	=> $o_privpass,
	  -privprotocol => $o_privproto,
      -timeout          => $o_timeout
    );
  }
} else {
  if (defined ($o_version2)) {
    # SNMPv2c Login
	verb("SNMP v2c login");
	($session, $error) = Net::SNMP->session(
       -hostname  => $o_host,
	   -version   => 2,
       -community => $o_community,
       -port      => $o_port,
       -timeout   => $o_timeout
    );
  } else {
    # SNMPV1 login
	verb("SNMP v1 login");
    ($session, $error) = Net::SNMP->session(
       -hostname  => $o_host,
       -community => $o_community,
       -port      => $o_port,
       -timeout   => $o_timeout
    );
  }
}
if (!defined($session)) {
   printf("ERROR opening session: %s.\n", $error);
   exit $ERRORS{"UNKNOWN"};
}

if (defined($o_octetlength)) {
	my $oct_resultat=undef;
	my $oct_test= $session->max_msg_size();
	verb(" actual max octets:: $oct_test");
	$oct_resultat = $session->max_msg_size($o_octetlength);
	if (!defined($oct_resultat)) {
		 printf("ERROR: Session settings : %s.\n", $session->error);
		 $session->close;
		 exit $ERRORS{"UNKNOWN"};
	}
	$oct_test= $session->max_msg_size();
	verb(" new max octets:: $oct_test");
}

# Get Environment Sensor Data
my $envstats = $session->get_table( Baseoid => $envmon_table );
if (!defined($envstats)) {
   printf("ERROR: Fetching Envmon table : %s.\n", $session->error);
   $session->close;
   exit $ERRORS{"UNKNOWN"};
}

$session->close;

# Only a few ms left...
alarm(0);


my $num_sensor = 0;

# define the OK value depending on -i option
my $print_out = "OK: All Environmental Sensors ok";
my $num_bad=0;
my $result = $ERRORS{"OK"};   # assume all will be well

my @outstr = ();
#my $perfstr = "\|";
my $perfstr = "";   # for now I'm not tracking envmon values
my $descr = "";
my $state = "";
my $msg = "";
foreach my $key ( sort (keys %$envstats)) {
   my $tind = "";
   if ($key =~ /^$temp_state_table(\..*)/) {
      $tind = $1;
      $descr = $$envstats{$temp_descr_table . $tind};
      my $value = $$envstats{$temp_value_table . $tind};
      $state = $$envstats{$temp_state_table . $tind};
      if (defined($value)) {
         $msg = "$descr = $value = $states{$state}";
      } else {
         $msg = "$descr = $states{$state}";
      }
      push (@outstr, $msg);
   } elsif ($key =~ /^$fan_state_table(\..*)/) {
      $tind = $1;
      $descr = $$envstats{$fan_descr_table . $tind};
      $state = $$envstats{$fan_state_table . $tind};
      $msg = "$descr = $states{$state}";
      push (@outstr, $msg);
   } elsif ($key =~ /^$pwr_state_table(\..*)/) {
      $tind = $1;
      $descr = $$envstats{$pwr_descr_table . $tind};
      $state = $$envstats{$pwr_state_table . $tind};
      $msg = "$descr = $states{$state}";
      push (@outstr, $msg);
   } elsif ($key =~ /^$volt_state_table(\..*)/) {
      $tind = $1;
      $descr = $$envstats{$volt_descr_table . $tind};
      my $value = $$envstats{$volt_value_table . $tind};
      $state = $$envstats{$volt_state_table . $tind};
      if (defined($value)) {
         $msg = "$descr = $value = $states{$state}";
      } else {
         $msg = "$descr = $states{$state}";
      }
      push (@outstr, $msg);
   }

   if (length($tind) > 0) {   # if we found a stat on this iteration
      if ((($state == 2) || ($state == 6)) && ($result != $ERRORS{'CRITICAL'})) {
         $result = $ERRORS{'WARNING'};
         $print_out = "WARNING: $msg";
      } elsif (($state == 3) || ($state == 4)) {
         $result = $ERRORS{'CRITICAL'};
         $print_out = "CRITICAL: $msg";
      }
   }
}

#verb ("perfstr = $perfstr");

print "$print_out $perfstr\n";
foreach my $i (@outstr) {
   print "$i\n";
}
exit $result;


