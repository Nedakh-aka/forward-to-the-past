## Installation de l'environnement Python

### 1. Cloner le dépôt

```bash
git clone https://github.com/<utilisateur>/forward-to-the-past.git
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
python -m pip check
```

## Structure du projet

```text
forward-to-the-past/
├── app/                # Application Streamlit
├── dashboard/          # Tableaux de bord (Power BI)
├── data/
│   ├── raw/            # Données brutes IMDb et TMDB
│   ├── interim/        # Données intermédiaires
│   └── processed/      # Données nettoyées et catalogue final
├── docs/               # Documentation et présentation du projet
├── notebooks/          # Notebooks d'exploration et de traitement
├── src/                # Scripts Python réutilisables
├── .env.example        # Exemple de variables d'environnement
├── .gitignore          # Fichiers exclus du suivi Git
├── README.md           # Documentation du dépôt
└── requirements.txt    # Dépendances Python
```

**Remarque :** les fichiers de données volumineux ne sont pas versionnés dans Git. Les dossiers `data/` sont conservés grâce aux fichiers `.gitkeep`.