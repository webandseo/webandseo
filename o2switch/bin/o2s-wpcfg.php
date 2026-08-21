<?php
/**
 * o2s-wpcfg.php — lit une valeur dans un wp-config.php sans l'exécuter.
 *
 *   php o2s-wpcfg.php <fichier> const DB_PASSWORD
 *   php o2s-wpcfg.php <fichier> prefix
 *
 * On passe par le tokenizer PHP plutôt que par une expression régulière :
 * un mot de passe contenant une apostrophe ou une contre-oblique est lu
 * correctement, là où un sed renverrait la valeur encore échappée — et
 * l'export de la base échouerait sans que la cause soit évidente.
 */

$file = $argv[1] ?? '';
$mode = $argv[2] ?? 'const';
$key  = $argv[3] ?? '';

if (!is_readable($file)) { fwrite(STDERR, "illisible : $file\n"); exit(1); }

$tokens = token_get_all(file_get_contents($file));

/** Convertit un littéral de chaîne PHP en sa valeur réelle. */
function literal(string $tok): string {
    $q = $tok[0];
    $body = substr($tok, 1, -1);
    if ($q === "'") {
        // En simple quote, seuls \' et \\ sont des échappements.
        return preg_replace('/\\\\([\\\\\'])/', '$1', $body);
    }
    return stripcslashes($body);
}

/** Tokens significatifs uniquement : on ignore espaces et commentaires. */
$t = [];
foreach ($tokens as $tk) {
    if (is_array($tk) && in_array($tk[0], [T_WHITESPACE, T_COMMENT, T_DOC_COMMENT], true)) continue;
    $t[] = $tk;
}

if ($mode === 'prefix') {
    for ($i = 0; $i < count($t) - 2; $i++) {
        if (is_array($t[$i]) && $t[$i][0] === T_VARIABLE && $t[$i][1] === '$table_prefix'
            && $t[$i + 1] === '='
            && is_array($t[$i + 2]) && $t[$i + 2][0] === T_CONSTANT_ENCAPSED_STRING) {
            echo literal($t[$i + 2][1]), "\n";
            exit(0);
        }
    }
    exit(1);
}

// define( 'CLE', 'valeur' )
for ($i = 0; $i < count($t) - 4; $i++) {
    if (!is_array($t[$i]) || strcasecmp($t[$i][1] ?? '', 'define') !== 0) continue;
    if ($t[$i + 1] !== '(') continue;
    if (!is_array($t[$i + 2]) || $t[$i + 2][0] !== T_CONSTANT_ENCAPSED_STRING) continue;
    if (literal($t[$i + 2][1]) !== $key) continue;
    if ($t[$i + 3] !== ',') continue;
    if (!is_array($t[$i + 4]) || $t[$i + 4][0] !== T_CONSTANT_ENCAPSED_STRING) continue;
    echo literal($t[$i + 4][1]), "\n";
    exit(0);
}
exit(1);
