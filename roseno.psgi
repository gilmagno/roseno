use strict;
use warnings;

use Roseno;

my $app = Roseno->apply_default_middlewares(Roseno->psgi_app);
$app;

