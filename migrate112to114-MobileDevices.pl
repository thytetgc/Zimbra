#!/usr/bin/perl

use strict;
use lib "/opt/zimbra/libexec/scripts";
use Migrate;

my $fromVersion = 112;
my $toVersion   = 114;

Migrate::verifySchemaVersion($fromVersion);

eval {
    # 1. Garante que a tabela schema_version existe corretamente
    my $mysql_pass = qx(/opt/zimbra/bin/zmlocalconfig -s -m nokey zimbra_mysql_password);
    chomp($mysql_pass);

    my $drop_create = qq{
        DROP TABLE IF EXISTS schema_version;
        CREATE TABLE schema_version (
            version INT NOT NULL
        );
        INSERT INTO schema_version (version) VALUES ($fromVersion);
    };
    Migrate::log("Ensuring schema_version table exists and is initialized to $fromVersion");
    system("/opt/zimbra/bin/mysql -u zimbra -p$mysql_pass zimbra -e \"$drop_create\"");

    # 2. Atualiza a tabela config para refletir o schema atual
    Migrate::log("Updating zimbra.config db.version to $fromVersion");
    my $updateConfig = qq{
        UPDATE config SET value = $fromVersion WHERE name = 'db.version';
    };
    system("/opt/zimbra/bin/mysql -u zimbra -p$mysql_pass zimbra -e \"$updateConfig\"");

    # 3. Adiciona coluna mobile_operator se necessário
    if (!columnExists("mobile_devices", "mobile_operator")) {
        Migrate::log("Adding 'mobile_operator' column to mobile_devices");
        my $sql = "ALTER TABLE mobile_devices ADD COLUMN mobile_operator VARCHAR(512);";
        Migrate::runSql($sql);
    } else {
        Migrate::log("Column 'mobile_operator' already exists. Skipping.");
    }

    # 4. Adiciona coluna last_updated_by se necessário
    if (!columnExists("mobile_devices", "last_updated_by")) {
        Migrate::log("Adding 'last_updated_by' column to mobile_devices");
        my $sql = "ALTER TABLE mobile_devices ADD COLUMN last_updated_by ENUM('Admin','User') DEFAULT 'User';";
        Migrate::runSql($sql);
    } else {
        Migrate::log("Column 'last_updated_by' already exists. Skipping.");
    }

    # 5. Atualiza o schema se necessário
    my $finalVersion = Migrate::getSchemaVersion();

    if ($finalVersion == $toVersion) {
        Migrate::log("Database schema already at version $toVersion. Nothing to do.");
    } elsif ($finalVersion > $toVersion) {
        Migrate::log("NOTE: Current DB version ($finalVersion) is ahead of target ($toVersion). Skipping schema update.");
    } else {
        Migrate::log("Updating DB schema version from $fromVersion to $toVersion.");
        Migrate::updateSchemaVersion($fromVersion, $toVersion);
        Migrate::log("Database schema updated from $fromVersion to $toVersion successfully.");
    }

};

if ($@) {
    Migrate::log("ERROR: Schema migration failed: $@");
    exit(1);
}

exit(0);

# ---------------------------------------------------------
# Verifica se a coluna existe
sub columnExists {
    my ($table, $column) = @_;

    my $mysql_pass = qx(/opt/zimbra/bin/zmlocalconfig -s -m nokey zimbra_mysql_password);
    chomp($mysql_pass);

    my $sql = qq{
        SELECT COUNT(*) FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA='zimbra' AND TABLE_NAME='$table' AND COLUMN_NAME='$column';
    };

    my $cmd = qq(/opt/zimbra/bin/mysql -u zimbra -p$mysql_pass --batch --skip-column-names -e "$sql");
    my $result = qx($cmd);
    chomp($result);

    return $result > 0;
}
