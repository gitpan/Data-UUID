# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test;
BEGIN { plan tests => 1 };
use Data::UUID;
ok(1); # If we made it this far, we're ok.

#########################

# Insert your test code below, the Test module is use()ed here so read
# its man page ( perldoc Test ) for help writing this test script.

ok($ug = new Data::UUID);

$uuid1 = $ug->create();
$uuid2 = $ug->to_hexstring($uuid1);
$uuid3 = $ug->from_string($uuid2);
ok(!$ug->compare($uuid1,$uuid3));

$uuid4 = $ug->to_b64string($uuid1);
$uuid5 = $ug->to_b64string($uuid3);
ok($uuid4 eq $uuid5);

$uuid6 = $ug->from_b64string($uuid4);
ok(!$ug->compare($uuid6,$uuid1));
