#!/usr/bin/perl

use strict;
use lib "/opt/zimbra/libexec/scripts";
use Migrate;

my $fromVersion = 112;
my $toVersion   = 114;

Migrate::verifySchemaVersion($fromVersion);

eval {
    ensureSchemaVersionTable();

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

    # Verifica e atualiza a versão do schema
    my $finalVersion = Migrate::getSchemaVersion();

    if ($finalVersion == $toVersion) {
        Migrate::log("Database schema already at version $toVersion. Nothing to do.");
    } elsif ($finalVersion > $toVersion) {
        Migrate::log("NOTE: Current DB version ($finalVersion) is ahead of target ($toVersion). Skipping.");
    } else {
        Migrate::log("Updating DB schema version from $fromVersion to $toVersion.");
        Migrate::updateSchemaVersion($fromVersion, $toVersion);
        updateConfigAndSchemaVersion($toVersion);
        Migrate::log("Database schema updated from $fromVersion to $toVersion successfully.");
    }
};

if ($@) {
    Migrate::log("ERROR: Schema migration failed: $@");
    exit(1);
}

exit(0);

# -----------------------------
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

# -----------------------------
# Cria a tabela schema_version se não existir
sub ensureSchemaVersionTable {
    my $mysql_pass = qx(/opt/zimbra/bin/zmlocalconfig -s -m nokey zimbra_mysql_password);
    chomp($mysql_pass);

    my $check = qq(
        SELECT COUNT(*) FROM information_schema.tables 
        WHERE table_schema = 'zimbra' AND table_name = 'schema_version';
    );

    my $exists = qx(/opt/zimbra/bin/mysql -u zimbra -p$mysql_pass --batch --skip-column-names -e "$check");
    chomp($exists);

    if ($exists == 0) {
        Migrate::log("Creating schema_version table");
        my $create = qq(
            CREATE TABLE zimbra.schema_version (
                version INT NOT NULL
            );
            INSERT INTO zimbra.schema_version (version) VALUES ($fromVersion);
        );
        system("/opt/zimbra/bin/mysql -u zimbra -p$mysql_pass -e \"$create\"");
    } else {
        Migrate::log("schema_version table already exists. Skipping creation.");
    }
}

# -----------------------------
# Atualiza as tabelas config e schema_version
sub updateConfigAndSchemaVersion {
    my ($version) = @_;

    my $mysql_pass = qx(/opt/zimbra/bin/zmlocalconfig -s -m nokey zimbra_mysql_password);
    chomp($mysql_pass);

    my $update_config = qq(
        UPDATE zimbra.config SET value = $version WHERE name = 'db.version';
    );
    my $update_schema = qq(
        UPDATE zimbra.schema_version SET version = $version;
    );

    Migrate::log("Updating zimbra.config and schema_version to $version");
    system("/opt/zimbra/bin/mysql -u zimbra -p$mysql_pass -e \"$update_config\"");
    system("/opt/zimbra/bin/mysql -u zimbra -p$mysql_pass -e \"$update_schema\"");
}
