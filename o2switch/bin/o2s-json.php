<?php
/**
 * o2s-json.php — extracteur JSON minimaliste pour les sorties UAPI cPanel.
 *
 * Lit du JSON sur stdin, écrit du TSV sur stdout.
 * Volontairement agnostique du schéma : on parcourt récursivement la structure
 * et on retient tout objet qui porte les clés attendues. Les sorties UAPI
 * changent de forme d'une version de cPanel à l'autre, cette approche survit.
 *
 * Usage : uapi --output=json DomainInfo domains_data | php o2s-json.php domains
 */

$mode = $argv[1] ?? 'raw';
$raw  = stream_get_contents(STDIN);
$json = json_decode($raw, true);

if (!is_array($json)) {
    fwrite(STDERR, "o2s-json: JSON illisible\n");
    exit(1);
}

/** Parcours récursif : applique $fn à chaque objet associatif rencontré. */
function walk($node, callable $fn) {
    if (!is_array($node)) return;
    $assoc = array_keys($node) !== range(0, count($node) - 1);
    if ($assoc) $fn($node);
    foreach ($node as $child) walk($child, $fn);
}

function tsv(array $cols) {
    echo implode("\t", array_map(
        static fn($c) => str_replace(["\t", "\n", "\r"], ' ', (string) $c),
        $cols
    )), "\n";
}

function b64(?string $s): string { return $s === null ? '' : (base64_decode($s, true) ?: ''); }

$seen = [];
switch ($mode) {

    case 'domains': // domaine <TAB> documentroot <TAB> version php <TAB> type
        walk($json, function (array $o) use (&$seen) {
            if (!isset($o['domain'], $o['documentroot'])) return;
            $k = $o['domain'] . '|' . $o['documentroot'];
            if (isset($seen[$k])) return;
            $seen[$k] = true;
            tsv([$o['domain'], $o['documentroot'], $o['phpversion'] ?? '', $o['type'] ?? '']);
        });
        break;

    case 'databases': // base <TAB> taille disque
        walk($json, function (array $o) use (&$seen) {
            if (!isset($o['database'])) return;
            if (isset($seen[$o['database']])) return;
            $seen[$o['database']] = true;
            tsv([$o['database'], $o['disk_usage'] ?? '']);
        });
        break;

    case 'pops': // adresse email <TAB> quota utilisé
        walk($json, function (array $o) use (&$seen) {
            if (!isset($o['email'])) return;
            if (isset($seen[$o['email']])) return;
            $seen[$o['email']] = true;
            tsv([$o['email'], $o['diskused'] ?? $o['_diskused'] ?? '']);
        });
        break;

    case 'zone': // reconstruction d'un fichier de zone depuis DNS::parse_zone
        $rows = $json['result']['data'] ?? $json['data'] ?? [];
        foreach ($rows as $r) {
            $type = $r['type'] ?? '';
            if ($type === 'record') {
                $data = array_map('b64', $r['data_b64'] ?? []);
                echo sprintf(
                    "%s\t%s\tIN\t%s\t%s\n",
                    b64($r['dname_b64'] ?? ''),
                    $r['ttl'] ?? '',
                    $r['record_type'] ?? '',
                    implode(' ', $data)
                );
            } elseif ($type === 'control') {
                echo sprintf("; %s %s\n", $r['name'] ?? '', b64($r['value_b64'] ?? ''));
            }
        }
        break;

    case 'errors': // remonte les messages d'erreur UAPI, s'il y en a
        walk($json, function (array $o) {
            foreach (['errors', 'error'] as $k) {
                if (!empty($o[$k])) {
                    foreach ((array) $o[$k] as $e) echo trim((string) $e), "\n";
                }
            }
        });
        break;

    default:
        echo json_encode($json, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE), "\n";
}
