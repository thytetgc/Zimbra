#!/usr/bin/perl

use strict;
use lib "/opt/zimbra/libexec/scripts";
use Migrate;

my $fromVersion = 112;
my $toVersion   = 114;

# Inicializa as versões se necessário
initSchemaVersion();

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

    # Verifica a versão final do schema
    my $finalVersion = Migrate::getSchemaVersion();

    if ($finalVersion == $toVersion) {
        Migrate::log("Database schema already at version $toVersion. Nothing to do.");
    } elsif ($finalVersion > $toVersion) {
        Migrate::log("NOTE: Current DB version ($finalVersion) is already ahead of target ($toVersion). Skipping schema update.");
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

# -----------------------------------------------------------------
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

# -----------------------------------------------------------------
# Cria ou reseta a tabela schema_version e define o valor inicial
sub initSchemaVersion {
    my $mysql_pass = qx(/opt/zimbra/bin/zmlocalconfig -s -m nokey zimbra_mysql_password);
    chomp($mysql_pass);

    my $sql = qq{
        DROP TABLE IF EXISTS schema_version;
        CREATE TABLE schema_version (
            version INT NOT NULL
        );
        INSERT INTO schema_version (version) VALUES ($fromVersion);
    };

    my $cmd = qq(/opt/zimbra/bin/mysql -u zimbra -p$mysql_pass zimbra -e "$sql");
    system($cmd);

    # Sincroniza a tabela config
    my $cmd2 = qq(/opt/zimbra/bin/mysql -u zimbra -p$mysql_pass -e "UPDATE zimbra.config SET value = $fromVersion WHERE name = 'db.version';");
    system($cmd2);

    # Garante também que o valor foi inserido corretamente
    my $cmd3 = qq(/opt/zimbra/bin/mysql -u zimbra -p$mysql_pass -e "UPDATE schema_version SET version = $fromVersion;" zimbra);
    system($cmd3);

    Migrate::log("Initialized schema_version and config to version $fromVersion");
}
