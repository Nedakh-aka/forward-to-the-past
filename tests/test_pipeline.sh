#!/usr/bin/env bash
# Tests d'intégration Forward to the Past — à lancer depuis la racine du dépôt.
# Les données du projet original ne sont jamais modifiées.
set -u
set -o pipefail
export PYTHONUTF8=1 PYTHONIOENCODING=utf-8

RACINE=$(pwd -P)
LOG="$RACINE/test_pipeline_$(date +%Y%m%d_%H%M%S)_$$.log"
IMDB=(name.basics.tsv.gz title.akas.tsv.gz title.basics.tsv.gz title.principals.tsv.gz title.ratings.tsv.gz)
INTERIM=(name.basics.csv title.akas.csv title.basics.csv title.principals.csv title.ratings.csv TMDB_movie_dataset_v11.csv)
TMDB=TMDB_movie_dataset_v11.csv
PYTHON=${PYTHON:-python}

# FULL=0 : tests locaux + téléchargement d'une archive absente, sans les trois
# téléchargements complets. Par défaut, toute la campagne est exécutée.
FULL=${FULL:-1}
KEEP_WORKSPACE=${KEEP_WORKSPACE:-0}

campagne() (
    nb_ok=0; nb_ko=0; nb_skip=0
    declare -a bilan=()
    W=''
    nettoyage() {
        if [[ -n "$W" && -d "$W" ]]; then
            if [[ "$KEEP_WORKSPACE" == 1 ]]; then
                echo "Espace de test conservé : $W"
            else
                cd "$RACINE" || return 1
                rm -rf -- "$W" || { echo "[ATTENTION] Nettoyage incomplet : $W"; return 1; }
                echo 'Espace de test supprimé (projet original intact).'
            fi
        fi
    }
    trap nettoyage EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM

    noter() {
        local etat=$1 nom=$2
        bilan+=("$etat | $nom")
        case "$etat" in
            OK) ((nb_ok+=1));;
            KO) ((nb_ko+=1));;
            SKIP) ((nb_skip+=1));;
        esac
        printf '\n[%s] %s\n' "$etat" "$nom"
    }
    fatal() { echo "[BLOQUANT] $*"; exit 1; }
    echo '=== CAMPAGNE DE TESTS FORWARD TO THE PAST ==='
    date
    echo "Projet : $RACINE"
    echo "Log : $LOG"
    echo "FULL=$FULL | KEEP_WORKSPACE=$KEEP_WORKSPACE"
    [[ "$FULL" =~ ^[01]$ && "$KEEP_WORKSPACE" =~ ^[01]$ ]] || fatal 'FULL et KEEP_WORKSPACE doivent valoir 0 ou 1.'
    command -v "$PYTHON" >/dev/null || fatal 'Python introuvable.'
    "$PYTHON" -V || fatal 'Python indisponible.'
    # Résoudre l'interpréteur avant de changer de répertoire (Git Bash/Windows).
    PYTHON=$("$PYTHON" -c 'import sys; print(sys.executable)' | tr -d '\r') || fatal 'Impossible de résoudre Python.'
    if command -v cygpath >/dev/null; then PYTHON=$(cygpath -u "$PYTHON"); fi
    echo "Interpréteur : $PYTHON"
    echo '--- Arborescence et prérequis ---'
    for f in main.py src/reduction_sources.py src/exporter_sources_reduites.py \
        notebooks/01_creation_catalogue.ipynb notebooks/02_enrichissement_catalogue.ipynb \
        "data/raw/$TMDB" data/supplements/Entrees_France.csv \
        data/supplements/film_description_enrichi.csv; do
        [[ -s "$f" ]] || fatal "Fichier obligatoire absent ou vide : $f"
        ls -lh -- "$f"
    done
    for d in app dashboard docs notebooks src data/raw data/interim data/processed; do
        if [[ -d "$d" && -f "$d/.gitkeep" ]]; then echo "[OK] $d/.gitkeep"; else echo "[INFO] Dossier ou .gitkeep absent : $d"; fi
    done
    if [[ -e notebooks/test.ipynb ]]; then echo '[INFO] notebooks/test.ipynb encore présent.'; fi
    if command -v git >/dev/null && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo '--- État Git initial (aucune modification de l’index) ---'
        git status --short
        git ls-files -- data/raw data/interim data/processed data/supplements
        echo '--- Règles d’exclusion ---'
        git check-ignore -v --no-index data/raw/"$TMDB" data/interim/name.basics.csv data/processed/catalogue.csv || true
    fi
    "$PYTHON" - <<'PY' || fatal 'Dépendances nécessaires indisponibles.'
import sys
from importlib.metadata import version
for paquet in ('pandas', 'requests', 'ipython', 'ipykernel', 'nbformat', 'nbclient', 'jupyter_client', 'pyzmq'):
    print(f'{paquet}: {version(paquet)}')
print('Python:', sys.executable)
PY
    # Isolation : copie des seuls fichiers nécessaires, sans .git ni .venv.
    W=$(mktemp -d "${TMPDIR:-/tmp}/forward-tests.XXXXXXXX") || fatal 'Création du dossier temporaire impossible.'
    echo "Espace de test : $W"
    df -h "$W" || true
    mkdir -p "$W"/{src,notebooks,data/raw,data/interim,data/processed,data/supplements,controles} || fatal 'mkdir impossible.'
    cp main.py "$W/" && cp src/{reduction_sources,exporter_sources_reduites}.py "$W/src/" && \
        cp notebooks/{01_creation_catalogue,02_enrichissement_catalogue}.ipynb "$W/notebooks/" && \
        cp data/supplements/{Entrees_France,film_description_enrichi}.csv "$W/data/supplements/" && \
        cp "data/raw/$TMDB" "$W/data/raw/" || fatal 'Copie des fichiers obligatoires impossible.'
    if [[ -f data/supplements/title.principals.csv ]]; then
        cp data/supplements/title.principals.csv "$W/data/supplements/" || fatal 'Copie du supplément impossible.'
    fi
    for f in "${IMDB[@]}"; do
        if [[ -f data/raw/$f ]]; then cp "data/raw/$f" "$W/data/raw/" || fatal "Copie impossible : $f"; fi
    done
    cd "$W" || fatal 'Accès au dossier de test impossible.'

    # Contrôles Python intégrés : pas de fichier à installer dans le projet.
    cat > controles/verifier.py <<'PY'
import hashlib
import json
import sys
from pathlib import Path
import pandas as pd

RAW = Path('data/raw')
IMDB = ['name.basics.tsv.gz', 'title.akas.tsv.gz', 'title.basics.tsv.gz',
        'title.principals.tsv.gz', 'title.ratings.tsv.gz']
BASE = ['tconst', 'tmdb_id', 'titre_affiche', 'originalTitle', 'startYear',
        'runtimeMinutes', 'genre_source', 'original_language', 'origine_production',
        'production_countries', 'film_francais', 'entrees_france', 'type_cumul_entrees',
        'saga', 'averageRating', 'numVotes', 'overview', 'poster_path']
AJOUTS = ['acteurs_principaux', 'acteurs_nconst', 'realisateurs', 'realisateurs_nconst',
          'overview_fr', 'source_fr']
INTERIM = {'name.basics.csv': 'nconst', 'title.akas.csv': 'titleId',
           'title.basics.csv': 'tconst', 'title.principals.csv': 'tconst',
           'title.ratings.csv': 'tconst', 'TMDB_movie_dataset_v11.csv': 'id'}

def empreinte(p):
    if not p.is_file():
        return None
    h = hashlib.sha256()
    with p.open('rb') as f:
        for bloc in iter(lambda: f.read(4 * 1024 * 1024), b''):
            h.update(bloc)
    return h.hexdigest()

def lire(p):
    return pd.read_csv(p, dtype='string', keep_default_na=False)

def verifier(condition, message):
    if not condition:
        raise AssertionError(message)
    print('[OK]', message)

def manifeste(p):
    fichiers = [RAW / n for n in IMDB + ['TMDB_movie_dataset_v11.csv']]
    fichiers += [Path('data/supplements') / n for n in
                 ['Entrees_France.csv', 'film_description_enrichi.csv', 'title.principals.csv']]
    contenu = {str(f): empreinte(f) for f in fichiers}
    p.write_text(json.dumps(contenu, indent=2), encoding='utf-8')
    print(json.dumps(contenu, indent=2))

mode = sys.argv[1]
if mode == 'manifest':
    manifeste(Path(sys.argv[2]))
elif mode == 'sources':
    avant = json.loads(Path(sys.argv[2]).read_text(encoding='utf-8'))
    apres = json.loads(Path(sys.argv[3]).read_text(encoding='utf-8'))
    force = sys.argv[4] == '1'
    trace = Path(sys.argv[5]).read_text(encoding='utf-8', errors='replace')
    for n in IMDB:
        cle = str(RAW / n)
        verifier(apres[cle] is not None, f'{n} disponible après exécution')
        attendu = force or avant[cle] is None
        marque = '[TÉLÉCHARGEMENT]' if attendu else '[IGNORÉ]'
        verifier(f'{marque} {n}' in trace, f'{n} : trace attendue {marque}')
        if not attendu:
            verifier(avant[cle] == apres[cle], f'{n} non modifié')
    for cle in avant:
        if cle not in [str(RAW / n) for n in IMDB]:
            verifier(avant[cle] == apres[cle], f'Source locale inchangée : {cle}')
elif mode == 'csv':
    base = lire('data/processed/catalogue.csv')
    final = lire('data/processed/dataset_catalogue_filtres.csv')
    verifier(list(base.columns) == BASE, 'Schéma initial : 18 colonnes attendues')
    verifier(list(final.columns) == BASE + AJOUTS, 'Schéma final : 24 colonnes attendues')
    verifier(len(base) > 0 and len(base) == len(final), 'Catalogue non vide et nombre de films conservé')
    verifier(base.tconst.is_unique and base.tconst.str.fullmatch(r'tt\d+').all(), 'Identifiants IMDb valides et uniques')
    pd.testing.assert_frame_equal(base, final[BASE])
    print('[OK] Les 18 colonnes initiales sont strictement conservées')
    for a, b in [('acteurs_principaux','acteurs_nconst'), ('realisateurs','realisateurs_nconst')]:
        verifier((final[a].eq('') == final[b].eq('')).all(), f'Absences cohérentes : {a}/{b}')
        # Les noms peuvent exceptionnellement contenir le séparateur ; ne pas
        # imposer une règle métier supplémentaire sur leur texte.
        verifier(final.loc[final[b].ne(''), b].str.fullmatch(r'nm\d+( \| nm\d+)*').all(), f'Format des identifiants : {b}')
    verifier((final.overview_fr.eq('') == final.source_fr.eq('')).all(), 'Description FR et provenance présentes ou absentes ensemble')
    # Le notebook utilise les valeurs NA usuelles de pandas ; comparer avec la
    # même convention pour les champs du supplément.
    desc = pd.read_csv('data/supplements/film_description_enrichi.csv', dtype='string', na_values=[r'\N']).set_index('tconst')
    attendues = desc.reindex(final.tconst)[['overview_fr','source_fr']].fillna('').reset_index(drop=True)
    pd.testing.assert_frame_equal(final[['overview_fr','source_fr']].astype('string'), attendues.astype('string'))
    print('[OK] Descriptions françaises conformes au supplément, absences autorisées')
    print('Dimensions:', base.shape, final.shape)
    print('Valeurs vides par colonne :\n', final.eq('').sum().to_string())
    if sys.argv[2] == '1':
        ids = set(base.tconst)
        for nom, cle in INTERIM.items():
            p = Path('data/interim') / nom
            verifier(p.is_file(), f'Export présent : {nom}')
            df = lire(p)
            verifier(cle in df, f'Colonne clé présente : {nom}/{cle}')
            print(f'{nom}: {len(df):,} lignes, {len(df.columns)} colonnes')
            if cle in ('tconst','titleId'):
                verifier(set(df[cle]) <= ids, f'Identifiants limités au catalogue : {nom}')
            if nom == 'title.basics.csv':
                verifier(set(df[cle]) == ids, 'Title Basics couvre tout le catalogue')
        principals = lire('data/interim/title.principals.csv')
        noms = lire('data/interim/name.basics.csv')
        autorises = set(principals.nconst)
        p = Path('data/supplements/title.principals.csv')
        if p.is_file():
            sup = lire(p)
            autorises.update(sup.loc[sup.tconst.isin(ids), 'nconst'])
        verifier(set(noms.nconst) <= autorises, 'Name Basics limité aux personnes concernées')
    else:
        verifier(not any(Path('data/interim').glob('*.csv')), 'Mode raw : aucun export intermédiaire')
elif mode == 'compare':
    a, b = map(Path, sys.argv[2:4])
    ma = json.loads((a/'apres.json').read_text(encoding='utf-8'))
    mb = json.loads((b/'apres.json').read_text(encoding='utf-8'))
    if ma != mb:
        print('[INFO] Sources différentes : égalité non exigible.')
        print('Sources modifiées:', [k for k in ma if ma[k] != mb[k]])
        sys.exit(3)
    for nom in ('catalogue.csv','dataset_catalogue_filtres.csv'):
        x, y = lire(a/nom), lire(b/nom)
        print(f'{nom}: {x.shape} contre {y.shape}')
        try:
            pd.testing.assert_frame_equal(x, y)
        except AssertionError:
            if list(x.columns) == list(y.columns) and x.tconst.is_unique and y.tconst.is_unique:
                print('Films ajoutés:', sorted(set(y.tconst)-set(x.tconst))[:20])
                print('Films retirés:', sorted(set(x.tconst)-set(y.tconst))[:20])
                ix = x.set_index('tconst'); iy = y.set_index('tconst')
                commun = ix.index.intersection(iy.index)
                print('Différences par colonne:\n', ix.loc[commun].ne(iy.loc[commun]).sum().to_string())
            raise
        print('[OK] Égalité stricte, ordre des lignes et colonnes compris')
else:
    raise ValueError(mode)
PY
    echo '--- Syntaxe des scripts et notebooks ---'
    if "$PYTHON" - <<'PY'
import json
from pathlib import Path
for p in [Path('main.py'), *Path('src').glob('*.py')]:
    compile(p.read_text(encoding='utf-8'), str(p), 'exec')
    print('[OK]', p)
for p in Path('notebooks').glob('*.ipynb'):
    n = json.loads(p.read_text(encoding='utf-8'))
    for i,c in enumerate(n['cells'],1):
        if c['cell_type']=='code':
            compile(''.join(c['source']), f'{p}: cellule {i}', 'exec')
    print('[OK]', p)
PY
    then noter OK 'Syntaxe'; else fatal 'Erreur de syntaxe.'; fi

    echo '--- Test du véritable kernel et des quatre types de sorties ---'
    if "$PYTHON" -u - <<'PY' 2>&1 | tee controles/kernel.log
import sys
import nbformat
from pathlib import Path
from main import executer_notebook
p = Path('notebooks/controle_kernel.ipynb')
n = nbformat.v4.new_notebook(cells=[nbformat.v4.new_code_cell(f"""import sys
from pathlib import Path
assert Path(sys.executable).resolve() == Path({sys.executable!r}).resolve(), 'Kernel différent de Python lancé'
from IPython.display import display
import pandas as pd
import requests
print('KERNEL_STDOUT')
print('KERNEL_STDERR', file=sys.stderr)
print('KERNEL_PYTHON:', sys.executable)
display('KERNEL_DISPLAY')
'KERNEL_RESULT'
""")])
nbformat.write(n, p)
try:
    executer_notebook(p.resolve(), {})
finally:
    p.unlink(missing_ok=True)
PY
    then
        if grep -q KERNEL_STDOUT controles/kernel.log && grep -q KERNEL_STDERR controles/kernel.log && grep -q KERNEL_DISPLAY controles/kernel.log && grep -q KERNEL_RESULT controles/kernel.log; then noter OK 'Kernel et traces'; else fatal 'Sorties du kernel incomplètes.'; fi
    else fatal 'Le kernel ne démarre pas correctement.'; fi

    nettoyer_generes() {
        local f
        rm -f -- data/processed/catalogue.csv data/processed/dataset_catalogue_filtres.csv || return 1
        for f in "${INTERIM[@]}"; do rm -f -- "data/interim/$f" || return 1; done
    }
    negatif() {
        local nom=$1 fichier=$2; local rc
        echo "=== TEST NÉGATIF : $nom ==="
        nettoyer_generes || fatal 'Nettoyage impossible.'
        mv -- "$fichier" "$fichier.test_absent" || fatal 'Déplacement impossible.'
        "$PYTHON" -u main.py -f 2>&1 | tee "controles/$nom.log"
        rc=${PIPESTATUS[0]}
        mv -- "$fichier.test_absent" "$fichier" || fatal 'Restauration impossible.'
        echo "Code de retour : $rc (attendu : 1)"
        if [[ "$rc" == 1 && ! -e data/processed/catalogue.csv && ! -e data/processed/dataset_catalogue_filtres.csv ]] && \
            grep -Fq 'Fichier source manquant' "controles/$nom.log" && grep -Fq "${fichier##*/}" "controles/$nom.log" && \
            ! grep -Fq '[TÉLÉCHARGEMENT]' "controles/$nom.log"; then
            noter OK "$nom : arrêt avant téléchargement"
        else noter KO "$nom : arrêt anticipé incorrect"; fi
    }
    scenario() {
        local nom=$1 interim=$2 force=$3; shift 3
        local rc debut=$SECONDS
        local dossier="controles/$nom"
        mkdir -p "$dossier" || fatal 'Création du dossier de résultats impossible.'
        nettoyer_generes || fatal 'Nettoyage impossible.'
        echo; echo "=== $nom | python -u main.py $* ==="; date
        "$PYTHON" controles/verifier.py manifest "$dossier/avant.json" || fatal 'Empreintes initiales impossibles.'
        "$PYTHON" -u main.py "$@" 2>&1 | tee "$dossier/execution.log"
        rc=${PIPESTATUS[0]}
        echo "Code de retour : $rc | Durée : $((SECONDS-debut)) s"
        if [[ "$rc" != 0 ]]; then noter KO "$nom : main.py"; return; fi
        if "$PYTHON" controles/verifier.py manifest "$dossier/apres.json" && \
            "$PYTHON" controles/verifier.py sources "$dossier/avant.json" "$dossier/apres.json" "$force" "$dossier/execution.log" && \
            "$PYTHON" controles/verifier.py csv "$interim" && \
            cp data/processed/{catalogue,dataset_catalogue_filtres}.csv "$dossier/"; then
            noter OK "$nom"
        else noter KO "$nom : contrôles complémentaires"; fi
    }
    comparer() {
        local a=$1 b=$2 rc
        echo "=== COMPARAISON : $a / $b ==="
        if [[ ! -f controles/$a/dataset_catalogue_filtres.csv || ! -f controles/$b/dataset_catalogue_filtres.csv ]]; then noter SKIP "$a / $b : résultat indisponible"; return; fi
        "$PYTHON" controles/verifier.py compare "controles/$a" "controles/$b"
        rc=$?
        case $rc in 0) noter OK "$a / $b";; 3) noter SKIP "$a / $b : sources différentes";; *) noter KO "$a / $b : divergence à sources identiques";; esac
    }

    negatif 'N01_TMDB_absent' "data/raw/$TMDB"
    negatif 'N02_entrees_absentes' 'data/supplements/Entrees_France.csv'
    scenario 'T01_raw' 0 0
    scenario 'T02_interim' 1 0 -i
    comparer T01_raw T02_interim
    # Ne retirer que des copies dans l'espace temporaire.
    rm -f -- data/raw/title.ratings.tsv.gz data/raw/title.ratings.tsv.gz.part || fatal 'Suppression de la copie impossible.'
    scenario 'T03_archive_absente' 0 0
    comparer T01_raw T03_archive_absente
    if [[ "$FULL" == 1 ]]; then
        for f in "${IMDB[@]}"; do rm -f -- "data/raw/$f" "data/raw/$f.part" || fatal 'Suppression de la copie impossible.'; done
        scenario 'T04_coldstart' 0 0
        scenario 'T05_force' 0 1 -f
        comparer T04_coldstart T05_force
        scenario 'T06_force_interim' 1 1 -if
        scenario 'T07_raw_apres_force' 0 0
        comparer T06_force_interim T07_raw_apres_force
    else
        noter SKIP 'T04 à T07 : campagne complète désactivée (FULL=0)'
    fi
    echo; echo '=== BILAN FINAL ==='
    printf '%s\n' "${bilan[@]}"
    echo "OK=$nb_ok | KO=$nb_ko | SKIP=$nb_skip"
    date
    if ((nb_ko > 0)); then exit 1; fi
    exit 0
)

campagne 2>&1 | tee "$LOG"
statuts=("${PIPESTATUS[@]}")
if [[ "${statuts[1]}" != 0 ]]; then echo 'Erreur d’écriture du log.' >&2; exit 1; fi
exit "${statuts[0]}"
