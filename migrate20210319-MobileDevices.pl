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

Migrate::verifySchemaVersion(113);

addLastUpdatedByColumn();

Migrate::updateSchemaVersion(113, 114);

exit(0);

#####################

sub addLastUpdatedByColumn() {
    # Verificar se a coluna 'last_updated_by' já existe na tabela 'mobile_devices'
    my $check_column_sql = "SHOW COLUMNS FROM mobile_devices LIKE 'last_updated_by'";

    # Rodar o comando SQL para verificar a coluna
    my $sth = Migrate::runSql($check_column_sql);
    
    # Verificar se o resultado contém alguma linha (indicando que a coluna já existe)
    if ($sth && $sth->[0]) {
        Migrate::log("Coluna 'last_updated_by' já existe. Pulando a criação.");
        return;
    }
    
    # Caso a coluna não exista, adicionar a coluna
    my $sql = <<MOBILE_DEVICES_ADD_COLUMN_EOF;
ALTER TABLE mobile_devices ADD COLUMN last_updated_by ENUM('Admin','User') DEFAULT 'User';
MOBILE_DEVICES_ADD_COLUMN_EOF

    Migrate::log("Adding last_updated_by column to ZIMBRA.MOBILE_DEVICES table.");
    Migrate::runSql($sql);
}
