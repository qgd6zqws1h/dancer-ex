package inventory;
use Dancer2 ':syntax';
use Dancer2 ':script';
use Template;
use DBI;
use DBD::mysql;

set template => 'template_toolkit';
set layout => undef;
set views => File::Spec->rel2abs('./views');

sub get_connection{
    if ( defined $ENV{'PLACK_ENV'} && $ENV{'PLACK_ENV'} eq 'development' ) {
	$ENV{'DATABASE_SERVICE_NAME'}="DEVMYSQL";
	$ENV{'DEVMYSQL_SERVICE_HOST'}='127.0.0.1';
	$ENV{'DEVMYSQL_SERVICE_PORT'}='3306';
	$ENV{'MYSQL_DATABASE'}='dancer2';
	$ENV{'MYSQL_USER'}='dancer2';
	$ENV{'MYSQL_PASSWORD'}='dance-dance-revolution';
    }

    my $service_name=uc $ENV{'DATABASE_SERVICE_NAME'};
    my $db_host=$ENV{"${service_name}_SERVICE_HOST"};
    my $db_port=$ENV{"${service_name}_SERVICE_PORT"};
    my $dbh=DBI->connect("DBI:mysql:database=$ENV{'MYSQL_DATABASE'};host=$db_host;port=$db_port",$ENV{'MYSQL_USER'},$ENV{'MYSQL_PASSWORD'}, { RaiseError => 1 } ) or die ("Couldn't connect to database: " . DBI->errstr );
    return $dbh;
}

sub init_db{
    my $dbh = $_[0];
    eval { $dbh->do("DROP TABLE foo") };
    $dbh->do("CREATE TABLE foo (id INTEGER not null auto_increment, name VARCHAR(20), email VARCHAR(30), PRIMARY KEY(id))");
    $dbh->do("INSERT INTO foo (name, email) VALUES (" . $dbh->quote("Eric Cartman") . ", " . $dbh->quote("Cartman\@SouthPark.com") . ")");
    $dbh->do("INSERT INTO foo (name, email) VALUES (" . $dbh->quote("Stan March") . ", " . $dbh->quote("March\@SouthPark.com") . ")");
    $dbh->do("INSERT INTO foo (name, email) VALUES (" . $dbh->quote("Kyle Broflovski") . ", " . $dbh->quote("Broflovski\@SouthPark.com") . ")");
    $dbh->do("INSERT INTO foo (name, email) VALUES (" . $dbh->quote("Kenny McCormick") . ", " . $dbh->quote("Kenny\@SouthPark.com") . ")");
};

get '/user/:id' => sub {
    addSecurityHeaders();
    my $timestamp = localtime();
    my $dbh = get_connection();

    my $sth = $dbh->prepare("SELECT * FROM foo WHERE id=?") or die "Could not prepare statement: " . $dbh->errstr;
    $sth->execute(params->{id});

    my $data = $sth->fetchall_hashref('id');
    $sth->finish();

    template user => {timestamp => $timestamp, data => $data};
};
sub addSecurityHeaders() {
    set header 'X-XSS-Protection' => "1; 'mode=block'";
    set header 'X-Download-Options' => 'noopen';
    set header 'X-Content-Type-Options' => 'nosniff';
    set header 'Strict-Transport-Security' => 'max-age=3600';
    set header 'X-Frame-Options' => 'DENY';
    #set header 'Server' => 'nginx';
    set header 'Content-Security-Policy' =>
	"default-src 'self'; font-src *;img-src * data:; script-src *; style-src *";
}
get '/headers' => sub {
    # Legger på sikkerhets-headere med fornuftige defaultverdier:
    addSecurityHeaders();
    my $hrefReq=request->params;
    my $headerObj=request->headers();
    my $headerNames="";
    if (defined $headerObj && $headerObj ) {
	#$headerObj->remove_header('Server');
	foreach ($headerObj->header_field_names()) {
	    $headerNames.=sprintf("%-42s: %s\n","$_",$headerObj->header("$_"));
	}
    }
    my $htmlOutPut="<h3>headers</h3>\n<pre>\n$headerNames\n<hr>";
    $htmlOutPut.="<h3>Parameters</h3><pre>\n";
    foreach (sort keys %{$hrefReq} ) {
	$htmlOutPut.=sprintf("%-42s: %s\n","$_","$$hrefReq{$_}");
    }
#    $htmlOutPut.="Request URI: $requestUri\n";
#    $htmlOutPut.="URI base: $uriBase\n";
    $htmlOutPut.="\n</pre>\n";
    return $htmlOutPut;
};

get '/env' => sub {
    addSecurityHeaders();
    my $htmlOutPut="<h3>Env</h3>\n<pre>\n";
    foreach (sort keys %ENV ) {
	$htmlOutPut.=sprintf("%-42s: %s\n","$_","$ENV{$_}");
    }
    $htmlOutPut.="\n</pre>\n";
    return $htmlOutPut;
};

get '/req' => sub {
    addSecurityHeaders();
    my $hrefReq=request->params;
    my $requestUri=request->request_uri;
    my $uriBase=request->uri_base;
    my $htmlOutPut="<h3>Request</h3>\n<pre>\n";
    foreach (sort keys %{$hrefReq} ) {
	$htmlOutPut.=sprintf("%-42s: %s\n","$_","$$hrefReq{$_}");
    }
    $htmlOutPut.="Request URI: $requestUri\n";
    $htmlOutPut.="URI base: $uriBase\n";
    $htmlOutPut.="\n</pre>\n";
    return $htmlOutPut;
};


get '/' => sub {
    addSecurityHeaders();
    my $dbh = get_connection();

    eval { $dbh->prepare("SELECT * FROM foo")->execute() };
    init_db($dbh) if $@;

    my $sth = $dbh->prepare("SELECT * FROM foo");
    $sth->execute();

    my $data = $sth->fetchall_hashref('id');
    $sth->finish();

    my $timestamp = localtime();
    template index => {data => $data, timestamp => $timestamp};
};

post '/' => sub {

   my $name = params->{name};
   my $email = params->{email};

   my $dbh = get_connection();
   print "#DEBUG: name:'$name' email:'$email'\n";
   $dbh->do("INSERT INTO foo (name, email) VALUES (" . $dbh->quote($name) . ", " . $dbh->quote($email) . ") ");

   my $sth = $dbh->prepare("SELECT * FROM foo");
   $sth->execute();

   my $data = $sth->fetchall_hashref('id');
   $sth->finish();

   my $timestamp = localtime();
   template index => {data => $data, timestamp => $timestamp};
};

get '/health' => sub {
    addSecurityHeaders();
    my $dbh  = get_connection();
    my $ping = $dbh->ping();

    if ($ping and $ping == 0) {
	# This is the 'true but zero' case, meaning that ping() is not implemented for this DB type.
	# See: http://search.cpan.org/~timb/DBI-1.636/DBI.pm#ping
	return "WARNING: Database health uncertain; this database type does not support ping checks.";
    }
    elsif (not $ping) {
	status 'error';
	return "ERROR: Database did not respond to ping.";
    }
    return "SUCCESS: Database connection appears healthy.";
};

true;
