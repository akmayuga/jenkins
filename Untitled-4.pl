#!/usr/bin/perl
use strict;
use warnings;
use HTTP::Request::Common qw(POST GET PUT);
use LWP::UserAgent;
use Getopt::Long;
use JSON -support_by_pp;
eval { require Config::Simple;};
my $has_config_parser = scalar($@) ? 0 : 1;

my $timestamp;
$timestamp = `date`;
print qq|Script Start for Manual Tasks: $timestamp\n|;

my ($host, $verbose,$context,$pid,$rid,$username,$password, $pip, $pdesc, $config_file,$printer_status,$basedir,$keyfile);
GetOptions (
  "host=s"   => \$host,
  "context=s" => \$context,
  "verbose"  => \$verbose,
  "pid=s" => \$pid,
  "rid=s" => \$rid,
  "username=s" => \$username,
  "password=s" => \$password,
  "pip=s" => \$pip,
  "printerDesc=s" => \$pdesc,
  "config=s" => \$config_file,
  "printerStatus=s" => \$printer_status,
  "basedir=s" => \$basedir,
  "keyfile=s" => \$keyfile

  );
my %file_config;

$ENV{'JAVA_HOME'} = '/usr/java/jre1.8.0_91/';
unless( $ENV{'JAVA_HOME'} && -d $ENV{'JAVA_HOME'})  {
  die "JAVA_HOME is not set\n";
}

my $printer_status_command = (defined $printer_status?$printer_status:'/home/bweschke/printer_status_2.0.pl');

if (defined $config_file){
  if (-e $config_file && $has_config_parser){
    Config::Simple->import_from($config_file, \%file_config )or die Config::Simple->error();
    # Set up the defaults from the config file if they weren't overwritten
    if (!defined $host && defined $file_config{'host'}){ $host = $file_config{'host'};}
    if (!defined $context && defined $file_config{'context'}){ $context = $file_config{'context'};}
    if (!defined $pid && defined $file_config{'pid'}){ $pid = $file_config{'pid'};}
    if (!defined $rid && defined $file_config{'rid'}){ $rid = $file_config{'rid'};}
    if (!defined $username && defined $file_config{'username'}){ $username = $file_config{'username'};}
    if (!defined $password && defined $file_config{'password'}){ $password = $file_config{'password'};}
    if (!defined $pip && defined $file_config{'pip'}){ $pip = $file_config{'pip'};}
    if (!defined $pdesc && defined $file_config{'printerDesc'}){ $pdesc = $file_config{'printerDesc'};}
    if (!defined $printer_status && defined $file_config{'printerStatus'}){ $printer_status_command = $file_config{'printerStatus'};}
    if (!defined $basedir && defined $file_config{'basedir'}){ $basedir = $file_config{'basedir'};}
    if (!defined $keyfile && defined $file_config{'keyfile'}){ $basedir = $file_config{'keyfile'};}


  } else {
    print "Unable to open config file specified or you do not have Config::Simple loaded on this system 'apt-get install libconfig-simple-perl'\n";
    exit 1;
  }

}
unless (defined $host && defined $pid && defined $rid && defined $username && defined $password && defined $pip){
  usage();
  exit 1;
}

unless (-e $printer_status_command){
  die "Unable to find printer status command: $printer_status_command\n";
}
$basedir = (defined $basedir?$basedir:'/home/bweschke');

unless (-d $basedir){
  die "The base directory does not exist: $basedir\n";
}
sub usage {
  print "$0 --host WEB_HOST --context CONTEXT --pid PRINTERID --rid RESTAURANTID --username USERNAME --password PASSWORD --pip PRINTERIP [--printerDesc PRINTERNAME?] [--verbose] [--config /path/to/configfile/filename] [--basedir /path/to/basedir] [--keyfile=keyfilename]\n";
}
$context = (defined $context?$context:'KJTRest');
my $printerid = "pid" . $pid;

unless (-e "$basedir/pd4ml.jar"){
  die "Unable to locate pd4ml.jar in $basedir\n";
}
$keyfile = (defined $keyfile?$keyfile:'privtest.key');
unless (-e "$basedir/$keyfile"){
  die "Unable to locate $keyfile in $basedir\n";
}

# Log into the page..
my $req = HTTP::Request->new( 'POST', "http://$host/$context/api/token" );
$req->content_type('application/x-www-form-urlencoded');
$req->content("username=$username&password=$password");
my $lwp      = LWP::UserAgent->new;
my $response = $lwp->request($req);
my $wstoken = $response->header('WSToken');

$timestamp = `date`;
print qq|Logged In: $timestamp\n|;

my $printerdesc = (defined $pdesc?$pdesc:"RPrinterEth");

# Check the status of the printer..
my $printprf = `$printer_status_command -h $pip`;
$timestamp = `date`;
print qq|Status Fetched: $timestamp\n|;
if ($? != 0){
  # Handle Printer error...
  my $reqS = HTTP::Request->new( 'PUT', "http://$host/$context/papi/restaurant/$rid/printer/$printerid/status" );
  $reqS->header( 'Content-Type' => 'application/json' );
  $reqS->header( 'WSToken'      => $wstoken );
  my $jsonSTR = qq|{"status":"insufficient", "statusReport":"$printprf"}|;
  $reqS->content($jsonSTR);
  my $responseOBJ = $lwp->request($reqS);
  exit;
}


my $enableprinterstr = `/usr/sbin/cupsenable $printerdesc`;

my $lastptid = `cat $basedir/printer-tasks-$pid/mlast.ptid`;

$timestamp = `date`;
print qq|Printer Enabled: $timestamp\n|;

my $reqTasks = GET("http://$host/$context/services/userservices/restaurant/papi/restaurant/$rid/printer/$printerid/manualtasks/aftermptid/$lastptid");
$reqTasks->header( 'WSToken' => $wstoken );
print $reqTasks->as_string();
$response = $lwp->request($reqTasks);

my $jsonresp;
$timestamp = `date`;
print qq|Tasks Fetched: $timestamp\n|;

if ( $response->is_success ) {
    $jsonresp = $response->decoded_content;
}

my $json = new JSON;

print qq|$jsonresp\n|;

# these are some nice json options to relax restrictions a bit:
my $json_text =
  $json->allow_nonref->utf8->relaxed->escape_slash->loose->allow_singlequote
  ->allow_barekey->decode($jsonresp);

foreach my $ptid ( @{$json_text} ) {
    print qq|PTID: $ptid->{mptid}\n|;
    print qq|\nHTML: $ptid->{html}\n|;
    open( JOBOUT, ">$basedir/printer-tasks-$pid/m-$ptid->{mptid}.html" );
    print JOBOUT $ptid->{html};
    close(JOBOUT);
    my $dopdf = `$ENV{'JAVA_HOME'}/bin/java -Xmx512m -Djava.awt.headless=true -cp $basedir/pd4ml.jar Pd4Cmd 'file:$basedir/printer-tasks-$pid/m-$ptid->{mptid}.html' 200 200x750 -ttf . -insets 0,0,10,0,pt -out $basedir/printer-tasks-$pid/m-$ptid->{mptid}.pdf`;
    my $printprf   = `/usr/bin/lp -d $printerdesc $basedir/printer-tasks-$pid/m-$ptid->{mptid}.pdf`;
    my $x        = 0;
    my $lpstatlc = "$printerdesc";
    while ( $x < 100 && ( $lpstatlc =~ /$printerdesc/ ) ) {
        $lpstatlc = `/usr/bin/lpstat -o $printerdesc`;
        print qq|LPStat LC: $lpstatlc\n|;
        sleep 1;
        $x++;
    }
    my $status;
    if ( $x < 25 ) {
        # GREAT SUCCESS!
        $status = "PRINTED";
    } else {
        # FAIL BOB, FAIL!
        $status = "FAILED";
    }

    my $reqS = HTTP::Request->new( 'PUT', "http://$host/$context/services/userservices/restaurant/papi/restaurant/$rid/printer/$printerid/manualtask/$ptid->{mptid}/status" );
    $reqS->header( 'Content-Type' => 'application/json' );
    $reqS->header( 'WSToken'      => $wstoken );
    my $jsonSTR = qq|{"status":"$status"}|;
    $reqS->content($jsonSTR);
    my $responseOBJ = $lwp->request($reqS);
    print $responseOBJ->as_string;
    open( JOBOUT, ">$basedir/printer-tasks-$pid/mlast.ptid" );
    print JOBOUT $ptid->{mptid};
    close(JOBOUT);
}
