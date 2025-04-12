#!/usr/bin/perl

use strict;
use lib "/opt/zimbra/libexec/scripts";
use Migrate;

my $targetVersion = 114;
my $mysql_pass = get_mysql_password();
my $current_version = get_db_version($mysql_pass);

Migrate::log("Current DB schema version is $current_version. Target: $targetVersion");

eval {
    # Etapa 1: de 111 para 112 — Nenhuma alteração, só atualização do número da versão
    if ($current_version == 111) {
        Migrate::log("Updating schema from 111 to 112 (no SQL changes).");
        Migrate::updateSchemaVersion(111, 112);
        $current_version = 112;
    }

    # Etapa 2: de 112 para 113 — Adiciona coluna mobile_operator
    if ($current_version == 112) {
        if (!columnExists("mobile_devices", "mobile_operator", $mysql_pass)) {
            Migrate::log("Adding 'mobile_operator' column to mobile_devices.");
            my $sql = "ALTER TABLE mobile_devices ADD COLUMN mobile_operator VARCHAR(512);";
            Migrate::runSql($sql);
        } else {
            Migrate::log("Column 'mobile_operator' already exists. Skipping.");
        }
        Migrate::updateSchemaVersion(112, 113);
        $current_version = 113;
    }

    # Etapa 3: de 113 para 114 — Adiciona coluna last_updated_by
    if ($current_version == 113) {
        if (!columnExists("mobile_devices", "last_updated_by", $mysql_pass)) {
            Migrate::log("Adding 'last_updated_by' column to mobile_devices.");
            my $sql = "ALTER TABLE mobile_devices ADD COLUMN last_updated_by ENUM('Admin','User') DEFAULT 'User';";
            Migrate::runSql($sql);
        } else {
            Migrate::log("Column 'last_updated_by' already exists. Skipping.");
        }
        Migrate::updateSchemaVersion(113, 114);
        $current_version = 114;
    }

    if ($current_version == $targetVersion) {
        Migrate::log("Database schema successfully updated to $targetVersion.");
    } else {
        die "Failed to reach schema version $targetVersion. Final version: $current_version.";
    }
};

if ($@) {
    Migrate::log("ERROR: Schema migration failed: $@");
    exit(1);
}

exit(0);

# ---------------------
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

sub get_mysql_password {
    my $line = qx(/opt/zimbra/bin/zmlocalconfig -s -m nokey zimbra_mysql_password);
    chomp($line);
    $line =~ s/^.*\s//;
    return $line;
}

sub get_db_version {
    my ($mysql_pass) = @_;
    my $sql = "SELECT value FROM config WHERE name='db.version';";
    my $cmd = qq(/opt/zimbra/bin/mysql -u zimbra -p$mysql_pass -N -e "$sql" zimbra);
    my $result = qx($cmd);
    chomp($result);
    return $result;
}
