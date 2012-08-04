#!/usr/bin/perl -w

use strict;
use warnings;

use LWP::Simple;
use Data::Dumper;

my $verbose = 1; #$ENV{VERBOSE} || 1;
my $emulate;
my $six_month_summary = 1;
my $local_dir = '/Users/gwg/Desktop/GMOD/gmod-scripts/';
my $temp_dir = '/Users/gwg/Desktop/GMOD/gmod-scripts/temp/';
my $data;

my $months = {
'January' => '01',
'February' => '02',
'March' => '03',
'April' => '04',
'May' => '05',
'June' => '06',
'July' => '07',
'August' => '08',
'September' => '09',
'October' => 10,
'November' => 11,
'December' => 12,
};

my $sf_lists = [
	"ergatis-announce",
	"ergatis-devel",
	"ergatis-users",
	"gmod-ajax",
	"gmod-announce",
#	"gmod-apollo-cmts",
	"gmod-architecture",
#	"gmod-biographics-commits",
	"gmod-chado-seq-ad",
	"gmod-citrina",
	"gmod-cmae",
#	"gmod-cmap-commits",
	"gmod-cmap",
	"gmod-cogephy",
#	"gmod-das2-cmts",
	"gmod-devel",
#	"gmod-gbrowse-cmts",
	"gmod-gbrowse",
	"gmod-gene-page",
	"gmod-ontol-sw-dev",
	"gmod-phendiver",
	"gmod-pubsearch-dv",
	"gmod-resources",
#	"gmod-schema-cmts",
	"gmod-schema",
	"gmod-tripal-devel",
	"gmod-tripal",
	"gmod-ware-users",
#	"gmod-web-cmts",
	"gmod-webgbrowse",
	"isga-users",
	"sybil-info",
#	"turnkey-cmts",
	"turnkey-devel",
	"turnkey-users",
];
## SF lists: http://sourceforge.net/mailarchive/forum.php?forum_name=$list_name
## URLs: <a href="forum.php?forum_name=$list_name&amp;max_rows=25&amp;style=ultimate&amp;viewmonth=YYYYMM">(23)</a>

unless ($emulate)
{
	foreach my $l (@$sf_lists)
	{	my $url = 'http://sourceforge.net/mailarchive/forum.php?forum_name=' . $l;
		print STDERR "Getting $url...\n" if $verbose;
		my $page = get( $url );
		if (! defined ($page) )
		{	warn "SF page for $l not found";
			next;
		}

		while ($page =~ /<a href="forum.php\?forum_name=$l&amp;max_rows=25&amp;style=ultimate&amp;viewmonth=(\d{4})(\d{2})">\((\d+)\)<\/a>/g)
		{	## we have /viewmonth=YYYYMM">(\d+)
#			print STDERR "$1 -- $2 -- $3\n";
			$data->{by_date}{$1}{$2}{$l} = $3;
			$data->{by_list}{$l}{$1}{$2} = $3;
		}
		if (! $data->{by_list}{$l})
		{	warn "No data found for $l";
			## save the file to a temp dir to examine manually
			my $fh = $l . "-index.html";
			if ( open(FH, "> $temp_dir$fh") )
			{	print FH $page;
				close FH;
			}
			else
			{	die "Could not open $fh: $!\n";
			}

		}
	}
	print STDERR "Finished processing SF mailing lists\n" if $verbose;
}


my $url_h = {
## no response from biomart - due to https?
'biomart_users' => 'https://lists.biomart.org/pipermail/users/',
'biomart_announce' => 'https://lists.biomart.org/pipermail/announce/',
## 'apollo' => 'https://lists.lbl.gov/sympa/info/apollo',
'galaxy_announce' => 'http://lists.bx.psu.edu/pipermail/galaxy-announce/',
'galaxy_dev' => 'http://lists.bx.psu.edu/pipermail/galaxy-dev/',
'galaxy_user' => 'http://lists.bx.psu.edu/pipermail/galaxy-user/',
'maker-devel' => 'http://box290.bluehost.com/pipermail/maker-devel_yandell-lab.org/',
'intermine' => 'http://mail.intermine.org/pipermail/dev/',
};

foreach my $l (keys %$url_h)
{	my $url = $url_h->{$l};
	print STDERR "url: $url\n" if $verbose;
	my $index = get( $url );
	if (! defined ($index) )
	{	warn "Query returned no data";
		next;
	}
	## OK, let's get all the URLs ending in 'date.html'
	my @date_urls = ($index =~ /<a href="(\d{4}-[A-Z][a-z]{2,10}\/date.html)">\[ Date \]<\/a>/gi);

	if (! @date_urls || scalar @date_urls == 0)
	{	warn "No dates found for $l";
		## temporarily save the data to a file
		my $fh = $l . "-index.html";
		if ( open(FH, "> $temp_dir$fh") )
		{	print FH $index;
			close FH;
		}
		else
		{	die "Could not open $fh: $!\n";
		}
		next;
	}

	foreach my $d (@date_urls)
	{	## let's get those URLs!
		print STDERR "Getting $url$d\n" if $verbose;
		my $page = get($url . $d);
		if (! defined $page)
		{	warn "No data found for $d";
		}
		else
		{	## find the count
			my $err;
			if ($page =~ /<b>Messages:<\/b> (\d+)<p>/)
			{	my $n = $1;
				## convert the date into YYYY DD format
				## current format: YYYY-name of month
				if ($d =~ /^(\d{4})-([A-Z][a-z]{2,10})\/date.html/)
				{	if (! $months->{$2})
					{	warn "$l: month $2 in $d unknown";
						$err++;
					}
					else
					{	$data->{by_date}{$1}{$months->{$2}}{$l} = $n;
						$data->{by_list}{$l}{$1}{$months->{$2}} = $n;
					}
				}
				else
				{	warn "$l: unrecognized date format: $d";
					$err++;
				}
			}
			else
			{	$err++;
			}
			if ($err)
			{	warn "Could not find count for $d";
				## save the page somewhere
				my $temp = $l . "-" . $d;
				if ( open(FH, "> $temp_dir$temp") )
				{	print FH $page;
					close FH;
				}
				else
				{	die "Could not open $temp: $!\n";
				}
			}
		}
	}
}


## print out the data
## tab delim'd
my $outfile = $local_dir . 'ml-stats-table.txt';
## as a wiki table
my $wikiout = $local_dir . 'ml-stats-wiki.txt';
open('OUT', '>', $outfile) or die "Could not open $outfile: $!";
open('WIKI','>', $wikiout) or die "Could not open $wikiout: $!";


print OUT "name\t";
print WIKI '{| class="wikitable"' . "\n|-\n! name !! ";


if ($six_month_summary)
{	## gather up data into six month chunks
	foreach my $l (keys %{$data->{by_list}})
	{	foreach my $y (keys %{$data->{by_list}{$l}})
		{	foreach my $m (keys %{$data->{by_list}{$l}{$y}})
			{	if ($m > 6)
				{	$data->{by_6_mo}{$l}{$y."-7"} += $data->{by_list}{$l}{$y}{$m};
					$data->{all_6_mo}{$y."-7"} += $data->{by_list}{$l}{$y}{$m};
				}
				else
				{	$data->{by_6_mo}{$l}{$y."-1"} += $data->{by_list}{$l}{$y}{$m};
					$data->{all_6_mo}{$y."-1"} += $data->{by_list}{$l}{$y}{$m};
				}
			}
		}
	}
	## table header
	print OUT join("\t", sort keys %{$data->{all_6_mo}}) . "\n";
	print WIKI join(" !! ", sort keys %{$data->{all_6_mo}}) . "\n";

	## now the data
	foreach my $name (sort { lc($a) cmp lc($b) } keys %{$data->{by_list}})
	{	print OUT "$name\t" . join("\t", map {
			if ($data->{by_6_mo}{$name}{$_})
			{	$data->{by_6_mo}{$name}{$_}
			}
			else
			{	"0"
			}
		} sort keys %{$data->{all_6_mo}}) . "\n";

		print WIKI "|-\n| $name || " . join(' || ', map {
			if ($data->{by_6_mo}{$name}{$_})
			{	$data->{by_6_mo}{$name}{$_}
			}
			else
			{	"0"
			}
		} sort keys %{$data->{all_6_mo}}) . "\n";
	}
	## totals
	print OUT "total\t" . join("\t", map { $data->{all_6_mo}{$_} } sort keys %{$data->{all_6_mo}}) . "\n";
	print WIKI "|-\n| total || " . join(' || ', map { $data->{all_6_mo}{$_} } sort keys %{$data->{all_6_mo}}) . "\n";
}
else ## report by month
{
	print OUT "name\t";
	print WIKI '{| class="wikitable"' . "\n|-\n! name !! ";
	## table header
	print OUT join("\t", sort keys %{$data->{by_date}}) . "\n";
	print WIKI join(" !! ", sort keys %{$data->{by_date}}) . "\n";

	foreach my $name (sort { lc($a) cmp lc($b) } keys %{$data->{by_list}})
	{	print OUT "$name\t" . join("\t", map {
			if ($data->{by_list}{$name}{$_})
			{	$data->{by_list}{$name}{$_}
			}
			else
			{	"0"
			}
		} sort keys %{$data->{by_date}}) . "\n";

		print WIKI "|-\n| $name || " . join(' || ', map {
			if ($data->{by_list}{$name}{$_})
			{	$data->{by_list}{$name}{$_}
			}
			else
			{	"0"
			}
		} sort keys %{$data->{by_date}}) . "\n";
	}
}

print OUT "\n\n";
print WIKI "|}\n\n";

close(OUT);
close(WIKI);

exit(0);
