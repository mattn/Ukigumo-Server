use strict;
use warnings;
use utf8;
use Test::More;
use t::Util;
use Plack::Util;
use Test::Requires 'LWP::Protocol::PSGI', 'LWP::UserAgent';
use JSON;
use Ukigumo::Server;

my $app = Plack::Util::load_psgi 'app.psgi';
LWP::Protocol::PSGI->register($app);

{
	my $c = Ukigumo::Server->new;
	$c->dbh->do(q{DELETE FROM report});
}

my $ua = LWP::UserAgent->new();
my $url = do {
	my @branch = 'master';
	my $res = $ua->post('http://localhost/api/v1/report/add', [
		project => 'TestingProject',
		branch => $branch[int rand @branch],
		revision => 3,
		status  => 1,
		body    => '....',
        repo => 'git://...',
        vc_log => 'testtest',
	]);
	is $res->code, 200;
	note $res->content;
	my $dat = decode_json($res->content);
	like $dat->{report}->{report_id}, qr{^[0-9]+$};
	like $dat->{report}->{url}, qr{^http://};
	is $dat->{report}->{last_status}, undef;
	$dat->{report}->{url};
};
{
	my $res = $ua->get($url);
	is($res->code, 200, $url) or note $res->content;
}
{
    my $url = 'http://localhost/report/9999999999';
	my $res = $ua->get($url);
	is $res->code, 404, $url;
}

do {
	my $res = $ua->post('http://localhost/api/v1/report/add', [
		project => 'TestingProject',
		branch => 'master',
		revision => 3,
		status  => 2, 
		body    => '....',
        repo => 'git://...',
	]);
	is $res->code, 200;
	note $res->content;
	my $dat = decode_json($res->content);
	is $dat->{report}->{last_status}, 1, 'got last status successfully';
};

subtest 'validation error' => sub {
	my $res = $ua->post('http://localhost/api/v1/report/add', [
		# project => 'TestingProject', # <= do not pass this parameter.
		branch => 'master',
		revision => 3,
		status  => 2,
		body    => '....',
        repo => 'git://...',
    ]);
	is $res->code, 400;
	note $res->content;
	my $dat = decode_json($res->content);
	like $dat->{error}->{message}, qr{Missing parameter: 'project'};
};

subtest 'api list' => sub {
    my $res = $ua->get(
        'http://localhost/api/v1/report/search?project=TestingProject&branch=master&revision=3',
    );
	is $res->code, 200;
	note $res->content;
	my $dat = decode_json($res->content);
    is_deeply $dat,
      {
        'reports' => [
            {
                'status'    => 1,
                'report_id' => 1
            },
            {
                'status'    => 2,
                'report_id' => 2
            }
        ]
      };
};

done_testing;

