#!/usr/bin/perl

use strict;
use lib "/opt/zimbra/libexec/scripts";
use Migrate;

my $fromVersion = 112;
my $toVersion   = 114;

# Verifica a versão atual do schema
Migrate::verifySchemaVersion($fromVersion);

eval {
    # Garante que a tabela schema_version exista
    Migrate::log("Ensuring schema_version table exists...");
    my $createTableSQL = qq{
        CREATE TABLE IF NOT EXISTS schema_version (
            version INT NOT NULL
        );
    };
    Migrate::runSql($createTableSQL);

    # Verifica se a tabela schema_version tem a versão correta e atualiza
    my $schemaVer = getSchemaVersionFromTable();
    if (!defined $schemaVer) {
        Migrate::log("Inserting initial schema_version = $fromVersion");
        Migrate::runSql("INSERT INTO schema_version (version) VALUES ($fromVersion);");
    } elsif ($schemaVer != $fromVersion) {
        Migrate::log("Updating schema_version from $schemaVer to $fromVersion");
        Migrate::runSql("UPDATE schema_version SET version = $fromVersion;");
    }

    # Verifica e adiciona as colunas, se necessário
    if (!columnExists("mobile_devices", "mobile_operator")) {
        Migrate::log("Adding 'mobile_operator' column to mobile_devices");
        Migrate::runSql("ALTER TABLE mobile_devices ADD COLUMN mobile_operator VARCHAR(512);");
    } else {
        Migrate::log("Column 'mobile_operator' already exists. Skipping.");
    }

    if (!columnExists("mobile_devices", "last_updated_by")) {
        Migrate::log("Adding 'last_updated_by' column to mobile_devices");
        Migrate::runSql("ALTER TABLE mobile_devices ADD COLUMN last_updated_by ENUM('Admin','User') DEFAULT 'User';");
    } else {
        Migrate::log("Column 'last_updated_by' already exists. Skipping.");
    }

    # Atualiza a versão no Zimbra (tabela config)
    Migrate::log("Updating DB schema version from $fromVersion to $toVersion in config");
    Migrate::updateSchemaVersion($fromVersion, $toVersion);

    # Atualiza a versão no schema_version para 114
    Migrate::log("Updating schema_version table to $toVersion");
    Migrate::runSql("UPDATE schema_version SET version = $toVersion;");

    # Confirmação final de sucesso
    Migrate::log("Database schema updated from $fromVersion to $toVersion successfully.");
};

if ($@) {
    Migrate::log("ERROR: Schema migration failed: $@");
    exit(1);
}

exit(0);

# ----------------------
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

# ----------------------
sub getSchemaVersionFromTable {
    my $mysql_pass = qx(/opt/zimbra/bin/zmlocalconfig -s -m nokey zimbra_mysql_password);
    chomp($mysql_pass);
    my $sql = "SELECT version FROM schema_version LIMIT 1;";
    my $cmd = qq(/opt/zimbra/bin/mysql -u zimbra -p$mysql_pass --batch --skip-column-names -e "$sql" zimbra);
    my $result = qx($cmd);
    chomp($result);
    return ($result =~ /^\d+$/) ? $result : undef;
}
