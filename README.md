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