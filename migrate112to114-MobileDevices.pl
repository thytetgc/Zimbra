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
use lib "/opt/zimbra/libexec/scripts";  # Caminho para Migrate.pm
use Migrate;

my $success = 1;

Migrate::verifySchemaVersion(112);

$success &= addColumnIfNotExists("mobile_operator", "VARCHAR(512)");
$success &= addColumnIfNotExists("last_updated_by", "ENUM('Admin','User') DEFAULT 'User'");

if ($success) {
    Migrate::log("Atualizando versão do schema de 112 para 114.");
    Migrate::updateSchemaVersion(112, 114);
    exit(0);
} else {
    Migrate::log("Erro detectado durante a migração. Versão do schema NÃO será alterada.");
    exit(1);
}

#####################
sub addColumnIfNotExists {
    my ($column_name, $column_def) = @_;

    my $sql_check = qq{
        SELECT COUNT(*) FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA='zimbra'
        AND TABLE_NAME='mobile_devices'
        AND COLUMN_NAME='$column_name'
    };

    my $count = Migrate::runSqlReturnOneValue($sql_check);

    if ($count == 0) {
        my $sql_add = qq{
            ALTER TABLE mobile_devices ADD COLUMN $column_name $column_def
        };
        Migrate::log("Adicionando coluna '$column_name' à tabela ZIMBRA.MOBILE_DEVICES.");
        return Migrate::runSql($sql_add);
    } else {
        Migrate::log("Coluna '$column_name' já existe. Pulando adição.");
        return 1;
    }
}
