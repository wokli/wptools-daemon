use strict;
use warnings;
package wpcore;

use Google::CostUploadAPI;
use Yandex::DirectAPI;

use JSON;
use LWP::UserAgent;
use DateTime;

use HTTP::Request;
use constant DOLLAR => 35;

# TODO: write proper validation
sub _validate_conf {
  return shift;
}

sub _get_access_token {
  my $self = shift;

  my $ua = new LWP::UserAgent;
  my $r = new HTTP::Request(POST => 'https://accounts.google.com/o/oauth2/token', 
    ['Content-Type', 'application/x-www-form-urlencoded'],
    "client_id=".$ENV{GOOGLE_CLIENT_ID}."&client_secret=".$ENV{GOOGLE_CLIENT_SECRET}."&refresh_token=".$self -> {'conf'} -> {'google_refresh_token'}."&grant_type=refresh_token"
  );
  my $response = $ua -> request($r);

  unless ($response -> is_success) { warn "Failed to fetch access token: ".$response -> status_line; return undef; }
  my $decoded = eval { decode_json($response -> content) };
  warn $@ if $@;
  
  $decoded ? return $decoded -> {'access_token'} : return undef;
}


sub new {
  my $class = shift;
  my $self = {};
  my $conf = shift;

  $self -> {'conf'} = _validate_conf($conf) or die "config parse failed!";

  bless $self, $class;
  $self -> {'google_api'} = new Google::CostUploadAPI(
    token => $self -> _get_access_token,
    account => $self -> {'conf'} -> {'account'},
    property => $self -> {'conf'} -> {'property'}
  );

   $self -> {'yandex_api'} = new Yandex::DirectAPI(token => $self -> {'conf'} -> {'yandex_token'}, login => $self -> {'conf'} -> {'yandex_login'});

  return $self;
}

# getter to avoid typing all that {} and ''
sub google {
  my $self = shift;
  return $self -> {'google_api'};
}

sub yandex {
	my $self = shift;
	return $self -> {'yandex_api'};
}

sub conf {
  my $self = shift;
  return $self -> {'conf'};
}

sub dubstep {
  my $self = shift;
  return "Wobwobwobwobwobwobwobwobwobwob";
}

sub _get_string {
  my $href = shift;
  my $banner = shift;

  return join (',',
      $href -> {'utm_medium'}||'nomedium', # ga:medium
      $href -> {'utm_source'}||'nosource', # ga:source
      $banner -> {'Sum'} * DOLLAR,    # ga:adCost
      $banner -> {'Clicks'}, # ga:adClicks
      $banner -> {'Shows'},  # ga:impressions
      $href -> {'utm_campaign'}||'nocampaign', #ga:campaign
      $href -> {'utm_content'}||'nocontent' #ga:adContent
    );
}

sub get_data {
  my $self = shift;
  my $date = shift;

  my $api = $self -> yandex;
  my $yesterday = DateTime -> now() -> subtract(days => 1) -> ymd;

  #TODO: fix, use login from yandex api constructor
  my $campaigns = $api -> get_active_campaigns([$self -> {'conf'} -> {'yandex_login'}]);
  my $campaign_ids = [map {''.$_ -> {'CampaignID'}} @$campaigns];

  # href here
  my $banners = $api -> get_banners($campaign_ids, 10);

  # sum-clicks-shows etc here
  my $banners_stat = $api -> get_banners_stat_mass($yesterday, $yesterday, $campaign_ids);

  my $result = {};
  for my $campaign (@$campaign_ids) {
    # TODO: shorten this
    $result -> {$campaign} = {
      'bytes' => '',
      'sum' => 0,
      'clicks' => 0,
      'shows' => 0
    };

    for my $banner (@{$banners_stat -> {$campaign}}) {
      my $string = _get_string($banners -> {$banner -> {'BannerID'}}, $banner);
      
      for (qw/Sum Clicks Shows/) { $result -> {$campaign} -> {lc $_} += $banner -> {$_} };
      $result -> {$campaign} -> {'bytes'} .= $string . "\n";
    }
  }
  return $result;

}





1;