#!/usr/bin/perl

# ***** BEGIN LICENSE BLOCK *****
# Zimbra Collaboration Suite Server
# Copyright (C) 2020 Synacor, Inc.
#
# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software Foundation,
# version 2 of the License.
#
# This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
# without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
# See the GNU General Public License for more details.
# You should have received a copy of the GNU General Public License along with this program.
# If not, see <https://www.gnu.org/licenses/>.
# ***** END LICENSE BLOCK *****

use strict;
use Migrate;

Migrate::verifySchemaVersion(112);

addColumnIfNotExists("mobile_devices", "mobile_operator", "VARCHAR(512)");
addColumnIfNotExists("mobile_devices", "last_updated_by", "ENUM('Admin','User') DEFAULT 'User'");

Migrate::updateSchemaVersion(112, 114);

exit(0);

#####################

sub addColumnIfNotExists {
    my ($table, $column, $definition) = @_;

    Migrate::log("Checking if column '$column' exists in table '$table'...");

    my $check_sql = qq{
        SELECT COUNT(*) FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = 'zimbra'
        AND TABLE_NAME = '$table'
        AND COLUMN_NAME = '$column';
    };

    my $cmd = "/opt/zimbra/bin/mysql -u zimbra -p" .
              `'/opt/zimbra/bin/zmlocalconfig -s -m nokey zimbra_mysql_password'` .
              " --database=zimbra --batch --skip-column-names -e \"$check_sql\"";

    my $exists = `$cmd`;
    chomp($exists);

    if ($exists == 0) {
        Migrate::log("Adding column '$column' to table '$table'.");
        my $alter_sql = "ALTER TABLE $table ADD COLUMN $column $definition;";
        Migrate::runSql($alter_sql);
    } else {
        Migrate::log("Column '$column' already exists. Skipping.");
    }
}
