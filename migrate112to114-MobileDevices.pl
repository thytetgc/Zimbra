#!/usr/bin/perl

use strict;
use lib "/opt/zimbra/libexec/scripts";
use Migrate;

my $fromVersion = 112;
my $toVersion   = 114;

Migrate::verifySchemaVersion($fromVersion);

eval {
    # Adiciona a coluna 'mobile_operator' se não existir
    if (!columnExists("mobile_devices", "mobile_operator")) {
        Migrate::log("Adding 'mobile_operator' column to mobile_devices");
        my $sql = "ALTER TABLE mobile_devices ADD COLUMN mobile_operator VARCHAR(512);";
        Migrate::runSql($sql);
    } else {
        Migrate::log("Column 'mobile_operator' already exists. Skipping.");
    }

    # Adiciona a coluna 'last_updated_by' se não existir
    if (!columnExists("mobile_devices", "last_updated_by")) {
        Migrate::log("Adding 'last_updated_by' column to mobile_devices");
        my $sql = "ALTER TABLE mobile_devices ADD COLUMN last_updated_by ENUM('Admin','User') DEFAULT 'User';";
        Migrate::runSql($sql);
    } else {
        Migrate::log("Column 'last_updated_by' already exists. Skipping.");
    }

    # Verifica a versão final do schema e decide se precisa atualizar
    my $finalVersion = Migrate::getSchemaVersion();

    if ($finalVersion == $toVersion) {
        Migrate::log("Database schema already at version $toVersion. Nothing to do.");
    } elsif ($finalVersion > $toVersion) {
        Migrate::log("NOTE: Current DB version ($finalVersion) is already ahead of target ($toVersion). Skipping schema update.");
    } else {
        Migrate::log("Updating DB schema version from $fromVersion to $toVersion.");
        Migrate::updateSchemaVersion($fromVersion, $toVersion);

        # Atualiza também a tabela schema_version
        my $mysql_pass = getMysqlPass();
        my $cmd = qq(/opt/zimbra/bin/mysql -u zimbra -p$mysql_pass --batch -e "UPDATE schema_version SET version = $toVersion;" zimbra);
        my $res = qx($cmd);
        Migrate::log("Updated schema_version table to $toVersion");

        Migrate::log("Database schema updated from $fromVersion to $toVersion successfully.");
    }
};

if ($@) {
    Migrate::log("ERROR: Schema migration failed: $@");
    exit(1);
}

exit(0);

# -----------------------------------------------------------------
# Verifica se uma coluna existe na tabela
sub columnExists {
    my ($table, $column) = @_;

    my $mysql_pass = getMysqlPass();

    my $sql = qq{
        SELECT COUNT(*) FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA='zimbra' AND TABLE_NAME='$table' AND COLUMN_NAME='$column';
    };

    my $cmd = qq(/opt/zimbra/bin/mysql -u zimbra -p$mysql_pass --batch --skip-column-names -e "$sql");
    my $result = qx($cmd);
    chomp($result);

    return $result > 0;
}

# -----------------------------------------------------------------
# Recupera a senha do MySQL
sub getMysqlPass {
    my $pass = qx(/opt/zimbra/bin/zmlocalconfig -s -m nokey zimbra_mysql_password);
    chomp($pass);
    return $pass;
}
