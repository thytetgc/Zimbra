#!/usr/bin/perl

use strict;
use lib "/opt/zimbra/libexec/scripts";
use Migrate;

my $fromVersion = 112;
my $toVersion = 114;

Migrate::verifySchemaVersion($fromVersion);

eval {
    my $mysql_pass = get_mysql_password();

    # Verifica a versão atual no banco antes de seguir
    my $current_version = get_db_version($mysql_pass);
    if ($current_version != $fromVersion) {
        die "Versão atual do banco é $current_version. Esperado: $fromVersion. Abortando update.";
    }

    # Verifica e adiciona a coluna mobile_operator
    if (!columnExists("mobile_devices", "mobile_operator", $mysql_pass)) {
        Migrate::log("Adding 'mobile_operator' column to mobile_devices");
        my $sql = "ALTER TABLE mobile_devices ADD COLUMN mobile_operator VARCHAR(512);";
        Migrate::runSql($sql);
    } else {
        Migrate::log("Column 'mobile_operator' already exists. Skipping.");
    }

    # Verifica e adiciona a coluna last_updated_by
    if (!columnExists("mobile_devices", "last_updated_by", $mysql_pass)) {
        Migrate::log("Adding 'last_updated_by' column to mobile_devices");
        my $sql = "ALTER TABLE mobile_devices ADD COLUMN last_updated_by ENUM('Admin','User') DEFAULT 'User';";
        Migrate::runSql($sql);
    } else {
        Migrate::log("Column 'last_updated_by' already exists. Skipping.");
    }

    # Atualiza a versão do schema no banco
    Migrate::log("Updating DB schema version from $fromVersion to $toVersion.");
    Migrate::updateSchemaVersion($fromVersion, $toVersion);
    Migrate::log("Database schema updated from $fromVersion to $toVersion successfully.");
};

if ($@) {
    Migrate::log("ERROR: Schema migration failed: $@");
    exit(1);
}

exit(0);

# ---------------------
# Função para verificar se uma coluna existe
sub columnExists {
    my ($table, $column, $mysql_pass) = @_;

    my $sql = qq{
        SELECT COUNT(*) FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA='zimbra' AND TABLE_NAME='$table' AND COLUMN_NAME='$column';
    };

    my $cmd = qq(/opt/zimbra/bin/mysql -u zimbra -p$mysql_pass -N -e "$sql");
    my $result = qx($cmd);
    chomp($result);
    return $result > 0;
}

# ---------------------
# Pega a senha do MySQL de forma limpa
sub get_mysql_password {
    my $line = qx(/opt/zimbra/bin/zmlocalconfig -s -m nokey zimbra_mysql_password);
    chomp($line);
    $line =~ s/^.*\s//; # Pega apenas o valor
    return $line;
}

# ---------------------
# Pega a versão atual do banco
sub get_db_version {
    my ($mysql_pass) = @_;
    my $sql = "SELECT value FROM config WHERE name='db.version';";
    my $cmd = qq(/opt/zimbra/bin/mysql -u zimbra -p$mysql_pass -N -e "$sql" zimbra);
    my $result = qx($cmd);
    chomp($result);
    return $result;
}
