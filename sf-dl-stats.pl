#!/usr/bin/perl -w
## gets the download stats of the gmod tools listed in @tool_list
## creates a tab delim'd table and a wiki formatted table
## at present only gets stats for tools in the gmod sf project
## can easily be altered.

use strict;
use warnings;
use Data::Dumper;
use JSON;
use DateTime;

## set to 1 if have already downloaded the stats.
my $no_get;

## local dir where all these files will be created
## creates four files:
## sf-dl-urls.txt        - list of urls to check
## sf-dl-stats.json      - json downloaded from sf
## sf-dl-stats-table.txt - tab delim'd text
## sf-dl-stats-wiki.txt  - wikified

my $local_dir = '/Users/gwg/Desktop/GMOD/';

my $to_date = DateTime->today->subtract(months => 1);
my $year = $to_date->year;
my $month = sprintf("%02d" , $to_date->month);

my @tool_list = qw(
Generic%20Genome%20Browser
gmod
Apollo
OldFiles
cas-utils
cmap
XML-XORT
FlashGViewer
PubSearch
blastGraphic
pg_dump
LuceGene
PubFetch
Citrina
GDS
GOView
RestGraph
seqdb_engine
imdb
org.bdgp
sop
LabDoc
GOET
);
## wget cmd: wget "http://sourceforge.net/projects/gmod/files/Generic%20Genome%20Browser/stats/json?start_date=2001-06-01&end_date=$year-$month-01" -O output-file.txt
## or better still
## wget -i /Users/gwg/Desktop/GMOD/sf-dl-urls.txt -O /Users/gwg/Desktop/GMOD/sf-dl-stats.json';

my $url_file = $local_dir . 'sf-dl-urls.txt';
unless ($no_get)
{	## write sf-dl-urls.txt
	open(URL, '>', $url_file) or die "Could not open $url_file: $!";
	foreach my $t (@tool_list)
	{	print URL "http://sourceforge.net/projects/gmod/files/" . $t . "/stats/json?start_date=2001-06-01&end_date=$year-$month-01\n";
	}
	close(URL);
}

my $json = $local_dir . 'sf-dl-stats.json';

unless ($no_get)
{	## now call wget
	my @wget_call = ("wget", "-i", $url_file, "-O", $json);
	print STDERR join(" ", @wget_call)."\n";
	## EXECUTE!
	system(@wget_call) == 0 or die "system @wget_call failed: $?";
}

my $data;
open('IN', '<', $json) or die "Could not open $json: $!";
my $str;
while (<IN>)
{	$str .= $_;
}

## chunks of JSON, initially not sep'd
## have manually formatted - rplc }{"oses" to add in a line break
## and put "tool": "toolnamehere" as the first tag
## i.e. s/\}\{"oses"/\}\\r\{"tool":<toolname>, "oses"/
$str =~ s/[\n\r]//g;
$str =~ s/\}\{\"oses\"/}\n{"oses"/g;
my @arr = split(/\n/, $str);
my $c = 0;
foreach (@arr)
{	next unless /\w/;
#	print STDERR "to decode: $_<-- END\n";
	my $temp = decode_json($_);
#	print Dumper($temp);
	if (! $tool_list[$c])
	{	die "Run out of names for tool data! Found $c tools";
	}
	my $t_name = $tool_list[$c];
	$t_name =~ s/\%20/ /g;
	foreach my $d (@{$temp->{downloads}})
	{	## should we parse the dates a little better?
		## should also remove the data from this month...
		my $ym = substr($d->[0], 0, 7);
		$data->{by_date}{$ym}{$t_name} = $d->[1];
		$data->{by_name}{$t_name}{$ym} = $d->[1];
	}
	$c++;
#	print Dumper($data);
#	exit(0);
}

close( IN );

## print out the data
## tab delim'd
my $outfile = $local_dir . 'sf-dl-stats-table.txt';
## as a wiki table
my $wikiout = $local_dir . 'sf-dl-stats-wiki.txt';
open('OUT', '>', $outfile) or die "Could not open $outfile: $!";
open('WIKI','>', $wikiout) or die "Could not open $wikiout: $!";


print OUT "name\t";
print WIKI '{| class="wikitable"' . "\n|-\n! name !! ";
## table header
print OUT join("\t", sort keys %{$data->{by_date}}) . "\n";
print WIKI join(" !! ", sort keys %{$data->{by_date}}) . "\n";

foreach my $name (sort { lc($a) cmp lc($b) } keys %{$data->{by_name}})
{	print OUT "$name\t" . join("\t", map {
		if ($data->{by_name}{$name}{$_})
		{	$data->{by_name}{$name}{$_}
		}
		else
		{	"0"
		}
	} sort keys %{$data->{by_date}}) . "\n";

	print WIKI "|-\n| $name || " . join(' || ', map {
		if ($data->{by_name}{$name}{$_})
		{	$data->{by_name}{$name}{$_}
		}
		else
		{	"0"
		}
	} sort keys %{$data->{by_date}}) . "\n";
}

print OUT "\n\n";
print WIKI "|}\n\n";

close(OUT);
close(WIKI);
#foreach my $l (sort keys %{$data->{l_post}})
#{	print STDERR "$l\t$data->{l_post}{$l}\n";
#}



exit(0);
