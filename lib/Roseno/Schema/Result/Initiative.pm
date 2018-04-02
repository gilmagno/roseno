use utf8;
package Roseno::Schema::Result::Initiative;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use MooseX::MarkAsMethods autoclean => 1;
extends 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime", "TimeStamp", "PassphraseColumn");
__PACKAGE__->table("initiatives");
__PACKAGE__->add_columns(
  "id",
  {
    data_type   => "text",
    is_nullable => 0,
    original    => { data_type => "varchar" },
  },
  "title",
  {
    data_type   => "text",
    is_nullable => 1,
    original    => { data_type => "varchar" },
  },
  "subtitle",
  { data_type => "text", is_nullable => 1 },
  "body",
  { data_type => "text", is_nullable => 1 },
  "published",
  { data_type => "timestamp with time zone", is_nullable => 1 },
  "image",
  {
    data_type   => "text",
    is_nullable => 1,
    original    => { data_type => "varchar" },
  },
  "image_subtitle",
  { data_type => "text", is_nullable => 1 },
  "image_alt_text",
  { data_type => "text", is_nullable => 1 },
  "created",
  { data_type => "timestamp with time zone", is_nullable => 1 },
  "updated",
  { data_type => "timestamp with time zone", is_nullable => 1 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->has_many(
  "initiative_files",
  "Roseno::Schema::Result::InitiativeFile",
  { "foreign.initiative_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07045 @ 2018-03-30 12:26:17
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:Oa3Y/mV3h2kEiBe5J1YQzQ

__PACKAGE__->add_columns('+created' => { set_on_create => 1 },
                         '+updated' => { set_on_create => 1,
                                         set_on_update => 1 });

use Text::Markdown qw/markdown/;

sub body_as_html     { markdown( $_[0]->body )     }

# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
