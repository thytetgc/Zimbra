#!/usr/bin/perl

use strict;

my $expected_version = 118;

print "\n===== Verificação de Versão de Schema do Zimbra =====\n";

my $mysql_pass = getMysqlPass();

# Verifica config.db.version
my $config_version = qx(/opt/zimbra/bin/mysql -u zimbra -p$mysql_pass -N -e "SELECT value FROM config WHERE name = 'db.version';" zimbra);
chomp($config_version);
print "Versão em 'config': $config_version\n";
print $config_version == $expected_version ? "✓ OK\n" : "⚠️ DIFERENTE DA ESPERADA\n";

# Verifica schema_version.version
my $schema_version = qx(/opt/zimbra/bin/mysql -u zimbra -p$mysql_pass -N -e "SELECT version FROM schema_version;" zimbra 2>/dev/null);
chomp($schema_version);
if ($schema_version eq "") {
    print "Tabela schema_version não existe ou está vazia.\n⚠️ VERIFIQUE O SCRIPT DE CORREÇÃO\n";
} else {
    print "Versão em 'schema_version': $schema_version\n";
    print $schema_version == $expected_version ? "✓ OK\n" : "⚠️ DIFERENTE DA ESPERADA\n";
}

# Verifica colunas da mobile_devices
foreach my $col ("mobile_operator", "last_updated_by") {
    my $check = checkColumnExists("mobile_devices", $col);
    print "Coluna '$col' em mobile_devices: " . ($check ? "✓ OK\n" : "❌ NÃO ENCONTRADA\n");
}

print "======================================================\n";

exit(0);

# -----------------------------------------------------------------
# Função para checar se coluna existe
sub checkColumnExists {
    my ($table, $column) = @_;
    my $sql = qq{
        SELECT COUNT(*) FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA='zimbra' AND TABLE_NAME='$table' AND COLUMN_NAME='$column';
    };
    my $result = qx(/opt/zimbra/bin/mysql -u zimbra -p$mysql_pass -N -e "$sql");
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
