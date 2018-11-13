#!/usr/bin/env perl
use Dancer2;
#use Dancer2::Plugin::Swagger2;
use Plack::Runner;

## For some reason Apache SetEnv directives dont propagate
## correctly to the dispatchers, so forcing PSGI and env here 
## is safer.
set apphandler => 'PSGI';
set environment => 'production';

# Legger på sikkerhets-headere med fornuftige defaultverdier:
set header 'X-XSS-Protection' => "1; 'mode=block'";
set header 'X-Download-Options' => 'noopen';
set header 'X-Content-Type-Options' => 'nosniff';
set header 'Strict-Transport-Security' => 'max-age=3600';
set header 'X-Frame-Options' => 'DENY';
set header 'Server' => 'nginx';
set header 'Content-Security-Policy' =>  "default-src 'self'; font-src *;img-src * data:; script-src *; style-src *;";

my $psgi;
$psgi = path($ENV{'DOCUMENT_ROOT'}, 'bin', 'app.psgi');
die "Unable to read startup script: $psgi" unless -r $psgi;

Plack::Runner->run($psgi);
