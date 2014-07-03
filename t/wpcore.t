use strict;
use warnings;
use Test::More qw/no_plan/;

BEGIN { use_ok('wpcore') };
ok(my $wpc =  new wpcore ({
	'google_token' => $ENV{'GOOGLE_TOKEN'},
	'yandex_token' => $ENV{'YANDEX_TOKEN'},
	'yandex_login' => $ENV{'YANDEX_LOGIN'},
 	}), 'constructor;');

is(ref $wpc -> google, "Google::CostUploadAPI", "google api is ready;");
is(ref $wpc -> yandex, "Yandex::DirectAPI", "yandex api is ready;");
ok($wpc -> get_data(), "get_data sanity test;")