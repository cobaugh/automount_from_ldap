#!/usr/bin/env perl

use strict;
use warnings;

use Net::LDAP;
use Getopt::Long;

# print usage
sub usage {
	print "Usage: automount_from_ldap.pl [-h] [--help] -H <LDAP hostname> -b <base> [-m <auto.master map>]\n";
	print "\t-h displays usage()\n";
	print "\t--help displays full help page (perldoc -T)\n";
	exit 0;
}

# search an automountMapName
sub search_map($$$$);
sub search_map($$$$) {
	my ($map, $base, $path, $ldap) = @_;

	my $mesg = $ldap->search(
		base => "automountMapName=$map,$base",
		filter => "(objectClass=automount)",
		scope => 'one'
	);

	if ($mesg->count > 0) {
		foreach my $entry ($mesg->entries) {
			my $key = $entry->get_value('automountKey');
			$key =~ s/^\///;
			my $information = $entry->get_value('automountInformation');
			# check to see if this key points to another map (-fstype=autofs) or -fstype isn't specified (most likely another map)
			if ($information =~ /.*-fstype=autofs.+/ or $information !~ /.*-fstype.+/) {
				$information =~ s/.*-fstype=autofs\s+//;
				search_map($information, $base, $path . '/' . $key, $ldap);
			} else {
				print "$path/$key $information\n";
			}
		}
	}
}

##
## main program
##

# set option defaults
my %o = (
	'm' => 'auto.master'
);

# get options
Getopt::Long::Configure ("bundling");
GetOptions(\%o, "h", "help", "H=s", "b=s", "m=s") or usage;

# display full help
if ($o{'help'}) {
	exec('perldoc', '-T', $0);
	exit 0;
}

# check for required options
if (!$o{'b'} or !$o{'H'} or $o{'h'}) {
	usage;
	exit 0;
}

# connect to the ldap server
my $ldap = Net::LDAP->new($o{'H'}) or die "$@";

# kick off the search
search_map($o{'m'}, $o{'b'}, "", $ldap);

$ldap->unbind;

__END__

=head1 NAME

automount_from_ldap.pl - Generate automount direct map from autofs5 LDAP map

=head1 SYNOPSIS

automount_from_ldap.pl [--help] [-h] -H <LDAP server> -b <search base> [-m <auto.master map name>]

The LDAP automount maps are assumed to be compliant with RFC 2307bis. Nested maps are assumed to be of the 
form 

=over

automountInformation: -fstype=autofs <map name>

=back

With the exception of the maps directly underneath auto.master. Those should specify just the map name in automountInformation.

=head1 OPTIONS

Required:

=over

=item B<-H>

Hostname of LDAP server to connec to.

=item B<-b>

Search base. This is where the auto.master map name should be located.

=back

Optional:

=over

=item B<-m>

auto.master map name, or autoMountMapName to start searching from.

=item B<-h>

Displays usage().

=item B<--help>

Displays this full help page (equivalent of perldoc -T).

=back

=head1 SEE ALSO

L<http://github.com/phalenor/automount_from_ldap>

=head1 AUTHOR

Andy Cobaugh <phalenor@gmail.com>

=cut
