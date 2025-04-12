#!/usr/bin/perl
#
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
#

use strict;
use Migrate;

Migrate::verifySchemaVersion(112);

addMobileOperatorColumn();

Migrate::updateSchemaVersion(112, 113);

exit(0);

#####################

sub addMobileOperatorColumn() {
    my $check_sql = "SHOW COLUMNS FROM mobile_devices LIKE 'mobile_operator';";

    my $tmpfile = "/tmp/zimbra_check_mobile_operator.$$";
    my $password_cmd = "`zmlocalconfig -s -m nokey mysql_root_password | awk '{print \$2}'`";

    my $check_cmd = "/opt/zimbra/bin/mysql -N -u root -p$password_cmd -e \"$check_sql\" zimbra > $tmpfile 2>/dev/null";

    system($check_cmd);

    my $col_exists = 0;

    if (-e $tmpfile) {
        open(my $fh, "<", $tmpfile);
        while (my $line = <$fh>) {
            if ($line =~ /mobile_operator/) {
                $col_exists = 1;
                last;
            }
        }
        close($fh);
        unlink $tmpfile;
    }

    if ($col_exists) {
        Migrate::log("Column 'mobile_operator' already exists. Skipping...");
    } else {
        my $sql = <<MOBILE_DEVICES_ADD_COLUMN_EOF;
ALTER TABLE mobile_devices ADD COLUMN mobile_operator VARCHAR(512);
MOBILE_DEVICES_ADD_COLUMN_EOF

        Migrate::log("Adding mobile_operator column to ZIMBRA.MOBILE_DEVICES table.");
        Migrate::runSql($sql);
    }
}
