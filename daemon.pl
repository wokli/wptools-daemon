use strict;
use warnings;
use 5.012;
use JSON;
use File::Slurp;
use lib './lib';
use wpcore;
use Google::CostUploadAPI;
use DateTime;
use Data::Dumper;

use constant HEAD => "ga:medium,ga:source,ga:adCost,ga:adClicks,ga:impressions,ga:campaign,ga:adContent\n";
use constant DRY => 0;
# TODO: wtf deal with it
my $file = shift @ARGV;
my $json = read_file($file);
my $conf = decode_json($json);

my $wpc = new wpcore($conf);
say "config loaded";
my $campaigns_data = $wpc -> get_data();
say "data loaded";

for (keys $campaigns_data) {
	say join " ", $_, $campaigns_data -> {$_} -> {'clicks'}, $campaigns_data -> {$_} -> {'shows'}, $campaigns_data -> {$_} -> {'sum'};
}

=head
$campaign_data = {
	camp_id1 => {bytes => 'upload_data1', ...},
	camp_id2 => {bytes => 'upload_data2', ...},
	...
}
=cut
my $default_data = '';
my $yest = DateTime -> now() -> subtract(days => 1) -> ymd;

for my $cds (keys $wpc -> conf -> {cds_map}) {
	my $string = join '', map {($campaigns_data -> {$_} -> {'bytes'})||''} @{$wpc -> conf -> {'cds_map'} -> {$cds}};
	if ($string) {
		# TODO: data_source => source maybe? or both?
		my $res = $wpc -> google -> upload ( data_source => $cds, date => $yest, bytes => HEAD.$string, dry => DRY, reset => 1, append => 1 );
		# TODO: ugly interface for getting error
		unless ($res) { warn "$cds: " . $wpc -> google -> get_error() -> {'error'} -> {'message'} . "\n"; }
		else { 
			say "$cds loaded OK with " . join " ", @{$wpc -> conf -> {'cds_map'} -> {$cds}};
			say Dumper($res);
		}
	}
}

# find "default" campaigns
my @processed = ();
for my $cds (keys $wpc -> conf -> {cds_map}) {
	push @processed, $_ for (@{$wpc -> conf -> {cds_map} -> {$cds}});
}

my @default = grep { not $_ ~~ @processed } keys $campaigns_data;
for my $camp (@default) {
	$default_data .= $campaigns_data -> {$camp} -> {'bytes'};
}
say "uploading defaults : " . join " ", @default;
if ($default_data) {
	my $res = $wpc -> google -> upload(
		dry => DRY,
		data_source => $wpc -> conf -> {'default_cds'}, 
		date => $yest, 
		bytes => HEAD.$default_data,
		append => 1,
		reset => 1
	);
	unless ($res) { warn $wpc -> conf -> {'default_cds'}.": " . $wpc -> google -> get_error() -> {'error'} -> {'message'} . "\n"; }
	else { say "default data loaded ok"};
}