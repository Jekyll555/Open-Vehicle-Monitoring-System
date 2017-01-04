#!/usr/bin/perl

use Digest::MD5;
use Digest::HMAC;
use Crypt::RC4::XS;
use MIME::Base64;
use IO::Socket::INET;
use IO::Socket::Timeout;
use Errno qw(ETIMEDOUT EWOULDBLOCK);
use Config::IniFiles;

# Read command line arguments:
my $cmd_code = $ARGV[0];
my $cmd_args = $ARGV[1];
my $cmd_rescnt = $ARGV[2];

if (!$cmd_code) {
 print "usage: cmd.pl code [args] [resultcnt]\n";
 exit;
}

my $b64tab = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

# Configuration
my $config = Config::IniFiles->new(-file => 'ovms_client.conf');

my $vehicle_id       = $config->val('client','vehicle_id','TESTCAR');
my $server_password  = $config->val('client','server_password','NETPASS');
my $module_password  = $config->val('client','module_password','OVMS');

my $server_ip        = $config->val('client','server_ip','tmc.openvehicles.com');


#####
##### CONNECT
#####

my $sock = IO::Socket::INET->new(
	PeerAddr => $server_ip,
	PeerPort => '6867',
	Proto    => 'tcp',
	Timeout  => 5 );

# configure socket timeouts:
IO::Socket::Timeout->enable_timeouts_on($sock);
$sock->read_timeout(20);
$sock->write_timeout(20);


#####
##### REGISTER
#####

rand;
my $client_token;
foreach (0 .. 21)
  { $client_token .= substr($b64tab,rand(64),1); }

my $client_hmac = Digest::HMAC->new($server_password, "Digest::MD5");
$client_hmac->add($client_token);
my $client_digest = $client_hmac->b64digest();

# Register as batch client (type "B"):
print $sock "MP-B 0 $client_token $client_digest $vehicle_id\r\n";

my $line = <$sock>;
chop $line;
chop $line;
my ($welcome,$crypt,$server_token,$server_digest) = split /\s+/,$line;

my $d_server_digest = decode_base64($server_digest);
my $client_hmac = Digest::HMAC->new($server_password, "Digest::MD5");
$client_hmac->add($server_token);
if ($client_hmac->digest() ne $d_server_digest)
  {
  print STDERR "  Client detects server digest is invalid - aborting\n";
  exit(1);
  }

$client_hmac = Digest::HMAC->new($server_password, "Digest::MD5");
$client_hmac->add($server_token);
$client_hmac->add($client_token);
my $client_key = $client_hmac->digest;

my $txcipher = Crypt::RC4::XS->new($client_key);
$txcipher->RC4(chr(0) x 1024); # Prime the cipher
my $rxcipher = Crypt::RC4::XS->new($client_key);
$rxcipher->RC4(chr(0) x 1024); # Prime the cipher


##### 
##### SEND COMMAND
##### 

my $cmd;
if ($cmd_args)
 { $cmd = $cmd_code.",".$cmd_args; }
else
 { $cmd = $cmd_code; }

my $encrypted = encode_base64($txcipher->RC4("MP-0 C".$cmd),'');
print $sock "$encrypted\r\n";


##### 
##### READ RESPONSE
##### 

my $ptoken = "";
my $pdigest = "";
my $data = "";
my $discardcnt = 0;
my $resultcnt = 0;

while(1)
{
	# Read from server:
	$data = <$sock>;
	if (! $data && ( 0+$! == ETIMEDOUT || 0+$! == EWOULDBLOCK )) {
		print STDERR "Read timeout, exit.\n";
		exit;
	}
	
	chop $data; chop $data;
	my $decoded = $rxcipher->RC4(decode_base64($data));

	if ($decoded =~ /^MP-0 ET(.+)/)
	{
		$ptoken = $1;
		my $paranoid_hmac = Digest::HMAC->new($module_password, "Digest::MD5");
		$paranoid_hmac->add($ptoken);
		$pdigest = $paranoid_hmac->digest;
		# discard:
		$decoded = "";
	}
	elsif ($decoded =~ /^MP-0 EM(.)(.*)/)
	{
		my ($code,$data) = ($1,$2);
		my $pmcipher = Crypt::RC4::XS->new($pdigest);
		$pmcipher->RC4(chr(0) x 1024); # Prime the cipher
		$decoded = $pmcipher->RC4(decode_base64($data));
		# reformat as std msg:
		$decoded = "MP-0 ".$code.$decoded;
	}
	
	if ($decoded =~ /^MP-0 c$cmd_code/)
	{
		print STDOUT $decoded,"\n";
		$discardcnt = 0;
		$resultcnt++;
		if (($cmd_rescnt ne 0) && ($resultcnt >= $cmd_rescnt))
		{
			exit;
		}
	}
	else
	{
		# exit if more than 25 other msgs received in series (assuming cmd done):
		$discardcnt++;
		if ($discardcnt > 25)
		{
			print STDERR "No more results, exit.\n";
			exit;
		}
	}
}
