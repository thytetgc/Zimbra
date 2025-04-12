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
use lib "/opt/zimbra/libexec/scripts";  # Adiciona caminho para o módulo Migrate.pm
use Migrate;

# Verifica se o schema está na versão esperada
Migrate::verifySchemaVersion(112);

# Adiciona a coluna mobile_operator
addMobileOperatorColumn();

# Adiciona a coluna last_updated_by
addLastUpdatedByColumn();

# Atualiza a versão do schema diretamente para 114
Migrate::updateSchemaVersion(112, 114);

exit(0);

#####################
# Subrotina para adicionar a coluna mobile_operator
sub addMobileOperatorColumn() {
    my $sql = <<MOBILE_DEVICES_ADD_COLUMN_EOF;
ALTER TABLE mobile_devices ADD COLUMN mobile_operator VARCHAR(512);
MOBILE_DEVICES_ADD_COLUMN_EOF

    Migrate::log("Adding mobile_operator column to ZIMBRA.MOBILE_DEVICES table.");
    Migrate::runSql($sql);
}

# Subrotina para adicionar a coluna last_updated_by
sub addLastUpdatedByColumn() {
    my $sql = <<MOBILE_DEVICES_ADD_COLUMN_EOF;
ALTER TABLE mobile_devices ADD COLUMN last_updated_by ENUM('Admin','User') DEFAULT 'User';
MOBILE_DEVICES_ADD_COLUMN_EOF

    Migrate::log("Adding last_updated_by column to ZIMBRA.MOBILE_DEVICES table.");
    Migrate::runSql($sql);
}
