# Forward to the Past

Guide de démarrage du projet : installation de l'environnement et reconstruction du catalogue de films à partir des données sources.

## Installation de l'environnement Python

Prérequis : Git, Python 3.12 (version utilisée lors de la recette : 3.12.10), une connexion Internet pour télécharger les sources IMDb et suffisamment d'espace disque pour les données et les exports.

### 1. Cloner le dépôt

```bash
git clone https://github.com/Nedakh-aka/forward-to-the-past
cd forward-to-the-past
```


### 2. Créer l'environnement virtuel

```bash
python -m venv .venv
```

### 3. Activer l'environnement

**Windows — Git Bash :**

```bash
source .venv/Scripts/activate
```

**Linux / macOS :**

```bash
source .venv/bin/activate
```

### 4. Installer les dépendances

```bash
python -m pip install -r requirements.txt
```

### 5. Vérifier l'installation

```bash
python --version
python -m pip check
```

Le programme exécute les notebooks avec le kernel Jupyter `python3`. Celui-ci doit utiliser l'interpréteur de l'environnement virtuel `.venv`. Les dépendances nécessaires à l'exécution des notebooks doivent donc être installées dans cet environnement.

## Préparer les données

Avant la première exécution, placer le fichier TMDB fourni pour le projet dans `data/raw/`, en conservant son nom exact :

```text
data/raw/TMDB_movie_dataset_v11.csv
```

Vérifier également la présence des fichiers suivants dans `data/supplements/` :

| Fichier | Rôle |
|---|---|
| `Entrees_France.csv` | Données de fréquentation des films en France (obligatoire) |
| `film_description_enrichi.csv` | Descriptions françaises des films (obligatoire pour l'enrichissement) |
| `title.principals.csv` | Compléments manuels des acteurs et réalisateurs (facultatif) |

Ces suppléments doivent être récupérés auprès du groupe s'ils ne sont pas présents dans le dépôt.

Les cinq archives IMDb suivantes sont automatiquement téléchargées dans `data/raw/` lorsqu'elles sont absentes :

- `name.basics.tsv.gz`
- `title.akas.tsv.gz`
- `title.basics.tsv.gz`
- `title.principals.tsv.gz`
- `title.ratings.tsv.gz`

Il n'est pas nécessaire de les télécharger ni de les décompresser manuellement. Les archives déjà présentes sont réutilisées par défaut. Les données IMDb sont actualisées régulièrement ; les résultats peuvent donc évoluer selon la date des sources utilisées.

Documentation et conditions d'utilisation : [IMDb Non-Commercial Datasets](https://developer.imdb.com/non-commercial-datasets/).

## Exécuter le programme

Depuis la racine du dépôt, avec l'environnement virtuel activé :

```bash
python main.py
```

Cette commande crée le catalogue filtré puis l'enrichit à partir des sources brutes. Aucun lancement manuel des notebooks n'est nécessaire.

### Options disponibles

| Commande | Comportement |
|---|---|
| `python main.py` | Réutilise les archives IMDb présentes, télécharge celles qui manquent et enrichit depuis les sources brutes. |
| `python main.py -i` | Génère les six fichiers intermédiaires et les utilise pour l'enrichissement (sources intermédiaires utiles pour d'autres traitements). |
| `python main.py -f` | Force le téléchargement des cinq archives IMDb, même si elles sont déjà présentes. |
| `python main.py -if` | Combine le téléchargement forcé et la génération des fichiers intermédiaires. |

Les options longues sont `--interim` et `--forcer-telechargement`. Pour afficher l'aide :

```bash
python main.py --help
```

L'option `-f` concerne uniquement les archives IMDb ; elle ne télécharge pas le fichier TMDB ni les suppléments. Le mode `-i` régénère les intermédiaires à chaque exécution du programme.

Le terminal affiche la progression des traitements. La durée dépend de la machine, du mode choisi et du débit Internet. Lors de la recette sous Windows, une exécution standard avec les archives locales a pris environ 7 minutes.

### Fichiers générés

- `data/processed/catalogue.csv` : catalogue filtré avant enrichissement (18 colonnes).
- `data/processed/dataset_catalogue_filtres.csv` : catalogue final enrichi (24 colonnes), fichier à utiliser pour la suite du projet.
- `data/interim/` : six sources réduites, générées uniquement avec l'option `-i` lors d'une exécution de `main.py`.

Les fichiers de sortie correspondants sont remplacés lors de leur régénération. Une exécution réussie se termine par le message `Construction du catalogue terminée` et affiche le chemin du catalogue final ainsi que le temps total.

## Structure du projet

```text
forward-to-the-past/
├── app/                             # Application Streamlit
├── dashboard/                       # Tableaux de bord (Power BI)
├── data/
│   ├── raw/                         # Sources brutes IMDb et TMDB
│   ├── interim/                     # Sources réduites générées
│   ├── processed/                   # Catalogue filtré et catalogue final
│   └── supplements/                 # Données complémentaires
├── docs/                            # Documentation du projet
├── notebooks/
│   ├── 01_creation_catalogue.ipynb  # Création et filtrage du catalogue
│   └── 02_enrichissement_catalogue.ipynb # Enrichissement du catalogue
├── src/
│   ├── reduction_sources.py         # Lecture et réduction des sources
│   └── exporter_sources_reduites.py # Export des fichiers intermédiaires
├── .env.example                     # Exemple de variables d'environnement
├── .gitignore                       # Règles d'exclusion Git
├── main.py                          # Point d'entrée du pipeline
├── README.md                        # Documentation du dépôt
└── requirements.txt                 # Dépendances Python
```

Les sources brutes, les fichiers intermédiaires et le catalogue filtré `catalogue.csv` sont exclus du suivi Git selon les règles prévues du projet. Le catalogue final constitue une exception à l'exclusion de `data/processed/`. Les fichiers `.gitkeep` permettent de conserver les dossiers vides dans le dépôt.
