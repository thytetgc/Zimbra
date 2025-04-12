#!/usr/bin/perl

use strict;
use lib '/opt/zimbra/libexec/scripts';
use Migrate;

Migrate::verifySchemaVersion(112);

# Pega a senha diretamente do zmlocalconfig
my $db_password = `/opt/zimbra/bin/zmlocalconfig -s -m nokey zimbra_mysql_password`;
chomp($db_password);  # Remove o caractere de nova linha ao final da senha

my $column_exists = 0;

# Verifica se a coluna 'mobile_operator' já existe na tabela mobile_devices
open(my $fh, "-|", "/opt/zimbra/bin/mysql", "--user=zimbra", "--password=$db_password", "--batch", "--skip-column-names", "-e", "SHOW COLUMNS FROM mobile_devices LIKE 'mobile_operator';", "zimbra")
    or die "Falha ao executar SHOW COLUMNS: $!";

while (<$fh>) {
    if (/mobile_operator/) {
        $column_exists = 1;
        last;
    }
}
close($fh);

if ($column_exists) {
    Migrate::log("Coluna 'mobile_operator' já existe. Pulando criação.");
} else {
    my $sql = <<EOF;
ALTER TABLE mobile_devices ADD COLUMN mobile_operator VARCHAR(512);
EOF

    Migrate::log("Adicionando coluna 'mobile_operator' à tabela MOBILE_DEVICES.");
    Migrate::runSql($sql);
}

Migrate::updateSchemaVersion(112, 113);
exit(0);
