use strictures 2;

use Test::InDistDir;
use Test::More;

use Test::ReportPerlTidy;

run();
done_testing;
exit;

sub run {
    Test::ReportPerlTidy::run( sub { shift =~ /^Makefile\.PL$/ } );
    return;
}
