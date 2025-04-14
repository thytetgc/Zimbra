#!/usr/bin/perl

use strict;
use lib "/opt/zimbra/libexec/scripts";
use Migrate;

my $expectedVersion = 118;

eval {
    Migrate::log("Starting schema fix to version $expectedVersion...");

    # Adiciona colunas na tabela mobile_devices se necessário
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

    # Verifica se a tabela schema_version existe e recria
    my $mysql_pass = getMysqlPass();
    my $check = qx(/opt/zimbra/bin/mysql -u zimbra -p$mysql_pass -e "SHOW TABLES LIKE 'schema_version';" zimbra);
    if ($check !~ /schema_version/) {
        Migrate::log("Creating schema_version table.");
    } else {
        Migrate::log("schema_version table exists. Dropping and recreating.");
    }

    my $schema_sql = qq{
        DROP TABLE IF EXISTS schema_version;
        CREATE TABLE schema_version (
            version INT NOT NULL
        );
        INSERT INTO schema_version (version) VALUES ($expectedVersion);
    };
    Migrate::runSql($schema_sql);

    # Atualiza a tabela config
    Migrate::log("Updating config table with version $expectedVersion.");
    Migrate::runSql("UPDATE config SET value = $expectedVersion WHERE name = 'db.version';");

    Migrate::log("Schema successfully synchronized to version $expectedVersion.");
};

if ($@) {
    Migrate::log("ERROR: Schema migration failed: $@");
    exit(1);
}

exit(0);

# -----------------------------------------------------------------
# Verifica se coluna existe
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
# Busca a senha do MySQL via zmlocalconfig
sub getMysqlPass {
    my $pass = qx(/opt/zimbra/bin/zmlocalconfig -s -m nokey zimbra_mysql_password);
    chomp($pass);
    return $pass;
}
